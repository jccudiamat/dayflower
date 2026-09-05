import 'dart:async';
import 'dart:convert';

import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/call.dart';
import 'call_transport.dart';

/// Carries the call over LiveKit.
///
/// The only file in the app that knows a media provider exists. Everything
/// above it — the notifier, the screens, the thread bubble — speaks
/// [CallEvent] and would keep working against a different provider written
/// to the same six members.
///
/// ## What it translates
///
/// LiveKit's room emits far more than this app draws: track subscriptions,
/// per-participant quality, reconnection phases, permission changes. Passing
/// that upward would put provider types in the widget tree and make the
/// screens impossible to reason about. So this narrows to five events and
/// throws the rest away deliberately.
class LiveKitCallTransport implements CallTransport {
  LiveKitCallTransport({required String url, required SupabaseClient client})
      : _url = url,
        _client = client;

  final String _url;
  final SupabaseClient _client;

  final _events = StreamController<CallEvent>.broadcast();
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;

  /// A voice call must never publish video, so the camera state is held here
  /// rather than read back off the room — [setCameraEnabled] is a no-op on
  /// voice and the room would happily report a camera that should not exist.
  bool _isVideo = false;

  /// The live room, for the one widget that has to render actual video.
  ///
  /// Deliberately the only crack in the abstraction. Video frames cannot be
  /// funnelled through [CallEvent] — they are a texture, not a fact — so
  /// `call_video.dart` reaches in here and nothing else does. A `Room` is a
  /// `ChangeNotifier`, which is what lets that widget rebuild as tracks
  /// arrive and leave.
  lk.Room? get room => _room;

  @override
  bool get isConfigured => _url.isNotEmpty;

  @override
  Stream<CallEvent> get events => _events.stream;

  @override
  Future<void> join({
    required String room,
    required CallMode mode,
    required String identity,
  }) async {
    _isVideo = mode == CallMode.video;

    // The secret that signs this never leaves Postgres — see migration
    // 0026. `identity` is not sent: the token's `sub` comes from
    // `auth.uid()` server-side, so a client cannot join as someone else.
    final String token;
    try {
      token = await _client.rpc<String>(
        'livekit_token',
        params: {'p_room': room},
      );
    } catch (error) {
      // The one server-side failure worth telling apart. Everything else
      // reads as "couldn't reach them", which on a restricted network is
      // both true and the more likely cause.
      final message = error is PostgrestException ? error.message : '$error';
      _events.add(CallFailed(
        message.contains('calling not configured')
            ? CallFailure.notConfigured
            : CallFailure.unreachable,
      ));
      return;
    }

    final room0 = lk.Room(
      roomOptions: const lk.RoomOptions(
        // Adaptive stream and dynacast both trade a little latency for a lot
        // of bandwidth, which is the right trade on the network this app has
        // to survive: a throttled carrier drops video long before voice.
        adaptiveStream: true,
        dynacast: true,
        defaultVideoPublishOptions: lk.VideoPublishOptions(
          simulcast: true,
        ),
      ),
    );
    _room = room0;

    final listener = room0.createListener();
    _listener = listener;

    listener
      ..on<lk.RoomConnectedEvent>((_) {
        _events.add(const CallConnected());
        // A call joined *second* has the other person already in the room,
        // and no ParticipantConnected event will ever fire for them. Without
        // this the timer would never start for whoever answered.
        if (room0.remoteParticipants.isNotEmpty) {
          _events.add(const CallPartnerJoined());
        }
      })
      ..on<lk.ParticipantConnectedEvent>((_) {
        _events.add(const CallPartnerJoined());
      })
      ..on<lk.ParticipantDisconnectedEvent>((_) {
        if (room0.remoteParticipants.isEmpty) {
          _events.add(const CallPartnerLeft());
        }
      })
      ..on<lk.RoomDisconnectedEvent>((event) {
        // A disconnect we asked for is not a failure. `leave()` clears the
        // room first, so a null room here means this is our own teardown.
        if (_room == null) return;
        _events.add(CallFailed(
          event.reason == lk.DisconnectReason.clientInitiated
              ? CallFailure.dropped
              : CallFailure.unreachable,
        ));
      })
      ..on<lk.DataReceivedEvent>((event) {
        // Anything on this channel came from the other phone, so it is only
        // as trustworthy as their build. Decoded defensively and ignored
        // unless it is exactly the shape we send — a malformed payload must
        // never take the call down.
        try {
          final decoded = jsonDecode(utf8.decode(event.data));
          if (decoded is Map && decoded['t'] == 'reaction') {
            final emoji = decoded['emoji'];
            if (emoji is String && emoji.isNotEmpty && emoji.length <= 8) {
              _events.add(CallReactionReceived(emoji));
            }
          }
        } catch (_) {
          // Not ours, or not valid. Silence is the right response.
        }
      })
      ..on<lk.ActiveSpeakersChangedEvent>((event) {
        // Local audio is in this list too; the ripple is about *them*.
        final speaking =
            event.speakers.any((s) => s.sid != room0.localParticipant?.sid);
        _events.add(CallPartnerSpeaking(speaking));
      });

    try {
      await room0.connect(_url, token);
      await room0.localParticipant?.setMicrophoneEnabled(true);
      if (_isVideo) {
        await room0.localParticipant?.setCameraEnabled(true);
      }
    } on lk.MediaConnectException catch (_) {
      // Signalling worked and media did not — the shape a carrier-level
      // block takes, and the reason this failure is worth its own branch.
      _events.add(const CallFailed(CallFailure.unreachable));
    } catch (error) {
      _events.add(CallFailed(_readFailure(error)));
    }
  }

  /// LiveKit surfaces a refused microphone as a platform exception rather
  /// than a typed error, so the message is what there is to go on. A wrong
  /// guess here costs a slightly off explanation, never a broken call.
  CallFailure _readFailure(Object error) {
    final text = '$error'.toLowerCase();
    if (text.contains('permission') ||
        text.contains('notallowed') ||
        text.contains('denied')) {
      return CallFailure.noPermission;
    }
    return CallFailure.unreachable;
  }

  @override
  Future<void> leave() async {
    final room = _room;
    // Cleared first so the disconnect handler knows this teardown is ours
    // and does not report a hang-up as a dropped call.
    _room = null;
    await _listener?.dispose();
    _listener = null;
    await room?.disconnect();
    await room?.dispose();
  }

  @override
  Future<void> setMicEnabled(bool enabled) async {
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    if (!_isVideo) return;
    await _room?.localParticipant?.setCameraEnabled(enabled);
  }

  @override
  Future<void> sendReaction(String emoji) async {
    final local = _room?.localParticipant;
    if (local == null) return;
    // Reliable: a dropped tulip is a gesture that silently did not happen,
    // and there is no retry the user could reasonably make sense of.
    await local.publishData(
      utf8.encode(jsonEncode({'t': 'reaction', 'emoji': emoji})),
      reliable: true,
    );
  }

  @override
  Future<void> dispose() async {
    await leave();
    await _events.close();
  }
}

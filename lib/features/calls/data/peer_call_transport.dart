import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/call.dart';
import 'call_repository.dart';
import 'call_transport.dart';
import 'native_calls.dart';

/// Carries the call directly between the two phones.
///
/// 🔴 **No media server.** Every room in this app has exactly two people in
/// it, always — `CallRepository.roomFor` derives one room per pair, and a
/// pair is two. An SFU exists to mix and forward many participants, and with
/// two it is a very expensive wire: modelled at 5,000 pairs it was about
/// 90% of the whole running cost. Two phones talking to each other cost
/// nothing.
///
/// What still needs a server is the part that is not media:
///
/// - **Signalling** — the offer, the answer and the ICE candidates, so each
///   phone learns how to reach the other. That goes over Supabase Realtime
///   broadcast on a private channel per pair (migration 0050), which is
///   ephemeral: nothing is written down, because a description of a
///   connection is worthless the moment the call ends.
/// - **STUN**, to learn what this phone's address looks like from outside.
///   Free, and enough for most calls.
/// - **TURN**, to relay the ones that cannot reach each other at all. On
///   mobile networks that is roughly a fifth to a quarter of calls. ⚠️ With
///   no TURN configured those calls simply fail — see `hasRelay`.
///
/// Written to the same [CallTransport] interface as [LiveKitCallTransport],
/// which is what made replacing the provider one file rather than a rewrite.
class PeerCallTransport implements CallTransport {
  PeerCallTransport({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;
  final _events = StreamController<CallEvent>.broadcast();

  rtc.RTCPeerConnection? _pc;
  rtc.MediaStream? _local;
  rtc.MediaStream? _remote;
  rtc.RTCDataChannel? _data;
  RealtimeChannel? _signals;
  Timer? _speaking;

  /// Bumps whenever the local or remote picture changes, so the video
  /// widgets rebuild. The streams themselves are not [Listenable].
  final tracks = ValueNotifier<int>(0);

  bool _isVideo = false;
  String _me = '';

  /// Whether this phone is the one that sends the offer.
  ///
  /// ⚠️ Decided by comparing user ids, not by who dialled. Both sides derive
  /// the same answer from data they already hold, so there is no round trip
  /// to agree on it and no chance of two offers crossing (which is the
  /// "glare" every naive signalling implementation hits).
  bool _offers = false;

  /// Candidates that arrived before there was a remote description to
  /// attach them to. Adding one early throws, and dropping it can cost the
  /// only route that would have worked.
  final _earlyIce = <rtc.RTCIceCandidate>[];
  bool _remoteSet = false;

  /// Whether the media ever connected. A failure after this is a dropped
  /// call; before it, a call that never reached them.
  bool _wasConnected = false;
  bool _ended = false;

  /// Whether this build has a relay for the calls that cannot go direct.
  /// False means a fifth or so of calls will fail on strict networks, and
  /// the app should say so rather than blaming itself.
  bool hasRelay = false;

  /// Live streams, for the two widgets that render actual video. The
  /// deliberate crack in the abstraction — a frame is a texture, not a fact,
  /// so it cannot travel as a [CallEvent]. See call_video.dart.
  rtc.MediaStream? get localStream => _local;
  rtc.MediaStream? get remoteStream => _remote;

  @override
  bool get isConfigured => true;

  @override
  Stream<CallEvent> get events => _events.stream;

  @override
  Future<void> join({
    required String room,
    required CallMode mode,
    required String identity,
  }) async {
    _isVideo = mode == CallMode.video;
    _me = identity;
    _ended = false;
    _wasConnected = false;
    _remoteSet = false;

    final pairId = CallRepository.pairOf(room);
    if (pairId == null) {
      _events.add(const CallFailed(CallFailure.unreachable));
      return;
    }

    try {
      final ice = await _iceServers();
      _local = await rtc.navigator.mediaDevices.getUserMedia({
        'audio': true,
        // 640x480 at most: this is a phone call between two people, and a
        // higher capture only costs battery and the relay's bandwidth.
        'video': _isVideo
            ? {
                'facingMode': 'user',
                'width': {'ideal': 640},
                'height': {'ideal': 480},
                'frameRate': {'ideal': 24},
              }
            : false,
      });
      tracks.value++;

      final pc = await rtc.createPeerConnection({
        'iceServers': ice,
        // Bundle everything onto one transport, so a call needs one hole
        // through the network rather than one per track.
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
        'sdpSemantics': 'unified-plan',
      });
      _pc = pc;

      for (final track in _local!.getTracks()) {
        await pc.addTrack(track, _local!);
      }

      pc.onTrack = (event) {
        if (event.streams.isEmpty) return;
        _remote = event.streams.first;
        tracks.value++;
      };
      pc.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        _send('ice', {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };
      pc.onConnectionState = _onConnectionState;
      pc.onDataChannel = (channel) => _bindData(channel);

      await _openSignals(pairId);
      await NativeCalls.invoke('startActive', {'video': _isVideo});
      await _routeAudio();
      _events.add(const CallConnected());
      _watchSpeaking();
    } catch (error) {
      debugPrint('Dayflower peer call setup failed: ${error.runtimeType}');
      _events.add(CallFailed(_readFailure(error)));
    }
  }

  /// STUN always, and a relay when one is configured. From the `turn` edge
  /// function, which mints Cloudflare's short-lived credentials — see its
  /// header for why this cannot come from Postgres.
  Future<List<Map<String, dynamic>>> _iceServers() async {
    try {
      final response = await _client.functions.invoke('turn');
      final body = response.data;
      if (body is Map) {
        hasRelay = body['has_relay'] == true;
        final servers = (body['servers'] as List?) ?? const [];
        if (servers.isNotEmpty) {
          return [
            for (final s in servers)
              if (s is Map) Map<String, dynamic>.from(s),
          ];
        }
      }
    } catch (e) {
      // A call with public STUN and no relay still connects for most
      // people, which is a better failure than refusing to dial.
      debugPrint('ice servers unavailable, falling back to STUN: $e');
    }
    hasRelay = false;
    return const [
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {'urls': 'stun:stun.l.google.com:19302'},
    ];
  }

  /// The private channel both phones meet on. Authorised by RLS on
  /// `realtime.messages`, so only the two people in this pair can hear it.
  Future<void> _openSignals(String pairId) async {
    final channel = _client.channel(
      'call:$pairId',
      opts: const RealtimeChannelConfig(private: true),
    );
    _signals = channel;

    channel.onBroadcast(event: 'signal', callback: _onSignal);

    final ready = Completer<void>();
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (!ready.isCompleted) ready.complete();
        // Both sides announce themselves, and both answer an announcement,
        // so whichever joined second still learns about the first.
        _send('hello', const {});
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        if (!ready.isCompleted) ready.complete();
        debugPrint('call signalling failed: $status $error');
        if (!_wasConnected) {
          _events.add(const CallFailed(CallFailure.unreachable));
        }
      }
    });
    await ready.future.timeout(const Duration(seconds: 12), onTimeout: () {});
  }

  void _send(String type, Map<String, dynamic> body) {
    final channel = _signals;
    if (channel == null) return;
    channel.sendBroadcastMessage(
      event: 'signal',
      payload: {'t': type, 'from': _me, ...body},
    );
  }

  /// Lexicographic on the user ids: the smaller id offers. Both phones
  /// compute the same answer without asking each other.
  bool _offersAgainst(String? them) =>
      them != null && _me.compareTo(them) < 0;

  Future<void> _onSignal(Map<String, dynamic> payload) async {
    // Everything here came off the wire from the other phone, so it is only
    // as trustworthy as their build. Anything malformed is ignored rather
    // than allowed to take the call down.
    try {
      final from = payload['from'];
      if (from is! String || from.isEmpty || from == _me) return;
      final pc = _pc;
      if (pc == null) return;

      switch (payload['t']) {
        case 'hello':
          // Answer it, so the phone that was already here is discovered by
          // the one that just arrived and vice versa.
          _send('hey', const {});
          await _maybeOffer(from, pc);
        case 'hey':
          await _maybeOffer(from, pc);
        case 'offer':
          final sdp = payload['sdp'];
          if (sdp is! String) return;
          await pc.setRemoteDescription(rtc.RTCSessionDescription(sdp, 'offer'));
          await _drainIce(pc);
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          _send('answer', {'sdp': answer.sdp});
        case 'answer':
          final sdp = payload['sdp'];
          if (sdp is! String) return;
          // A second answer for a connection already up would tear it down.
          if (pc.signalingState !=
              rtc.RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
            return;
          }
          await pc
              .setRemoteDescription(rtc.RTCSessionDescription(sdp, 'answer'));
          await _drainIce(pc);
        case 'ice':
          final candidate = rtc.RTCIceCandidate(
            payload['candidate'] as String?,
            payload['sdpMid'] as String?,
            (payload['sdpMLineIndex'] as num?)?.toInt(),
          );
          if (_remoteSet) {
            await pc.addCandidate(candidate);
          } else {
            _earlyIce.add(candidate);
          }
        case 'bye':
          if (!_ended) {
            _ended = true;
            _events.add(const CallPartnerLeft());
          }
      }
    } catch (e) {
      debugPrint('call signal ignored: $e');
    }
  }

  /// Offers once, and only from the side that owns the offer.
  Future<void> _maybeOffer(String them, rtc.RTCPeerConnection pc) async {
    if (!_offersAgainst(them)) return;
    if (_offers) return;
    _offers = true;
    // The reactions channel rides the same connection, created by whichever
    // side offers so there is exactly one of it.
    _bindData(await pc.createDataChannel(
      'dayflower',
      rtc.RTCDataChannelInit()..ordered = true,
    ));
    final offer = await pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _isVideo,
    });
    await pc.setLocalDescription(offer);
    _send('offer', {'sdp': offer.sdp});
  }

  Future<void> _drainIce(rtc.RTCPeerConnection pc) async {
    _remoteSet = true;
    for (final candidate in _earlyIce) {
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        debugPrint('late ice candidate refused: $e');
      }
    }
    _earlyIce.clear();
  }

  void _bindData(rtc.RTCDataChannel channel) {
    _data = channel;
    channel.onMessage = (message) {
      try {
        final decoded = jsonDecode(message.text);
        if (decoded is Map && decoded['t'] == 'reaction') {
          final emoji = decoded['emoji'];
          if (emoji is String && emoji.isNotEmpty && emoji.length <= 8) {
            _events.add(CallReactionReceived(emoji));
          }
        }
      } catch (_) {
        // Not ours, or not valid. Silence is the right response.
      }
    };
  }

  void _onConnectionState(rtc.RTCPeerConnectionState state) {
    switch (state) {
      case rtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        if (!_wasConnected) {
          _wasConnected = true;
          _events.add(const CallPartnerJoined());
          // The route is settled only now on the dialling side: see
          // _routeAudio.
          _routeAudio();
        }
      case rtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        if (_ended) return;
        _ended = true;
        // 🔴 Told apart deliberately. Never connected on a build with no
        // relay is the network refusing a direct path, which is the one
        // failure the operator can actually fix; after connecting it is an
        // ordinary drop.
        _events.add(CallFailed(
          _wasConnected ? CallFailure.dropped : CallFailure.unreachable,
        ));
      case rtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        // Not terminal on its own: mobile networks flap, and WebRTC
        // recovers from this by itself more often than not. Failed is what
        // means gone.
        break;
      default:
        break;
    }
  }

  /// Sends the call's audio where the phone is being held: speaker for
  /// video, earpiece for voice. A headset still wins either way.
  ///
  /// ⚠️ Re-asserted when the connection comes up, not only at the start.
  /// The same trap LiveKit had: whoever dials sets up the audio session with
  /// nothing playing, and the route chosen then is the wrong one.
  Future<void> _routeAudio() async {
    try {
      await rtc.Helper.setSpeakerphoneOn(_isVideo);
    } catch (e) {
      debugPrint('call audio routing failed: $e');
    }
  }

  /// Their voice, for the ripple on the voice screen. Polled from the
  /// connection's own statistics: WebRTC has no event for "they are
  /// talking", and this is the one thing that makes a voice call feel like a
  /// live line rather than a timer on a still image.
  void _watchSpeaking() {
    var last = false;
    _speaking?.cancel();
    _speaking = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      final pc = _pc;
      if (pc == null) return;
      try {
        double level = 0;
        for (final report in await pc.getStats()) {
          final values = report.values;
          final audio = values['audioLevel'];
          // Inbound only: our own microphone is in here too, and the ripple
          // is about them.
          final inbound = report.type == 'inbound-rtp' ||
              (report.type == 'track' && values['remoteSource'] == true);
          if (inbound && audio is num) {
            level = level > audio.toDouble() ? level : audio.toDouble();
          }
        }
        final speaking = level > 0.02;
        if (speaking != last) {
          last = speaking;
          _events.add(CallPartnerSpeaking(speaking));
        }
      } catch (_) {
        // Statistics are a nicety; a call does not stop for them.
      }
    });
  }

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
    _ended = true;
    _speaking?.cancel();
    _speaking = null;
    // Told before the wire goes, so the other phone shows "call ended"
    // rather than waiting for a timeout to notice.
    _send('bye', const {});

    try {
      await NativeCalls.invoke('stopActive');
    } catch (e) {
      debugPrint('Dayflower call service cleanup failed: ${e.runtimeType}');
    }

    final channel = _signals;
    _signals = null;
    if (channel != null) {
      try {
        await _client.removeChannel(channel);
      } catch (e) {
        debugPrint('call channel teardown failed: $e');
      }
    }

    try {
      await _data?.close();
    } catch (_) {}
    _data = null;

    // ⚠️ Tracks stopped before the connection closes, or the camera light
    // stays on after the call.
    for (final track in _local?.getTracks() ?? const []) {
      try {
        await track.stop();
      } catch (_) {}
    }
    try {
      await _local?.dispose();
    } catch (_) {}
    _local = null;
    _remote = null;
    tracks.value++;

    final pc = _pc;
    _pc = null;
    try {
      await pc?.close();
      await pc?.dispose();
    } catch (e) {
      debugPrint('peer connection teardown failed: $e');
    }
    _offers = false;
    _earlyIce.clear();
  }

  @override
  Future<void> setMicEnabled(bool enabled) async {
    for (final track in _local?.getAudioTracks() ?? const []) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    if (!_isVideo) return;
    for (final track in _local?.getVideoTracks() ?? const []) {
      track.enabled = enabled;
    }
    tracks.value++;
  }

  @override
  Future<void> setCameraFront(bool front) async {
    final track = _local?.getVideoTracks().firstOrNull;
    if (track == null) return;
    try {
      // ⚠️ Switches the lens underneath the same track, so the far side sees
      // a brief still rather than the video dropping out and coming back.
      await rtc.Helper.switchCamera(track);
    } catch (e) {
      debugPrint('camera flip failed: $e');
    }
  }

  @override
  Future<void> sendReaction(String emoji) async {
    final channel = _data;
    if (channel == null) return;
    try {
      await channel.send(
          rtc.RTCDataChannelMessage(jsonEncode({'t': 'reaction', 'emoji': emoji})));
    } catch (e) {
      debugPrint('reaction not delivered: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await leave();
    tracks.dispose();
    await _events.close();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

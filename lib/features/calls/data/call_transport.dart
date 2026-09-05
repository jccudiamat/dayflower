import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../domain/call.dart';
import 'livekit_call_transport.dart';

/// Something happening to the media session, in the app's own vocabulary.
///
/// Deliberately small. Every provider worth using (LiveKit, Daily, Agora)
/// emits a much richer stream than this — track subscriptions, quality
/// scores, per-participant state — and none of it changes what the screen
/// draws. Translating down to these five at the edge is what keeps the
/// controller and the UI free of any provider's types.
sealed class CallEvent {
  const CallEvent();
}

/// This phone is in the room. Not yet a conversation — the partner may not
/// have joined.
class CallConnected extends CallEvent {
  const CallConnected();
}

/// Both of you are in. This is what starts the timer.
class CallPartnerJoined extends CallEvent {
  const CallPartnerJoined();
}

/// They hung up, or dropped out and did not come back.
class CallPartnerLeft extends CallEvent {
  const CallPartnerLeft();
}

/// Their microphone is carrying speech. Drives the ripple on the voice
/// screen — the one thing that makes a voice call feel like a live line
/// rather than a timer on a still image.
class CallPartnerSpeaking extends CallEvent {
  const CallPartnerSpeaking(this.speaking);
  final bool speaking;
}

/// They sent a flower. Arrives on the data channel, not as media.
class CallReactionReceived extends CallEvent {
  const CallReactionReceived(this.emoji);
  final String emoji;
}

/// Terminal. Carries the reason in the user's terms, not the transport's.
class CallFailed extends CallEvent {
  const CallFailed(this.failure);
  final CallFailure failure;
}

/// The media session, behind one door.
///
/// Implemented by [LiveKitCallTransport] and, for a build with no
/// `LIVEKIT_URL`, by [UnconfiguredCallTransport]. Nothing above this
/// interface knows which one it has, which is what keeps the notifier and
/// the screens free of provider types — and what would make swapping to
/// Daily or a self-hosted server one new file rather than a rewrite.
abstract class CallTransport {
  /// False when the build has no calling service configured. The UI asks
  /// before it dials, so an unconfigured build says so immediately instead
  /// of showing a spinner that can only ever time out.
  bool get isConfigured;

  Stream<CallEvent> get events;

  /// Joins [room], publishing a microphone track always and a camera track
  /// only for [CallMode.video].
  Future<void> join({
    required String room,
    required CallMode mode,
    required String identity,
  });

  Future<void> leave();

  Future<void> setMicEnabled(bool enabled);

  /// A no-op on a voice call. The screen never offers the control there, but
  /// the transport must not assume the screen is the only caller.
  Future<void> setCameraEnabled(bool enabled);

  /// Throws a flower to the other side.
  ///
  /// Deliberately not a chat message: it belongs to the call, expires with
  /// it, and posting one row per tulip would fill the thread with confetti.
  /// Goes over the data channel, which every provider worth using has.
  Future<void> sendReaction(String emoji);

  Future<void> dispose();
}

/// What ships until a provider is chosen.
///
/// It fails, immediately and honestly. The alternative — a transport that
/// pretends to connect so the in-call screen can be demonstrated — would put
/// a screen in the app that lies about being on a call, and someone would
/// eventually ship it.
class UnconfiguredCallTransport implements CallTransport {
  final _events = StreamController<CallEvent>.broadcast();

  @override
  bool get isConfigured => false;

  @override
  Stream<CallEvent> get events => _events.stream;

  @override
  Future<void> join({
    required String room,
    required CallMode mode,
    required String identity,
  }) async {
    _events.add(const CallFailed(CallFailure.notConfigured));
  }

  @override
  Future<void> leave() async {}

  @override
  Future<void> setMicEnabled(bool enabled) async {}

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> sendReaction(String emoji) async {}

  @override
  Future<void> dispose() async => _events.close();
}

/// The URL of the media server, or null when this build has none.
///
/// Read from `.env` the same way the Supabase keys are, so a phone build and
/// the web preview pick it up identically and no key is ever committed.
/// Adding `LIVEKIT_URL` to `.env` is what switches calling on.
String? get callServerUrl {
  final url = dotenv.env['LIVEKIT_URL']?.trim();
  return (url == null || url.isEmpty) ? null : url;
}

/// The transport this build will use.
///
/// `LIVEKIT_URL` in `.env` is the switch. Absent, the app says calling is
/// not switched on rather than dialling into nothing — which is also what a
/// build with the URL but no Vault secrets gets, from the server side (see
/// migration 0026).
final callTransportProvider = Provider<CallTransport>((ref) {
  final url = callServerUrl;
  final transport = url == null
      ? UnconfiguredCallTransport()
      : LiveKitCallTransport(
          url: url,
          client: ref.watch(supabaseClientProvider),
        );
  ref.onDispose(transport.dispose);
  return transport;
});

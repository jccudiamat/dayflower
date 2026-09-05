import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';
import '../../tulip/data/flower_repository.dart';
import '../data/call_repository.dart';
import '../data/call_transport.dart';
import '../data/call_usage.dart';
import 'call.dart';

/// The call this phone is in, from tap to hang-up.
///
/// Holds one [CallSession] or null, and owns the only two things a call
/// screen cannot work out for itself: what the transport is doing, and how
/// long the media has been up.
///
/// Everything provider-specific is behind [CallTransport]. This class never
/// learns which service is carrying the call, which is what lets the whole
/// feature be written, reviewed and screenshotted before that is decided.
class CallNotifier extends StateNotifier<CallSession?> {
  CallNotifier(this._ref) : super(null);

  final Ref _ref;

  StreamSubscription<CallEvent>? _events;

  /// Redraws the timer. One second is the resolution the timer is displayed
  /// at, so anything finer would be repainting for nothing.
  Timer? _tick;

  CallRepository get _calls => _ref.read(callRepositoryProvider);
  CallTransport get _transport => _ref.read(callTransportProvider);

  /// Starts a call and writes it into the thread.
  ///
  /// The row lands first and the media is attempted second — see
  /// [CallRepository.start]. A call that never connects still leaves a
  /// bubble the partner can answer, which on a restricted network is the
  /// difference between a broken feature and a slow one.
  Future<void> place(CallMode mode) async {
    final pair = _ref.read(currentPairProvider).valueOrNull;
    final userId = _ref.read(currentUserIdProvider);
    if (pair == null || !pair.isLinked || userId == null) return;

    // Already in one. Tapping the header during a call is a no-op rather
    // than a second room nobody is in.
    if (state != null && !state!.status.isTerminal) return;

    // The hard stop, checked before the row is written rather than after.
    // A call row inserted here would put a Join bubble in the thread that
    // nobody can answer — an invitation to a call that cannot happen is
    // worse than the refusal.
    //
    // Only blocks the *outgoing* side: [join] deliberately has no such
    // check, because a call your partner already started is one their
    // half of the allowance is paying for, and refusing to answer it
    // would strand them alone in a room.
    final usage = _ref.read(callUsageProvider).valueOrNull;
    if (usage != null && usage.isSpent(mode)) {
      state = CallSession(
        messageId: '',
        room: CallRepository.roomFor(pair.id),
        mode: mode,
        status: CallStatus.failed,
        isCaller: true,
        failure: CallFailure.quotaExhausted,
      );
      return;
    }

    final room = CallRepository.roomFor(pair.id);
    state = CallSession(
      // Filled in by the insert below. Until then the screen has everything
      // it needs to draw itself, which is what keeps the tap instant.
      messageId: '',
      room: room,
      mode: mode,
      status: CallStatus.dialling,
      isCaller: true,
      cameraEnabled: mode == CallMode.video,
    );

    final FlowerMessage message;
    try {
      message = await _calls.start(
        pairId: pair.id,
        senderId: userId,
        mode: mode,
      );
    } catch (_) {
      // The thread write failed, so there is nothing for them to answer and
      // no point negotiating media. This is the one failure that is really
      // about the network, and it is the one case where saying so is true.
      _fail(CallFailure.unreachable);
      return;
    }

    state = CallSession(
      messageId: message.id,
      room: message.callRoom ?? room,
      mode: mode,
      status: CallStatus.connecting,
      isCaller: true,
      cameraEnabled: mode == CallMode.video,
    );

    await _connect(identity: userId);
  }

  /// Joins a call already in the thread — from the ring screen, from the
  /// header, or from a Join bubble sent twenty minutes ago.
  ///
  /// All four entry points land here, so a call has exactly one way of
  /// starting on the receiving side.
  Future<void> join(FlowerMessage message) async {
    final userId = _ref.read(currentUserIdProvider);
    final mode = message.call;
    if (userId == null || mode == null) return;
    if (state != null && !state!.status.isTerminal) return;

    state = CallSession(
      messageId: message.id,
      room: message.callRoom ?? CallRepository.roomFor(message.pairId),
      mode: mode,
      status: CallStatus.connecting,
      isCaller: false,
      cameraEnabled: mode == CallMode.video,
    );

    await _connect(identity: userId);
  }

  /// Answers the call already on screen.
  ///
  /// Separate from [join] because the ring screen holds a [CallSession], not
  /// the row it came from — and re-reading the row to answer a call already
  /// described in memory would be a round-trip between the tap and the
  /// audio.
  Future<void> answer() async {
    final session = state;
    final userId = _ref.read(currentUserIdProvider);
    if (session == null || userId == null) return;
    if (session.status != CallStatus.ringing) return;

    state = session.copyWith(status: CallStatus.connecting);
    await _connect(identity: userId);
  }

  /// Shows the incoming call without answering it. The receiver's first
  /// screen: their name, the ripple, Answer and Not now.
  void ring(FlowerMessage message) {
    final mode = message.call;
    if (mode == null) return;
    if (state != null && !state!.status.isTerminal) return;

    state = CallSession(
      messageId: message.id,
      room: message.callRoom ?? CallRepository.roomFor(message.pairId),
      mode: mode,
      status: CallStatus.ringing,
      isCaller: false,
      cameraEnabled: mode == CallMode.video,
    );
  }

  Future<void> _connect({required String identity}) async {
    final session = state;
    if (session == null) return;

    // Asked before dialling rather than after a timeout: a build with no
    // calling service should say so in the moment the button is pressed,
    // not after fifteen seconds of a spinner that could never succeed.
    if (!_transport.isConfigured) {
      _fail(CallFailure.notConfigured);
      return;
    }

    _events?.cancel();
    _events = _transport.events.listen(_onEvent);

    try {
      await _transport.join(
        room: session.room,
        mode: session.mode,
        identity: identity,
      );
    } catch (_) {
      _fail(CallFailure.unreachable);
    }
  }

  void _onEvent(CallEvent event) {
    final session = state;
    if (session == null || session.status.isTerminal) return;

    switch (event) {
      case CallConnected():
        // In the room, alone. Still "connecting" as far as the person
        // holding the phone is concerned — there is no conversation yet.
        state = session.copyWith(status: CallStatus.connecting);

      case CallPartnerJoined():
        // The timer starts here, not at the tap. Seconds spent waiting for
        // someone to pick up are not part of the call.
        state = session.copyWith(
          status: CallStatus.live,
          startedAt: session.startedAt ?? DateTime.now(),
        );
        _startTicking();

      case CallPartnerLeft():
        hangUp();

      case CallPartnerSpeaking(:final speaking):
        // Voice only. On video you can see them, and a ring breathing over
        // their face is noise.
        if (!session.isVideo && speaking != session.partnerSpeaking) {
          state = session.copyWith(partnerSpeaking: speaking);
        }

      case CallReactionReceived(:final emoji):
        _addReaction(emoji, mine: false);

      case CallFailed(:final failure):
        _fail(failure);
    }
  }

  /// Throws a flower to the other side, and puts the same one on this
  /// screen immediately.
  ///
  /// Optimistic on purpose: the sender should see their own tulip the
  /// instant they tap, not after a data-channel round trip. If the send
  /// fails the flower is still on your screen and not on theirs — which is
  /// the same as any gesture that did not land, and not worth an error
  /// dialog mid-call.
  Future<void> sendReaction(String emoji) async {
    if (state == null) return;
    _addReaction(emoji, mine: true);
    try {
      await _transport.sendReaction(emoji);
    } catch (_) {
      // Deliberately silent — see above.
    }
  }

  void _addReaction(String emoji, {required bool mine}) {
    final session = state;
    if (session == null) return;
    final next = [
      // Expired ones are dropped here rather than filtered at render, so
      // the list never grows without bound over a long call.
      ...session.reactions.where((r) => !r.isExpired),
      CallReaction(
        id: '${DateTime.now().microsecondsSinceEpoch}-$mine',
        emoji: emoji,
        mine: mine,
        at: DateTime.now(),
      ),
    ];
    state = session.copyWith(reactions: next);
  }

  Future<void> toggleMic() async {
    final session = state;
    if (session == null) return;
    final next = !session.micEnabled;
    state = session.copyWith(micEnabled: next);
    await _transport.setMicEnabled(next);
  }

  /// No-op on a voice call — there is no camera track to toggle, and the
  /// screen never draws the control.
  Future<void> toggleCamera() async {
    final session = state;
    if (session == null || !session.isVideo) return;
    final next = !session.cameraEnabled;
    state = session.copyWith(cameraEnabled: next);
    await _transport.setCameraEnabled(next);
  }

  /// Hangs up, from either side, in any state.
  ///
  /// Order matters: the transport is torn down first so the media stops the
  /// instant the button is pressed, and the row is closed after. A failed
  /// row update leaves a call the thread thinks is live — which
  /// [FlowerMessage.isLiveCall] ages out on its own after two hours.
  Future<void> hangUp() async {
    final session = state;
    if (session == null) return;

    _stopTicking();
    await _events?.cancel();
    _events = null;
    await _transport.leave();

    // 🔴 Cleared, not left at `ended`. The call screen pops on a *null*
    // session, and `ended` is not one of the statuses its switch handles —
    // so hanging up used to stop the timer and strand the user on a dead
    // call screen with no way out. The record of the call lives in the
    // thread; there is nothing for this screen to stay open for.
    state = null;

    // Only the row's own call needs closing, and only if it was ever
    // written — a call that failed before the insert has nothing to end.
    if (session.messageId.isNotEmpty) {
      try {
        await _calls.end(session.messageId);
        // The minutes just spent are only counted once the row is closed
        // (migration 0027 ignores live calls), so this is the first moment
        // the meter could be right. Without it the ended-call line in the
        // thread would quote a remainder from before the call it is
        // reporting on.
        _ref.invalidate(callUsageProvider);
      } catch (_) {
        // Deliberately swallowed. The call is over on this phone either
        // way, and surfacing a hang-up error would be reporting a failure
        // for something the user has already finished doing.
      }
    }
  }

  /// Declines without answering. Ends the call for both — a two-person app
  /// has no third party for the caller to keep waiting on.
  Future<void> decline() => hangUp();

  /// Leaves the call screen. Separate from [hangUp] because a terminal
  /// session stays on screen until it is dismissed, so the failure can be
  /// read.
  void dismiss() {
    if (state?.status.isTerminal ?? false) state = null;
  }

  void _fail(CallFailure failure) {
    _stopTicking();
    _events?.cancel();
    _events = null;
    state = state?.copyWith(status: CallStatus.failed, failure: failure);
  }

  void _startTicking() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      // The session is immutable and `elapsed` is computed from
      // `startedAt`, so re-emitting the same object would not rebuild
      // anything. copyWith with no arguments makes a new instance, which is
      // what the timer is for.
      final session = state;
      if (session == null) return;
      final live = session.reactions.where((r) => !r.isExpired).toList();
      state = live.length == session.reactions.length
          ? session.copyWith()
          : session.copyWith(reactions: live);
    });
  }

  void _stopTicking() {
    _tick?.cancel();
    _tick = null;
  }

  @override
  void dispose() {
    _stopTicking();
    _events?.cancel();
    super.dispose();
  }
}

final callNotifierProvider =
    StateNotifierProvider<CallNotifier, CallSession?>((ref) {
  return CallNotifier(ref);
});

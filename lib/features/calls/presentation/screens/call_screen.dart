import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../app_router.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/timezone_picker.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../data/call_pip.dart';
import '../../data/call_usage.dart';
import '../../domain/call.dart';
import '../../domain/call_notifier.dart';
import '../widgets/call_video.dart';

/// The call, in all four of its states.
///
/// One screen rather than four routes: a call moves between ringing,
/// connecting, live and failed without ever being a different *place*, and
/// routing each state would put a back stack behind a phone call.
///
/// Dark throughout, per design.md's dual-mode rule — a call is a journey
/// screen, not a utility one. The gradient appears exactly once: on Answer
/// while ringing, on the retry CTA when it failed, and nowhere at all during
/// a live call, where nothing should compete with the other person.
class CallScreen extends ConsumerWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(callNotifierProvider);
    final partner = ref.watch(partnerProfileStreamProvider).valueOrNull ??
        ref.watch(partnerProfileProvider).valueOrNull;

    // Nothing to show. Reached by hanging up — the notifier clears the
    // session, and this screen takes itself off the stack rather than
    // leaving a dead call on screen.
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.canPop() ? context.pop() : context.go(Routes.chat);
        }
      });
      return const Scaffold(backgroundColor: AppColors.darkCanvas);
    }

    // In the floating window: video and nothing else. A PiP window is a few
    // hundred pixels wide and takes no touches at all, so controls rendered
    // into it are an unreadable wall of buttons nobody can press.
    if (ref.watch(pipModeProvider)) {
      return _PipView(session: session, partner: partner);
    }

    return PopScope(
      // 🔴 Back used to **hang up**. It was the safe reading once — leaving
      // the screen mid-call would strand the user in a call they could not
      // see or end — but it made the back gesture the most destructive
      // control on the screen, and destructive by accident.
      //
      // It minimises now. The call keeps running in the floating window,
      // which is both where it can still be seen and how it gets back.
      canPop: session.status.isTerminal,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // ⚠️ Only when the system will actually take it. Without PiP there
        // is no floating window to leave the call in, and popping anyway
        // would recreate exactly the invisible-call problem this used to
        // guard against — so on those devices back still does nothing.
        CallPip.enter();
      },
      child: Scaffold(
        backgroundColor: AppColors.darkCanvas,
        body: switch (session.status) {
          CallStatus.failed => _FailureView(session: session),
          // Hanging up clears the session, which is what pops this route.
          // Listed explicitly so a terminal call can never fall through to
          // the live view — that is what stranded the user on a dead call
          // screen with a stopped timer.
          CallStatus.ended => const SizedBox.shrink(),
          CallStatus.ringing || CallStatus.dialling => _RingingView(
              session: session,
              partner: partner,
            ),
          _ => _LiveView(session: session, partner: partner),
        },
      ),
    );
  }
}

/* ── Ringing / dialling ─────────────────────────────── */

/// What both sides see before the call connects.
///
/// The same layout for the caller and the receiver, differing only in the
/// line under the name and whether Answer is offered. They are the same
/// moment from two ends, and building them as two screens would be two
/// things to keep in step for no gain.
class _RingingView extends ConsumerWidget {
  const _RingingView({required this.session, required this.partner});

  final CallSession session;
  final UserProfile? partner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(callNotifierProvider.notifier);
    final name = partner?.petName ?? partner?.displayName ?? 'Them';
    final isRinging = session.status == CallStatus.ringing;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Dayflower ${session.mode.label.toLowerCase()}',
              style: AppText.label(AppColors.onDarkMuted),
            ),
            // Optically centred rather than top-packed: with a single
            // Spacer above the buttons the identity block sat against the
            // status bar with a third of the screen empty beneath it.
            const Spacer(flex: 3),
            _CallRipple(
              // Dialling pulses, waiting doesn't: the ripple means "reaching
              // out", and on the receiving end the reaching has arrived.
              active: true,
              child: UserAvatar(partner, size: 96),
            ),
            const SizedBox(height: AppSpace.md),
            Text(name, style: AppText.hero(AppColors.onDark)),
            const SizedBox(height: 2),
            _PartnerClock(partner: partner),
            const SizedBox(height: AppSpace.md),
            Text(
              isRinging
                  ? 'is calling you'
                  : session.status == CallStatus.dialling
                      ? 'Calling…'
                      : 'Connecting…',
              style: AppText.body(AppColors.onDarkMuted),
            ),
            const Spacer(flex: 4),
            Row(
              mainAxisAlignment: isRinging
                  ? MainAxisAlignment.spaceEvenly
                  : MainAxisAlignment.center,
              children: [
                _AnswerButton(
                  label: isRinging ? 'Not now' : 'Cancel',
                  color: AppColors.danger,
                  icon: CupertinoIcons.phone_down_fill,
                  onTap: notifier.decline,
                ),
                if (isRinging)
                  _AnswerButton(
                    label: 'Answer',
                    gradient: AppGradients.cta,
                    icon: session.isVideo
                        ? CupertinoIcons.video_camera_solid
                        : CupertinoIcons.phone_fill,
                    onTap: notifier.answer,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ── Live ───────────────────────────────────────────── */

class _LiveView extends ConsumerWidget {
  const _LiveView({required this.session, required this.partner});

  final CallSession session;
  final UserProfile? partner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(callNotifierProvider.notifier);
    final name = partner?.petName ?? partner?.displayName ?? 'Them';
    final elapsed = session.elapsed;

    return Stack(
      fit: StackFit.expand,
      children: [
        // On video, their camera fills the screen behind everything else.
        // On voice there is nothing to render, so the plum canvas stays and
        // the ripple carries the screen instead.
        if (session.isVideo)
          RemoteVideo(session: session)
        else
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppGradients.hero),
            child: SizedBox.expand(),
          ),
        _ReactionOverlay(reactions: session.reactions),
        if (session.isVideo) _SelfView(session: session),

        // ⚠️ Centred, not in the header. "Connecting…" used to sit in the
        // timer's pill in the top corner, which is where a *clock* belongs
        // — but this is the only thing happening on the screen at the time,
        // and the corner is where you put what can be ignored.
        if (session.isVideo && elapsed == null)
          const Center(child: _Connecting()),

        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                // The self-view used to live here, beside the timer. It is
                // a free-floating layer now — see _SelfView — because a
                // tile you can move is a tile that can get out of the way
                // of their face, and one pinned into a Row cannot.
                child: _CallHeader(name: name, elapsed: elapsed),
              ),
              const Spacer(),

              // Voice has no picture, so it gets the person instead: their
              // avatar, and a ring that breathes while they are talking.
              // This is the whole difference between a voice call and a
              // stopwatch on a dark screen.
              if (!session.isVideo) ...[
                _CallRipple(
                  active: session.partnerSpeaking,
                  child: UserAvatar(partner, size: 108),
                ),
                const SizedBox(height: AppSpace.md),
                Text(name, style: AppText.hero(AppColors.onDark)),
                const SizedBox(height: 2),
                Text(
                  session.status == CallStatus.live
                      ? (session.partnerSpeaking ? 'Talking' : 'On the line')
                      : 'Connecting…',
                  style: AppText.caption(AppColors.onDarkMuted),
                ),
              ],

              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 26),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The one control here that is not about plumbing. First
                    // in the row so it is the easiest to reach mid-sentence,
                    // and furthest from End.
                    _ControlButton(
                      icon: CupertinoIcons.smiley,
                      emoji: '🌷',
                      onTap: () => notifier.sendReaction('🌷'),
                      tooltip: 'Send a tulip',
                    ),
                    const SizedBox(width: 12),
                    _ControlButton(
                      icon: session.micEnabled
                          ? CupertinoIcons.mic_fill
                          : CupertinoIcons.mic_slash_fill,
                      // Filled means "off", matching design.md rule 7's
                      // logic: state is shown by inverting the surface, not
                      // by striking the icon through.
                      inverted: !session.micEnabled,
                      onTap: notifier.toggleMic,
                      tooltip: session.micEnabled ? 'Mute' : 'Unmute',
                    ),
                    if (session.isVideo) ...[
                      const SizedBox(width: 12),
                      _ControlButton(
                        icon: CupertinoIcons.video_camera_solid,
                        inverted: !session.cameraEnabled,
                        onTap: notifier.toggleCamera,
                        tooltip: session.cameraEnabled
                            ? 'Turn camera off'
                            : 'Turn camera on',
                      ),
                    ],
                    const SizedBox(width: 12),
                    _ControlButton(
                      icon: CupertinoIcons.phone_down_fill,
                      color: AppColors.danger,
                      onTap: notifier.hangUp,
                      tooltip: 'End',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ── Failed ─────────────────────────────────────────── */

/// The state this app's users are most likely to actually meet.
///
/// It names what happened, says what still works, and offers the thread back
/// — never a spinner that keeps trying, and never a line blaming the user's
/// connection for a call their carrier declined to carry.
class _FailureView extends ConsumerWidget {
  const _FailureView({required this.session});

  final CallSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(callNotifierProvider.notifier);
    final failure = session.failure ?? CallFailure.unreachable;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.danger.withValues(alpha: .12),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: .45),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: AppColors.danger,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              failure.title,
              textAlign: TextAlign.center,
              style: AppText.title(AppColors.onDark),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              // Only the quota failure names a date, and it has to be
              // computed rather than written into the enum — "the 1st" is
              // true but "1 October" is what someone can plan around.
              failure == CallFailure.quotaExhausted
                  ? 'Calling comes back on '
                      '${DateFormat('d MMMM').format(CallUsage.resetsOn)}. '
                      'Messages, flowers and heartbeats are all still yours.'
                  : failure.detail,
              textAlign: TextAlign.center,
              style: AppText.body(AppColors.onDarkMuted),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: _PillButton(
                label: 'Back to the chat',
                gradient: AppGradients.cta,
                onTap: () {
                  notifier.dismiss();
                  context.canPop() ? context.pop() : context.go(Routes.chat);
                },
              ),
            ),
            // Two failures cannot be retried into success — an unconfigured
            // build and a spent allowance both fail identically every time.
            // A button whose only outcome is the screen you are already on
            // is not an escape, it is a taunt.
            if (failure != CallFailure.notConfigured &&
                failure != CallFailure.quotaExhausted) ...[
              const SizedBox(height: AppSpace.xs),
              SizedBox(
                width: double.infinity,
                child: _PillButton(
                  label: 'Try again',
                  onTap: () {
                    notifier.dismiss();
                    notifier.place(session.mode);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ── Pieces ─────────────────────────────────────────── */

/// The lavender ripple, borrowed from the heartbeat rather than reinvented.
///
/// Three rings on one controller, staggered by phase, so the whole thing is
/// a single animation and not three that can drift apart.
class _CallRipple extends StatefulWidget {
  const _CallRipple({required this.child, required this.active});

  final Widget child;

  /// False holds the rings still and faint — a call that is up but silent
  /// should not look like one that is trying to reach someone.
  final bool active;

  @override
  State<_CallRipple> createState() => _CallRippleState();
}

class _CallRippleState extends State<_CallRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(_CallRipple old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      height: 148,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++) _ring((_c.value + i / 3) % 1),
              child!,
            ],
          );
        },
        child: widget.child,
      ),
    );
  }

  Widget _ring(double t) {
    // Fades in fast and out slowly across the sweep, so a ring is never
    // born or killed at full opacity.
    final opacity =
        widget.active ? (t < .18 ? t / .18 : 1 - (t - .18) / .82) : .22;
    final scale = .62 + t * .56;
    return Opacity(
      opacity: opacity.clamp(0, 1) * .85,
      child: Transform.scale(
        scale: widget.active ? scale : 1,
        child: Container(
          width: 148,
          height: 148,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: .55),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Their local time, under their name.
///
/// The one question worth answering before you pick up in a long-distance
/// relationship, and the app already computes it for the clocks on Home.
class _PartnerClock extends ConsumerWidget {
  const _PartnerClock({required this.partner});

  final UserProfile? partner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = partner?.timezone;
    if (zone == null || zone.isEmpty) return const SizedBox.shrink();
    final now = tz.TZDateTime.now(safeLocation(zone));
    final city = zone.split('/').last.replaceAll('_', ' ');
    return Text(
      '$city · ${DateFormat('h:mm a').format(now)}',
      style: AppText.caption(AppColors.onDarkMuted),
    );
  }
}

/// Back, their name, and the clock — a column in the top-left corner.
///
/// The name is here because a video call fills the screen with a face and
/// nothing else: on a glance at a locked-then-unlocked phone, whose call
/// this is was the one thing the screen never said.
class _CallHeader extends StatelessWidget {
  const _CallHeader({required this.name, required this.elapsed});

  final String name;
  final Duration? elapsed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⚠️ Minimise, not close. It looks like a back button because
            // that is the gesture it answers — and leaving a call by going
            // back should put it in the floating window, never end it.
            Semantics(
              button: true,
              label: 'Minimise the call',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: CallPip.enter,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.darkCanvas.withValues(alpha: .5),
                  ),
                  child: const Icon(
                    CupertinoIcons.chevron_back,
                    size: 20,
                    color: AppColors.onDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              name,
              style: AppText.title(AppColors.onDark).copyWith(
                shadows: const [
                  Shadow(color: Color(0x99000000), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // No clock until media is up: one sitting at 00:00 reads as a
            // call that connected and went silent. The connecting state has
            // the middle of the screen instead.
            if (elapsed != null) _Timer(elapsed: elapsed),
          ],
        ),
      ],
    );
  }
}

/// "Connecting…", in the middle, where the only thing happening goes.
class _Connecting extends StatelessWidget {
  const _Connecting();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCanvas.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.onDark.withValues(alpha: .1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.onDark,
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          Text('Connecting…', style: AppText.body(AppColors.onDark)),
        ],
      ),
    );
  }
}

/// The call as a floating window.
///
/// ⚠️ Video and nothing else. A PiP window is a few hundred pixels wide and
/// **takes no touches** — Android routes taps to "expand" and gives the app
/// nothing — so every control rendered here would be an unreadable button
/// that cannot be pressed. Tapping the window restores the full screen,
/// which is the maximise the floating window needs.
class _PipView extends StatelessWidget {
  const _PipView({required this.session, required this.partner});

  final CallSession session;
  final UserProfile? partner;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.darkCanvas,
      child: session.isVideo
          ? RemoteVideo(session: session)
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(partner, size: 64),
                  const SizedBox(height: AppSpace.xs),
                  // The clock is the whole reason a voice call is worth
                  // floating rather than just being a notification.
                  _Timer(elapsed: session.elapsed),
                ],
              ),
            ),
    );
  }
}

class _Timer extends StatelessWidget {
  const _Timer({required this.elapsed});

  final Duration? elapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.darkCanvas.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.onDark.withValues(alpha: .09)),
      ),
      child: Text(
        // No timer until media is up: a clock sitting at 00:00 reads as a
        // call that has connected and gone silent.
        elapsed == null ? 'Connecting…' : formatCallDuration(elapsed!),
        style: AppText.caption(AppColors.onDark).copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Your own camera: bigger than it was, draggable, and dismissible.
///
/// Three complaints in one widget. It was 74×104 and pinned beside the
/// timer, which made it too small to read your own framing and impossible
/// to move off their face — and there was no way to be rid of it at all.
///
/// Position and hidden-ness are deliberately **local state, not session
/// state**. Where you park your own thumbnail is not something the other
/// side, the notifier, or a reconnect should ever know or reset.
class _SelfView extends StatefulWidget {
  const _SelfView({required this.session});

  final CallSession session;

  @override
  State<_SelfView> createState() => _SelfViewState();
}

class _SelfViewState extends State<_SelfView> {
  // ⚠️ Sized so you can actually read your own framing. It has grown twice
  // — 74×104, then 112×158 — and this is the size at which a glance tells
  // you whether you are in shot.
  static const _size = Size(150, 210);
  static const _hiddenSize = Size(48, 48);
  static const _margin = 14.0;

  /// Null until first laid out, so the tile can start pinned to the
  /// top-right of whatever screen it actually finds itself on rather than
  /// at a guessed offset.
  Offset? _position;
  bool _hidden = false;

  Size get _currentSize => _hidden ? _hiddenSize : _size;

  void _drag(DragUpdateDetails details) {
    final bounds = MediaQuery.sizeOf(context);
    setState(() {
      _position = _clamp(
        (_position ?? _defaultPosition(bounds)) + details.delta,
        bounds,
      );
    });
  }

  Offset _defaultPosition(Size bounds) => Offset(
        bounds.width - _size.width - _margin,
        MediaQuery.paddingOf(context).top + _margin,
      );

  /// Keeps the tile fully on screen — after a drag, after hiding (which
  /// changes its size), and after a rotation.
  Offset _clamp(Offset value, Size bounds) {
    final safeTop = MediaQuery.paddingOf(context).top + _margin;
    return Offset(
      value.dx.clamp(_margin, bounds.width - _currentSize.width - _margin),
      value.dy.clamp(safeTop, bounds.height - _currentSize.height - 120),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bounds = MediaQuery.sizeOf(context);
    final position = _clamp(_position ?? _defaultPosition(bounds), bounds);

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        // 🔴 `opaque`, not the default. GestureDetector defers hit testing
        // to its child, and none of what the tile is made of — SizedBox,
        // ClipRRect, DecoratedBox, the video texture — registers a hit. So
        // the only draggable pixel was the hide button, which is a real
        // GestureDetector of its own. This makes the whole tile the grab
        // target, which is what makes it feel like an object rather than a
        // control with a handle.
        behavior: HitTestBehavior.opaque,
        onPanUpdate: _drag,
        onTap: _hidden ? () => setState(() => _hidden = false) : null,
        child: _hidden ? _restoreButton() : _tile(),
      ),
    );
  }

  Widget _tile() {
    return Stack(
      children: [
        LocalVideo(
          session: widget.session,
          width: _size.width,
          height: _size.height,
        ),

        // 🔴 **The drag layer, and it has to be above the video.** The
        // outer GestureDetector is `HitTestBehavior.opaque`, which should
        // have been enough — but the tile's whole face is a LiveKit
        // renderer, and a platform view consumes the touch before it ever
        // reaches an ancestor. So the only draggable pixel was the eye
        // button, which is a real GestureDetector sitting *on top* of the
        // video. This is that, for the rest of the tile.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: _drag,
          ),
        ),
        // Top-left, away from the thumb that just dragged it in from the
        // right, and small enough not to cover your own face.
        Positioned(
          left: 4,
          top: 4,
          child: GestureDetector(
            onTap: () => setState(() => _hidden = true),
            child: Semantics(
              button: true,
              label: 'Hide your self-view',
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.darkCanvas.withValues(alpha: .6),
                ),
                alignment: Alignment.center,
                // An eye, deliberately — this hides the *view*, it does
                // not turn the camera off. A camera glyph here would read
                // as a second, contradictory camera button.
                child: const Icon(
                  CupertinoIcons.eye_slash_fill,
                  size: 14,
                  color: AppColors.onDark,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// What is left when it is hidden: an eye, in the same place the tile
  /// was, so bringing it back happens where putting it away did.
  Widget _restoreButton() {
    return Semantics(
      button: true,
      label: 'Show your self-view',
      child: Container(
        width: _hiddenSize.width,
        height: _hiddenSize.height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.darkCanvas.withValues(alpha: .72),
          border: Border.all(color: AppColors.onDark.withValues(alpha: .18)),
        ),
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.eye_fill,
          size: 20,
          color: AppColors.onDark,
        ),
      ),
    );
  }
}

/// Flowers in flight, floating up over the call.
///
/// Each reaction gets its own controller keyed by id, so a second tulip sent
/// while the first is still rising animates on its own rather than
/// restarting the one already on screen. Yours drift up the right, theirs up
/// the left — the same sides the two of you occupy in the thread.
class _ReactionOverlay extends StatelessWidget {
  const _ReactionOverlay({required this.reactions});

  final List<CallReaction> reactions;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final reaction in reactions)
            _FloatingReaction(key: ValueKey(reaction.id), reaction: reaction),
        ],
      ),
    );
  }
}

class _FloatingReaction extends StatefulWidget {
  const _FloatingReaction({super.key, required this.reaction});

  final CallReaction reaction;

  @override
  State<_FloatingReaction> createState() => _FloatingReactionState();
}

class _FloatingReactionState extends State<_FloatingReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: CallReaction.lifetime,
  )..forward();

  /// A small horizontal offset so a burst of tulips fans out instead of
  /// stacking into one thick line.
  late final double _drift = (widget.reaction.id.hashCode % 40 - 20) / 100;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Align(
          // Rises from just above the controls to a little past halfway.
          alignment: Alignment(
            (widget.reaction.mine ? 0.55 : -0.55) + _drift,
            0.62 - t * 1.1,
          ),
          child: Opacity(
            // Holds full opacity for most of the climb, then fades — a
            // linear fade reads as the flower being taken away rather than
            // drifting off.
            opacity: (t < 0.7 ? 1.0 : (1 - t) / 0.3).clamp(0.0, 1.0),
            child: Transform.scale(
              // Pops in, then settles.
              scale: t < 0.15 ? 0.6 + t / 0.15 * 0.5 : 1.1 - t * 0.2,
              child: Text(
                widget.reaction.emoji,
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.inverted = false,
    this.color,
    this.emoji,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool inverted;
  final Color? color;

  /// Drawn in place of [icon] when set. The tulip is the artwork, not a
  /// glyph standing in for it — an outline flower icon would be the one
  /// button on this screen that looked like every other app's.
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final background = color ??
        (inverted
            ? AppColors.onDark.withValues(alpha: .9)
            : AppColors.onDark.withValues(alpha: .12));
    final foreground = color != null
        ? Colors.white
        : (inverted ? AppColors.ink : AppColors.onDark);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background,
              border: Border.all(
                color: color != null
                    ? Colors.transparent
                    : AppColors.onDark.withValues(alpha: .1),
              ),
            ),
            // 🔴 Centred explicitly. A Container with width/height passes
            // tight constraints, and an Icon centres itself inside them
            // while a Text aligns top-left — so the tulip sat high and to
            // the left while every other control looked fine. `height: 1`
            // matters too: emoji carry their own line metrics, which push
            // the glyph off-centre even inside a Center.
            alignment: Alignment.center,
            child: emoji == null
                ? Icon(icon, color: foreground, size: 22)
                : Text(
                    emoji!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, height: 1),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.gradient,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                gradient: gradient,
                boxShadow: gradient != null ? AppElevation.glow : null,
              ),
              child: Icon(icon, color: Colors.white, size: 27),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(label, style: AppText.caption(AppColors.onDarkMuted)),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap, this.gradient});

  final String label;
  final VoidCallback onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: gradient == null
              ? Border.all(color: AppColors.darkBorder, width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: AppText.subtitle(
            gradient != null ? Colors.white : AppColors.onDark,
          ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

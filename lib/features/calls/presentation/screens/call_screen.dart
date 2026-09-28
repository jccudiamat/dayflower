import 'dart:async';

import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../app_router.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/util/clamp_offset.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/timezone_picker.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../data/call_pip.dart';
import '../widgets/ring_light.dart';
import '../../data/ring_light_prefs.dart';
import '../../data/call_alerts.dart';
import '../../data/call_usage.dart';
import '../../domain/call.dart';
import '../../domain/call_notifier.dart';
import '../widgets/call_video.dart';
import '../game_mode.dart';

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
    // ⚠️ The banner goes as soon as this screen is up. It was staying on
    // top of the ring screen — the same call announced twice, once as a
    // notification over the thing it was announcing. Dismissed rather than
    // stopped: stop() would forget that nobody has answered yet, and a call
    // ignored from here would never be reported missed.
    if (session != null && session.status == CallStatus.ringing) {
      CallAlerts.dismissBanner();
    }
    if (session != null && session.status == CallStatus.ringing &&
        CallAlerts.pendingAnswerId == session.messageId) {
      CallAlerts.pendingAnswerId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        final current = ref.read(callNotifierProvider);
        if (current?.messageId != session.messageId ||
            current?.status != CallStatus.ringing) {
          return;
        }
        await CallAlerts.stop();
        await ref.read(callNotifierProvider.notifier).answer();
      });
    }
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

    // ⚠️ The floating window is **not** decided here any more — see
    // CallPipGate. Deciding it from inside this route meant it only worked
    // while this route was on top, and a minimised call is by definition one
    // you have walked away from.

    // 🔴 **Back leaves the screen; it does not leave the app.**
    //
    // It has been wrong twice. First it *hung up* — the most destructive
    // control on the screen, and destructive by accident. Then it entered
    // picture-in-picture, which is a floating window over the *launcher*:
    // pressing back inside the app put you outside it.
    //
    // Now it pops, and `_CallMiniBar` in the shell keeps the call one tap
    // away. The floating window is for leaving the app — Home, recents, or
    // a back that would close Dayflower — and MainActivity owns those.
    return PopScope(
      canPop: true,
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

class _LiveView extends ConsumerStatefulWidget {
  const _LiveView({required this.session, required this.partner});

  final CallSession session;
  final UserProfile? partner;

  @override
  ConsumerState<_LiveView> createState() => _LiveViewState();
}

class _LiveViewState extends ConsumerState<_LiveView> {
  /// Whether the header and the controls are on screen.
  ///
  /// ⚠️ Tapping the picture hides them, which is what every video call does
  /// — the thing you are looking at is the other person, and a row of
  /// buttons across the bottom of their face is the app in the way.
  bool _chrome = true;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final partner = widget.partner;
    final notifier = ref.read(callNotifierProvider.notifier);
    final name = partner?.petName ?? partner?.displayName ?? 'Them';
    final elapsed = session.elapsed;
    final ringOn = session.isVideo && ref.watch(ringLightProvider);

    // 🔴 The navigation bar is outside the app's own canvas on most phones,
    // so a light painted to the bottom of the screen stopped at a black bar
    // and never reached the bottom edge. While the light is on, the bar is
    // the light's colour (with dark buttons on it); otherwise the call's.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (ringOn ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor:
            ringOn ? RingLight.glow : AppColors.darkCanvas,
        systemNavigationBarDividerColor:
            ringOn ? RingLight.glow : AppColors.darkCanvas,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Stack(
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
        // ⚠️ Below the self-view and the controls in the stack, so it only
        // catches taps that missed them — dragging your own tile or
        // reaching for Mute must not also toggle the chrome.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _chrome = !_chrome),
          ),
        ),
        // 🔴 Over the video, under everything you can press. It is a light,
        // not a surface: RingLight ignores pointers, so Mute and End are
        // still exactly where they look.
        if (ringOn)
          Positioned.fill(
            child: RingLight(thickness: ref.watch(ringLightWidthProvider)),
          ),
        _ReactionOverlay(reactions: session.reactions),
        if (session.isVideo)
          CallSelfView(
            session: session,
            onSwitchCamera: notifier.switchCamera,
          ),

        // ⚠️ Centred, not in the header. "Connecting…" used to sit in the
        // timer's pill in the top corner, which is where a *clock* belongs
        // — but this is the only thing happening on the screen at the time,
        // and the corner is where you put what can be ignored.
        if (session.isVideo && elapsed == null)
          const Center(child: _Connecting()),

        SafeArea(
          child: Column(
            children: [
              // Up and out of the way, rather than simply vanishing —
              // sliding says where it went and how to think about getting
              // it back.
              _Chrome(
                visible: _chrome,
                offset: const Offset(0, -0.6),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  // The self-view used to live here, beside the timer. It
                  // is a free-floating layer now — see CallSelfView — because
                  // a tile you can move is a tile that can get out of the
                  // way of their face, and one pinned into a Row cannot.
                  child: _CallHeader(name: name, elapsed: elapsed),
                ),
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
              _Chrome(
                visible: _chrome,
                offset: const Offset(0, 1.2),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
                  child: _ControlBar(session: session, name: name),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}

/* ── Controls ───────────────────────────────────────── */

/// The controls, Google Meet's way: the everyday ones in one bar, and the
/// rest behind ⋮ in a sheet (the ring light, and game mode).
///
/// 🔴 The ring light used to be a fifth button in the row, with its width
/// slider stacked over the controls whenever it was on. A bar that grows
/// with every feature ends up as a wall of buttons over their face; the
/// things you set once a call go in the sheet.
class _ControlBar extends ConsumerWidget {
  const _ControlBar({required this.session, required this.name});

  final CallSession session;

  /// Theirs, for the words asking to float the call.
  final String name;

  static const _gap = SizedBox(width: 8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(callNotifierProvider.notifier);
    // ⋮ only when there is something behind it: the ring light on video,
    // game mode on a phone that can float a call.
    final more = session.isVideo ||
        (ref.watch(gameModeSupportedProvider).valueOrNull ?? false);

    // Scaled down, never wrapped or cut, on a phone too narrow for it.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.darkSurface.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.onDark.withValues(alpha: .08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (session.isVideo) ...[
              _ControlButton(
                icon: CupertinoIcons.video_camera_solid,
                inverted: !session.cameraEnabled,
                onTap: notifier.toggleCamera,
                tooltip: session.cameraEnabled
                    ? 'Turn camera off'
                    : 'Turn camera on',
              ),
              _gap,
            ],
            _ControlButton(
              icon: session.micEnabled
                  ? CupertinoIcons.mic_fill
                  : CupertinoIcons.mic_slash_fill,
              // Filled means "off", matching design.md rule 7's logic:
              // state is shown by inverting the surface, not by striking
              // the icon through.
              inverted: !session.micEnabled,
              onTap: notifier.toggleMic,
              tooltip: session.micEnabled ? 'Mute' : 'Unmute',
            ),
            _gap,
            // Where Meet keeps its reactions. The tulip is the artwork, not
            // a glyph standing in for it.
            _ControlButton(
              icon: CupertinoIcons.smiley,
              emoji: '🌷',
              onTap: () => notifier.sendReaction('🌷'),
              tooltip: 'Send a tulip',
            ),
            if (more) ...[
              _gap,
              _ControlButton(
                icon: CupertinoIcons.ellipsis_vertical,
                width: 44,
                onTap: () => _more(context, ref),
                tooltip: 'More options',
              ),
            ],
            // End stands apart: the one control that cannot be undone.
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: AppColors.onDark.withValues(alpha: .14),
            ),
            _ControlButton(
              icon: CupertinoIcons.phone_down_fill,
              color: AppColors.danger,
              width: 68,
              onTap: notifier.hangUp,
              tooltip: 'End',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _more(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<_More>(
      context: context,
      backgroundColor: AppColors.darkSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _MoreSheet(),
    );
    if (picked == _More.gameMode && context.mounted) {
      await _gameMode(context, ref);
    }
  }

  /// Floats the call, asking for "Display over other apps" first if it has
  /// never been given.
  Future<void> _gameMode(BuildContext context, WidgetRef ref) async {
    final game = ref.read(gameModeProvider.notifier);
    final result = await game.start();
    if (!context.mounted) return;
    switch (result) {
      case GameModeStart.needsPermission:
        final go = await showDialog<bool>(
          context: context,
          builder: (_) => _GameModePermission(name: name),
        );
        if (go == true) await game.askPermission();
      case GameModeStart.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't float the call. Try again?")),
        );
      case GameModeStart.floating || GameModeStart.unsupported:
        break;
    }
  }
}

enum _More { gameMode }

/// What is behind ⋮. Meet's sheet: a handle, then big rounded tiles.
class _MoreSheet extends ConsumerWidget {
  const _MoreSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(callNotifierProvider);
    final video = session?.isVideo ?? false;
    final ringOn = ref.watch(ringLightProvider);
    final canFloat = ref.watch(gameModeSupportedProvider).valueOrNull ?? false;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.onDark.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                // ⚠️ Only on video. It is the screen at full brightness
                // around your face, which means nothing on a voice call.
                if (video)
                  Expanded(
                    child: _SheetTile(
                      icon: CupertinoIcons.light_max,
                      label: 'Ring light',
                      selected: ringOn,
                      onTap: () =>
                          ref.read(ringLightProvider.notifier).toggle(),
                    ),
                  ),
                if (video && canFloat) const SizedBox(width: 12),
                if (canFloat)
                  Expanded(
                    child: _SheetTile(
                      icon: CupertinoIcons.gamecontroller,
                      label: 'Game mode',
                      onTap: () => Navigator.of(context).pop(_More.gameMode),
                    ),
                  ),
              ],
            ),
            // How wide the light is, right under the switch that turned it
            // on, while it is on.
            if (video && ringOn) ...[
              const SizedBox(height: 12),
              const _RingWidthSlider(),
            ],
          ],
        ),
      ),
    );
  }
}

/// One tile in the ⋮ sheet. Lit, in the ring light's own colour, while what
/// it switches is on.
class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // darkCanvas, not ink: ink follows the app's theme and is near-white
    // in dark mode, and this screen is dark in both.
    final foreground = selected ? AppColors.darkCanvas : AppColors.onDark;
    return Semantics(
      button: true,
      toggled: selected ? true : null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? RingLight.glow
            : AppColors.onDark.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 96,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(icon, size: 24, color: foreground),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: AppText.body(foreground)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asked once, the first time game mode is used: Android keeps drawing over
/// other apps behind a switch in Settings, and sending someone there without
/// saying why is how the switch stays off.
class _GameModePermission extends StatelessWidget {
  const _GameModePermission({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      icon: const AppIcon(
        CupertinoIcons.gamecontroller,
        size: 30,
        color: AppColors.onDark,
      ),
      title: Text(
        'Play together, still together',
        textAlign: TextAlign.center,
        style: AppText.title(AppColors.onDark),
      ),
      content: Text(
        'Game mode shrinks the call to a small circle over your game, so you '
        'can still see and hear $name while you play. Tap the circle to '
        'come back.\n\n'
        'Android needs you to let Dayflower display over other apps. It is '
        'one switch, and you only do it once.',
        style: AppText.body(AppColors.onDarkMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Not now', style: AppText.body(AppColors.onDarkMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Open settings',
            style: AppText.body(AppColors.brandLight)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// How wide the ring light is, in the ⋮ sheet under its switch. Narrow at
/// the left and wide at the right, as the icons at its ends say.
class _RingWidthSlider extends ConsumerWidget {
  const _RingWidthSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = ref.watch(ringLightWidthProvider);
    final notifier = ref.read(ringLightWidthProvider.notifier);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.onDark.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          const AppIcon(CupertinoIcons.light_min,
              size: 18, color: AppColors.onDark),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: RingLight.glow,
                inactiveTrackColor: AppColors.onDark.withValues(alpha: .25),
                thumbColor: RingLight.glow,
                overlayColor: RingLight.glow.withValues(alpha: .18),
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 9),
              ),
              child: Slider(
                value: width,
                min: RingLight.minThickness,
                max: RingLight.maxThickness,
                semanticFormatterCallback: (v) =>
                    'Ring light width ${v.round()}',
                onChanged: notifier.preview,
                onChangeEnd: notifier.save,
              ),
            ),
          ),
          const AppIcon(CupertinoIcons.light_max,
              size: 20, color: AppColors.onDark),
        ],
      ),
    );
  }
}

/// The header and the controls, on their way in or out.
///
/// ⚠️ `IgnorePointer` while hidden. A faded-out row of buttons still takes
/// taps, so without it End would still be sitting under your thumb after you
/// had asked for it to go away — invisible and live is the worst of both.
class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.visible,
    required this.offset,
    required this.child,
  });

  final bool visible;

  /// Where it goes when hidden, in fractions of its own size. The header
  /// leaves upward and the controls downward — each off its nearest edge.
  final Offset offset;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : offset,
      duration: AppMotion.standard,
      curve: AppMotion.easeOut,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppMotion.standard,
        curve: AppMotion.easeOut,
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
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
              child: const AppIcon(
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
            // Nor a call that has ended: "Try again" would ring them, which
            // is not what trying to join the old one meant.
            if (failure != CallFailure.notConfigured &&
                failure != CallFailure.quotaExhausted &&
                failure != CallFailure.ended) ...[
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

/// Leaves the call screen without leaving the call.
///
/// ⚠️ `canPop` covers the deep-link case: arriving here from a call
/// notification leaves nothing underneath, and popping an empty stack would
/// close the app — the same bug in a different disguise.
void _leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.chat);
  }
}

/// Back, their name, and the clock — a column in the top-left corner.
///
/// The name is here because a video call fills the screen with a face and
/// nothing else: on a glance at a locked-then-unlocked phone, whose call
/// this is was the one thing the screen never said.
class _CallHeader extends StatelessWidget {
  const _CallHeader({required this.name, required this.elapsed});

  /// Between the button and the name — and the clock's indent, so the clock
  /// starts exactly where the name does.
  static const _nameGap = AppSpace.xs;

  final String name;
  final Duration? elapsed;

  @override
  Widget build(BuildContext context) {
    // 🔴 **The clock is on its own line, and the back button ignores it.**
    //
    // It was a Row of [button, Column(name, clock)], which centres the
    // button against *both* lines — so the chevron floated at the midpoint
    // between the name and the clock and the three of them read as fighting
    // for one row. The button belongs beside the name and nothing else.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // ⚠️ Leaves the screen, not the call. See _leave: it pops back
            // to the conversation and the call keeps playing in the corner.
            Semantics(
              button: true,
              label: 'Back to the conversation',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _leave(context),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.darkCanvas.withValues(alpha: .5),
                  ),
                  child: const AppIcon(
                    CupertinoIcons.chevron_back,
                    size: 20,
                    color: AppColors.onDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: _nameGap),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title(AppColors.onDark).copyWith(
                  shadows: const [
                    Shadow(color: Color(0x99000000), blurRadius: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Under the name, indented past the button so the two line up. No
        // clock until media is up: one sitting at 00:00 reads as a call that
        // connected and went silent.
        if (elapsed != null)
          Padding(
            padding: const EdgeInsets.only(left: 38 + _nameGap, top: 4),
            child: _Timer(elapsed: elapsed),
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
/// The call as the floating window, and **only** the call.
///
/// 🔴 It used to be a branch inside [CallScreen], which meant it only drew
/// the call when the call screen happened to be the route on top. Minimise
/// the call inside the app, walk to the conversation, then press Home — and
/// picture-in-picture floated *the conversation*, scaled down. The whole app
/// in a small window, which is not what minimising a call means.
///
/// It is a layer above the router now: see `CallPipGate`. What is on the
/// stack underneath stops mattering.
class CallPipView extends ConsumerWidget {
  const CallPipView({super.key, required this.session});

  final CallSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(partnerProfileStreamProvider).valueOrNull ??
        ref.watch(partnerProfileProvider).valueOrNull;
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

/// Replaces the whole app with the call while the floating window is up.
///
/// ⚠️ Above the router on purpose. A PiP window renders whatever activity is
/// showing, so deciding what goes in it from inside a *route* only ever works
/// while that route is on top — and the entire point of minimising a call is
/// that you have gone somewhere else.
class CallPipGate extends ConsumerWidget {
  const CallPipGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(pipModeProvider)) return child;
    final session = ref.watch(callNotifierProvider);
    // 🔴 **No call left to show: the window is closing.** A call that ended
    // while floating used to leave the window up with the rest of the app
    // shrunk inside it. The Activity now closes the window whenever the
    // call stops, or it floats with no call at all (leavePip in
    // MainActivity), and until it has, this is the dark of the call rather
    // than a flash of the app.
    if (session == null || session.status.isTerminal) {
      return const ColoredBox(color: AppColors.darkCanvas);
    }
    return CallPipView(session: session);
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
///
/// Public for its test only; the call screen is the one place it lives.
class CallSelfView extends StatefulWidget {
  const CallSelfView({
    super.key,
    required this.session,
    required this.onSwitchCamera,
  });

  final CallSession session;
  final VoidCallback onSwitchCamera;

  /// How long the tile's two buttons stay up after the last touch.
  static const controlsFor = Duration(seconds: 3);

  @override
  State<CallSelfView> createState() => _SelfViewState();
}

class _SelfViewState extends State<CallSelfView> {
  // ⚠️ Sized so you can actually read your own framing. It has grown twice
  // — 74×104, then 112×158 — and this is the size at which a glance tells
  // you whether you are in shot.
  static const _size = callTileSize;
  static const _hiddenSize = Size(48, 48);
  static const _margin = 14.0;

  /// Null until first laid out, so the tile can start pinned to the
  /// top-right of whatever screen it actually finds itself on rather than
  /// at a guessed offset.
  Offset? _position;
  bool _hidden = false;

  /// Whether the tile's buttons are showing. They go after
  /// [CallSelfView.controlsFor] untouched, so they are not sat on your own
  /// face for the whole call, and a tap on the tile brings them back.
  bool _controls = true;
  Timer? _fade;

  Size get _currentSize => _hidden ? _hiddenSize : _size;

  @override
  void initState() {
    super.initState();
    _wake();
  }

  @override
  void dispose() {
    _fade?.cancel();
    super.dispose();
  }

  /// Shows the buttons, and starts the count to putting them away again.
  void _wake() {
    _fade?.cancel();
    if (!_controls) setState(() => _controls = true);
    _fade = Timer(CallSelfView.controlsFor, () {
      if (mounted) setState(() => _controls = false);
    });
  }

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
  Offset _clamp(Offset value, Size bounds) => clampToBox(
        value: value,
        box: bounds,
        tile: _currentSize,
        margin: _margin,
        topInset: MediaQuery.paddingOf(context).top,
        // Clear of the controls along the bottom.
        bottomInset: 120,
      );

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
        onTap: _hidden
            ? () {
                setState(() => _hidden = false);
                _wake();
              }
            : null,
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
        // reaches an ancestor. So the only draggable pixel was the hide
        // button, which is a real GestureDetector sitting *on top* of the
        // video. This is that, for the rest of the tile. A tap on it brings
        // the buttons back; so does a drag, which keeps them up until the
        // tile is let go of.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _wake,
            onPanStart: (_) => _wake(),
            onPanUpdate: _drag,
            onPanEnd: (_) => _wake(),
          ),
        ),

        // 🔴 **Along the bottom, and big enough for a thumb.** They were
        // 26pt circles in the top corners, and the camera flip was hard to
        // hit. Bottom corners now, one each side: a tile this narrow still
        // leaves a clear gap between them, and the two do very different
        // things. One hides the view, the other changes what is being sent.
        Positioned(
          left: 4,
          right: 4,
          bottom: 4,
          child: IgnorePointer(
            // Faded out is gone: the first tap on a bare tile brings the
            // buttons back rather than pressing one you cannot see.
            ignoring: !_controls,
            child: AnimatedOpacity(
              duration: AppMotion.standard,
              opacity: _controls ? 1 : 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // A picture with a line through it, deliberately: this
                  // hides the *view*, it does not turn the camera off. A
                  // camera glyph here would read as a second,
                  // contradictory camera button.
                  _TileButton(
                    icon: Icons.hide_image_outlined,
                    label: 'Hide your self-view',
                    onTap: () {
                      _fade?.cancel();
                      setState(() => _hidden = true);
                    },
                  ),
                  // Turn the camera around, on your own picture: the same
                  // place a camera app puts it, and the picture it affects.
                  _TileButton(
                    // Only while there is a picture to turn around. With
                    // the camera off there is nothing to flip and the
                    // button would be a control over a black rectangle.
                    enabled: widget.session.cameraEnabled,
                    onTap: () {
                      widget.onSwitchCamera();
                      _wake();
                    },
                    label: 'Switch camera',
                    icon: CupertinoIcons.camera_rotate_fill,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// What is left when it is hidden: a picture, in the same place the tile
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
        child: const AppIcon(
          CupertinoIcons.photo,
          size: 22,
          color: AppColors.onDark,
        ),
      ),
    );
  }
}

/// A control along the bottom of the self-view tile.
///
/// A 40pt circle inside a 48pt touch target, so a thumb that lands a
/// little off the circle still presses it.
class _TileButton extends StatelessWidget {
  const _TileButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.darkCanvas.withValues(alpha: enabled ? .6 : .3),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              icon,
              size: 21,
              color: AppColors.onDark.withValues(alpha: enabled ? 1 : .4),
            ),
          ),
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
    this.width = 58,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool inverted;
  final Color? color;

  /// Meet's pills are wider than they are tall; ⋮ is narrower, End wider.
  final double width;

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
        // 🔴 darkCanvas, not ink. ink follows the app's theme and is
        // near-white in dark mode, so a muted mic was a white icon on a white
        // button for anyone using it. The call is dark in both themes.
        : (inverted ? AppColors.darkCanvas : AppColors.onDark);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: width,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
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
                ? AppIcon(icon, color: foreground, size: 22)
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
              child: AppIcon(icon, color: Colors.white, size: 27),
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

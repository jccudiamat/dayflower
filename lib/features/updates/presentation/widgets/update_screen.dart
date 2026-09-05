import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cta_button.dart';
import '../../data/app_release.dart';
import '../../data/update_repository.dart';

/// The updater, as a full-screen layer that lives **above the router**.
///
/// 🔴 **It is deliberately not a route, and that is the whole fix.** It used
/// to be a modal bottom sheet raised with `showModalBottomSheet` on the
/// router's navigator, and it flashed up for a frame at launch and vanished
/// before it could be read, let alone tapped.
///
/// Why: a sheet pushed that way is a *pageless* route, and Flutter attaches
/// a pageless route to whichever page was on top when it was pushed. The
/// check fires from a post-frame callback at launch, so that page was the
/// **splash** — and a second later the gate redirect swapped splash for home.
/// Removing a page removes every pageless route attached to it. Nothing was
/// wrong with the sheet; it was tied to a page with a one-second lifespan.
///
/// ⚠️ Any dialog raised during launch has this bug waiting for it. Sitting
/// above the `Navigator` rather than inside it is what makes the routing
/// stack unable to take this away — redirect, replace or pop, it is not in
/// there to be removed.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.child});

  /// ⚠️ Nullable because `MaterialApp`'s builder types it that way. It was
  /// `child!` at the call site, which turns a null into a crash that renders
  /// as a full-screen grey box in release — the same failure mode this
  /// screen was written to fix.
  final Widget? child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  @override
  Widget build(BuildContext context) {
    // 🔴 **There was a `ref.listen` here that cleared the dismissal when a
    // check landed on `available`, and it was both redundant and dangerous.**
    //
    // Dangerous: a `ref.listen` registered during build fires *during that
    // build* if the value already changed, and writing to another provider
    // from inside it throws "Tried to modify a provider while the widget
    // tree was building". This widget is the top of the tree, so that throw
    // renders as a full-screen error box — grey, in release, with no text on
    // it at all.
    //
    // Redundant: a dismissal is stored as a build *number*, so a newer build
    // never matches it and interrupts on its own (see updateIsShowing), and
    // the only other case — asking again for a build already waved off — is
    // Settings, which clears it directly.
    final state = ref.watch(updateControllerProvider);
    final dismissed = ref.watch(updateDismissedProvider);

    return Stack(
      children: [
        if (widget.child != null) widget.child!,
        if (updateIsShowing(state, dismissed))
          // Takes every tap, so the app underneath cannot be driven blind
          // through a screen that is covering it.
          Positioned.fill(
            child: UpdateScreen(
              state: state,
              onDismiss: () => dismissUpdate(ref),
            ),
          ),
      ],
    );
  }
}

/// The build waved off for this session, if any.
///
/// ⚠️ Shared state rather than the gate's own, because the **back button is
/// handled outside the gate** — see `_UpdateBackButtonDispatcher` in app.dart.
/// The layer sits above the `Router`, so there is no `Navigator` and no route
/// to hang a `PopScope` on, and `BackButtonListener` throws up there for the
/// same reason: it looks for a `Router` ancestor and finds none. The Router's
/// own dispatcher is the supported hook, and it needs to be able to see and
/// set this.
///
/// Distinct from `skip()`: skip means "not this build, ever" and is
/// persisted; this means "not while I am in the middle of something".
/// Settings clears it to bring a waved-off build back — the one case a manual
/// check cannot cover, since `check` refuses to run over a downloaded APK.
final updateDismissedProvider = StateProvider<int?>((ref) => null);

/// Whether the updater is currently covering the app.
///
/// Shared by the gate and the back-button dispatcher so the two cannot
/// disagree about whether there is anything on screen to dismiss.
bool updateIsShowing(UpdateState state, int? dismissedBuild) {
  final release = state.release;
  if (release == null) return false;
  if (state.mandatory) return true;
  if (dismissedBuild == release.buildNumber) return false;
  return switch (state.stage) {
    UpdateStage.available ||
    UpdateStage.downloading ||
    UpdateStage.ready ||
    UpdateStage.failed =>
      true,
    _ => false,
  };
}

/// Waves the current build off for this session. No-op when mandatory.
void dismissUpdate(WidgetRef ref) {
  final state = ref.read(updateControllerProvider);
  if (state.mandatory) return;
  ref.read(updateDismissedProvider.notifier).state = state.release?.buildNumber;
  // Recorded as skipped as well, so tomorrow's launch does not open with the
  // same build all over again. `skip` is a no-op when mandatory.
  ref.read(updateControllerProvider.notifier).skip();
}

/// The full-screen updater.
///
/// ⚠️ **The layout is borrowed; the language is not.** The composition came
/// from a reference image — full screen rather than a sheet, the headline
/// stacked, one primary, a quiet secondary under it. The first version copied
/// that reference's *styling* as well: an invented violet ground, a white
/// rounded-rect button, Title Case labels. Each of those was this one screen
/// speaking a language nothing else in the app speaks. Ground, button, motif
/// and casing are Dayflower's own now; only the composition is borrowed.
class UpdateScreen extends ConsumerWidget {
  const UpdateScreen({
    super.key,
    required this.state,
    required this.onDismiss,
  });

  final UpdateState state;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(updateControllerProvider.notifier);
    final release = state.release;
    if (release == null) return const SizedBox.shrink();

    final mandatory = state.mandatory;
    final canDismiss = !mandatory && !state.busy;

    // ⚠️ No BackButtonListener here, and no PopScope: this widget is above
    // the Router, so there is no route and no Router ancestor for either of
    // them to attach to — BackButtonListener throws outright. The back button
    // is handled by the Router's own dispatcher instead. See
    // `_UpdateBackButtonDispatcher` in app.dart.
    return Material(
      color: AppColors.heroTop,
      child: Container(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(flex: 5, child: Center(child: _Bloom())),

                Text(
                  mandatory ? 'Update\nrequired' : 'A new\nDayflower\nis ready',
                  style: AppText.display(AppColors.onDark).copyWith(
                    fontSize: 38,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),

                Text(
                  _bodyText(release, mandatory),
                  style: AppText.body(AppColors.onDarkMuted),
                ),

                if (release.notes.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.sm),
                  for (final note in release.notes.take(3)) _NoteLine(note),
                ],

                if (state.stage == UpdateStage.downloading) ...[
                  const SizedBox(height: AppSpace.md),
                  _Progress(state: state),
                ],

                if (state.error != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  _ErrorNote(state.error!),
                ],

                const Spacer(flex: 2),

                _PrimaryButton(state: state, controller: controller),

                // A required update gets no way out, so it gets no button
                // offering one either. Hidden mid-download too: there is no
                // half of a download worth keeping.
                SizedBox(
                  height: 52,
                  child: canDismiss
                      ? Center(
                          child: TextButton(
                            onPressed: onDismiss,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.onDark,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'Not now',
                              style: AppText.subtitle(AppColors.onDark),
                            ),
                          ),
                        )
                      : null,
                ),

                if (state.stage == UpdateStage.ready)
                  Text(
                    'Android will ask you to confirm. The first time, it also '
                    'asks you to allow installs from Dayflower.',
                    textAlign: TextAlign.center,
                    style: AppText.caption(AppColors.onDarkMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _bodyText(AppRelease release, bool mandatory) {
    final size =
        release.readableSize.isEmpty ? '' : ' · ${release.readableSize}';
    final head = mandatory
        ? 'This build is required to keep using Dayflower.'
        : 'A newer version is ready to install.';
    return '$head\nVersion ${release.versionName} · build '
        '${release.buildNumber}$size';
  }
}

/* ── Pieces ─────────────────────────────────────────────────── */

/// The app's own mark, opening out of the heartbeat's ripple.
///
/// ⚠️ This replaced a soft orb lifted straight from the reference image. Both
/// halves here are already Dayflower's: the tulip is the launcher icon's own
/// artwork, and the expanding rings are the heartbeat widget's ripple in the
/// signature pink→purple. A photograph from `assets/images/flowers/` was the
/// other candidate and would have been wrong — those are the app's *content*,
/// the things you send each other, pasted onto its chrome.
///
/// Animated rather than a GIF: there is no Lottie or Rive in this project, a
/// GIF would be both a new dependency and a far larger asset, and the ripple
/// already exists here as motion rather than as a recording of motion.
class _Bloom extends StatefulWidget {
  const _Bloom();

  @override
  State<_Bloom> createState() => _BloomState();
}

class _BloomState extends State<_Bloom> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 4),
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 236,
      height: 236,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _RipplePainter(_controller.value),
          child: child,
        ),
        // Built once and passed into the painter's child slot, so the ripple
        // repaints without the image being rebuilt on every frame.
        child: Center(
          child: Image.asset(
            'assets/images/mark.png',
            width: 112,
            height: 112,
            // The mark is decoration. A missing asset must not cost the
            // screen that is telling you about an update.
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter(this.t);

  /// 0→1, looping.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // A steady bloom behind the mark, so it sits on something rather than
    // floating on the plum.
    canvas.drawCircle(
      centre,
      maxRadius * .46,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.gradientPurple.withValues(alpha: .38),
            AppColors.gradientPurple.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: centre, radius: maxRadius * .46),
        ),
    );

    // Three rings a third of a cycle apart, so one is always arriving as
    // another fades — the heartbeat widget's ripple, slowed right down.
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final radius = maxRadius * (0.44 + 0.56 * phase);
      final fade = (1 - phase) * .55;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppColors.gradientPink.withValues(alpha: fade),
              AppColors.gradientPurple.withValues(alpha: fade),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) => oldDelegate.t != t;
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.state, required this.controller});

  final UpdateState state;
  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    // ⚠️ AppCtaButton, not a bare ElevatedButton. It carries the signature
    // pink→purple gradient, the pill radius the token file calls for on ALL
    // buttons and chips, and the press-scale every other primary action in
    // the app has. The first version used a white rounded rect because the
    // reference image did — and it was the only ElevatedButton in the
    // entire codebase.
    return switch (state.stage) {
      UpdateStage.downloading => AppCtaButton(
          label: state.progress == null
              ? 'Downloading…'
              : 'Downloading ${(state.progress! * 100).round()}%',
          // Null disables it, which is also what greys the gradient.
          onPressed: null,
        ),
      UpdateStage.ready => AppCtaButton(
          label: 'Install now',
          icon: CupertinoIcons.checkmark_seal,
          onPressed: controller.install,
        ),
      UpdateStage.failed => AppCtaButton(
          label: 'Try again',
          icon: CupertinoIcons.arrow_clockwise,
          onPressed: () {
            controller.reset();
            controller.download();
          },
        ),
      _ => AppCtaButton(
          label: 'Update now',
          icon: CupertinoIcons.arrow_down_circle,
          onPressed: controller.download,
        ),
    };
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final UpdateState state;

  static String _mb(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: state.progress,
            minHeight: 6,
            backgroundColor: AppColors.darkRaised,
            valueColor: const AlwaysStoppedAnimation(AppColors.brand),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          state.total > 0
              ? '${_mb(state.received)} of ${_mb(state.total)}'
              : _mb(state.received),
          style: AppText.caption(AppColors.onDarkMuted),
        ),
      ],
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: AppSpace.xs),
            child: SizedBox(
              width: 5,
              height: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(child: Text(text, style: AppText.body(AppColors.onDark))),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text(message, style: AppText.caption(AppColors.danger)),
    );
  }
}

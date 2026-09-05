import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
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

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  @override
  Widget build(BuildContext context) {
    // A fresh check that lands on `available` un-dismisses. Safe because a
    // background check already refuses to report a skipped build at all — so
    // arriving here means either a new build or a manual check, and both of
    // those are somebody asking to see it.
    ref.listen<UpdateStage>(
      updateControllerProvider.select((s) => s.stage),
      (previous, stage) {
        if (stage == UpdateStage.available &&
            previous != UpdateStage.available) {
          ref.read(updateDismissedProvider.notifier).state = null;
        }
      },
    );

    final state = ref.watch(updateControllerProvider);
    final dismissed = ref.watch(updateDismissedProvider);

    return Stack(
      children: [
        widget.child,
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
    // them to attach to — BackButtonListener throws outright. The back
    // button is handled by the Router's own dispatcher instead. See
    // `_UpdateBackButtonDispatcher` in app.dart.
    return Material(
      color: _plumTop,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_plumTop, _plumBottom],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(flex: 5, child: Center(child: _Orb())),

                Text(
                  mandatory ? 'Update\nRequired' : 'New\nUpdate\nAvailable',
                  style: AppText.display(Colors.white).copyWith(
                    fontSize: 40,
                    height: 1.08,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),

                Text(
                  _bodyText(release, mandatory),
                  style: AppText.body(Colors.white.withValues(alpha: .78))
                      .copyWith(fontSize: 15),
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
                // offering one either. Hidden mid-download too: there is
                // no half of a download worth keeping.
                SizedBox(
                  height: 52,
                  child: canDismiss
                      ? Center(
                          child: TextButton(
                            onPressed: onDismiss,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'Not Now',
                              style: AppText.subtitle(Colors.white)
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        )
                      : null,
                ),

                if (state.stage == UpdateStage.ready)
                  Text(
                    'Android will ask you to confirm. The first time, it '
                    'also asks you to allow installs from Dayflower.',
                    textAlign: TextAlign.center,
                    style: AppText.caption(Colors.white.withValues(alpha: .55)),
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
        : 'A newer version of Dayflower is ready to install.';
    return '$head\nVersion ${release.versionName} · build '
        '${release.buildNumber}$size';
  }
}

/* ── Palette ────────────────────────────────────────────────────
   Screen-local on purpose. This is the one surface in the app that is a
   full-bleed violet, and promoting it to AppColors would invite it onto
   surfaces where the dark hero tokens are already the right answer. */

const _plumTop = Color(0xFF3B2364);
const _plumBottom = Color(0xFF241542);

/* ── Pieces ─────────────────────────────────────────────────── */

/// The soft concentric orb at the top of the screen.
///
/// Painted rather than an asset: it is three radial gradients, and shipping
/// a PNG of it would cost more bytes than the code and still be wrong at
/// some screen density.
class _Orb extends StatelessWidget {
  const _Orb();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math
            .min(constraints.maxWidth, constraints.maxHeight)
            .clamp(120.0, 240.0);
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _OrbPainter()),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    void ring(double radius, double alpha, {double lift = -0.25}) {
      final rect = Rect.fromCircle(center: centre, radius: radius);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            // Off-centre so the rings read as lit from the top, which is
            // what stops concentric circles looking like a target.
            center: Alignment(0, lift),
            colors: [
              Colors.white.withValues(alpha: alpha * 1.6),
              Colors.white.withValues(alpha: alpha * 0.35),
            ],
          ).createShader(rect),
      );
    }

    ring(r, .085);
    ring(r * .78, .105);
    ring(r * .52, .125);
    ring(r * .26, .17, lift: -0.1);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) => false;
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.state, required this.controller});

  final UpdateState state;
  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    final (label, onPressed) = switch (state.stage) {
      UpdateStage.downloading => (
          state.progress == null
              ? 'Downloading…'
              : 'Downloading ${(state.progress! * 100).round()}%',
          null,
        ),
      UpdateStage.ready => ('Install Now', controller.install),
      UpdateStage.failed => (
          'Try Again',
          () {
            controller.reset();
            controller.download();
          }
        ),
      _ => ('Update Now', controller.download),
    };

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _plumBottom,
          disabledBackgroundColor: Colors.white.withValues(alpha: .55),
          disabledForegroundColor: _plumBottom.withValues(alpha: .7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        child: Text(
          label,
          style: AppText.subtitle(_plumBottom).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
    );
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
            backgroundColor: Colors.white.withValues(alpha: .18),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          state.total > 0
              ? '${_mb(state.received)} of ${_mb(state.total)}'
              : _mb(state.received),
          style: AppText.caption(Colors.white.withValues(alpha: .7)),
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
          Padding(
            padding: const EdgeInsets.only(top: 7, right: AppSpace.xs),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppText.body(Colors.white.withValues(alpha: .8)),
            ),
          ),
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
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        message,
        style: AppText.caption(Colors.white.withValues(alpha: .85)),
      ),
    );
  }
}

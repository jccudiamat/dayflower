import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_router.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../data/feedback_repository.dart';
import '../data/screenshot_events.dart';
import 'feedback_screen.dart';

/// After a screenshot, a small card: send it as a report, or not.
///
/// ⚠️ Above the Navigator, beside UpdateGate, for the same reason: it has to
/// appear over whatever screen was captured, dialogs and the call included,
/// and nothing a route does can take it away. That also means no Overlay
/// up here, so nothing in the card may use a tooltip.
///
/// The picture sent is the app's own capture of its screen at that moment,
/// taken from the boundary around [child]. The card is outside it, so it is
/// never in the picture, and the gallery is never read.
class ScreenshotReportGate extends ConsumerStatefulWidget {
  const ScreenshotReportGate({super.key, required this.child});

  /// Nullable because MaterialApp's builder types it that way.
  final Widget? child;

  /// How long the card waits before going on its own.
  static const showFor = Duration(seconds: 8);

  @override
  ConsumerState<ScreenshotReportGate> createState() =>
      _ScreenshotReportGateState();
}

class _ScreenshotReportGateState extends ConsumerState<ScreenshotReportGate> {
  final _screen = GlobalKey();
  StreamSubscription<void>? _events;
  Uint8List? _shot;
  Timer? _hide;
  DateTime? _offeredAt;

  @override
  void initState() {
    super.initState();
    _events = ref.read(screenshotEventsProvider).listen((_) => _offer());
  }

  @override
  void dispose() {
    _events?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  Future<void> _offer() async {
    await ref.read(screenshotPromptProvider.notifier).ready;
    if (!mounted || !ref.read(screenshotPromptProvider)) return;
    // Signed out, there is nobody to send it from.
    if (ref.read(currentUserIdProvider) == null) return;
    // Already writing one: the screenshot is probably for it, and the
    // gallery button there is how to attach it.
    if (FeedbackScreen.showing > 0) return;
    // One offer for a burst of screenshots, not one each.
    final now = DateTime.now();
    if (_offeredAt != null && now.difference(_offeredAt!) < const Duration(seconds: 8)) {
      return;
    }
    _offeredAt = now;

    final shot = await _capture();
    if (shot == null || !mounted) return;
    setState(() => _shot = shot);
    _hide?.cancel();
    _hide = Timer(ScreenshotReportGate.showFor, _dismiss);
  }

  /// The screen as it is now, which is what the screenshot showed.
  Future<Uint8List?> _capture() async {
    try {
      // A frame on its way would change what is on screen; let it land.
      // Only then: waiting on a frame nobody asked for waits forever.
      if (WidgetsBinding.instance.hasScheduledFrame) {
        await WidgetsBinding.instance.endOfFrame;
      }
      final box = _screen.currentContext?.findRenderObject();
      if (box is! RenderRepaintBoundary || !mounted) return null;
      // Sharp enough to read, and a fraction of full resolution to upload.
      final ratio = math.min(MediaQuery.devicePixelRatioOf(context), 1.75);
      final image = await box.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (e) {
      debugPrint('screenshot capture failed: $e');
      return null;
    }
  }

  void _dismiss() {
    _hide?.cancel();
    if (mounted && _shot != null) setState(() => _shot = null);
  }

  void _report() {
    final shot = _shot;
    _dismiss();
    if (shot == null) return;
    final FeedbackImage image = (bytes: shot, extension: 'png');
    ref.read(routerProvider).push(Routes.feedback, extra: image);
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shot;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          key: _screen,
          child: widget.child ?? const SizedBox.shrink(),
        ),
        Positioned(
          left: 12,
          right: 12,
          // Clear of the bottom bar and the chat's message field.
          bottom: MediaQuery.paddingOf(context).bottom + 80,
          child: AnimatedSwitcher(
            duration: AppMotion.standard,
            switchInCurve: AppMotion.easeOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, .3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: shot == null
                ? const SizedBox.shrink()
                : ScreenshotReportCard(
                    key: ValueKey(shot),
                    shot: shot,
                    onReport: _report,
                    onDismiss: _dismiss,
                  ),
          ),
        ),
      ],
    );
  }
}

/// The card itself: the picture, one line, Report, and a way to say no.
class ScreenshotReportCard extends StatelessWidget {
  const ScreenshotReportCard({
    super.key,
    required this.shot,
    required this.onReport,
    required this.onDismiss,
  });

  final Uint8List shot;
  final VoidCallback onReport;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppElevation.card,
          ),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
              child: Row(
                children: [
                  // Edged, so a pale screen still reads as a picture of one.
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.memory(
                      shot,
                      width: 40,
                      height: 64,
                      fit: BoxFit.cover,
                      cacheWidth: 120,
                      excludeFromSemantics: true,
                      errorBuilder: (_, __, ___) => Container(
                        width: 40,
                        height: 64,
                        color: AppColors.surfaceSubtle,
                      ),
                    ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.compact),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Screenshot taken',
                            style: AppText.subtitle().copyWith(fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('Something wrong, or an idea? Send it to us.',
                            style: AppText.caption()),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onReport,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      textStyle: AppText.subtitle().copyWith(fontSize: 15),
                    ),
                    child: const Text('Report'),
                  ),
                  Semantics(
                    button: true,
                    label: 'Not now',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: onDismiss,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: AppIcon(CupertinoIcons.xmark,
                            size: 16, color: AppColors.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

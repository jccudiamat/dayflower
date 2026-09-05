import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// A dial: a full track with an arc over it, read from twelve o'clock.
///
/// Extracted from the Finance goal cards so calls could use the same shape.
/// Dayflower shows proportions as rings, not bars — see design.md — and a
/// second hand-rolled painter would have been the start of two idioms for
/// one idea.
///
/// Colours are passed in rather than fixed: goals sit on a dark hero card
/// and want white-on-plum, the calling meter sits on a white utility card
/// and wants the opposite. The geometry is what is shared.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.fraction,
    required this.color,
    required this.trackColor,
    this.size = 62,
    this.strokeWidth = 4,
    this.center,
  });

  /// 0–1. Values outside are clamped rather than drawn as an over-wound
  /// dial: past 100% the ring is full and the *number* carries the excess.
  final double fraction;

  final Color color;
  final Color trackColor;
  final double size;
  final double strokeWidth;

  /// What sits in the hole. Null leaves it empty.
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: fraction.clamp(0, 1),
          color: color,
          trackColor: trackColor,
          strokeWidth: strokeWidth,
        ),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2 - strokeWidth / 2 - 1;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (fraction <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2, // from twelve o'clock, the way a dial is read
      2 * math.pi * fraction,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        // Rounded, so a 2% ring is still a visible mark rather than a
        // hairline nobody can see.
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// The ring as the Finance goals draw it: white on a dark hero card, the
/// percentage in the hole, a tick once the goal is met.
class GoalRing extends StatelessWidget {
  const GoalRing({super.key, required this.fraction, required this.reached});

  final double fraction;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    return ProgressRing(
      fraction: fraction,
      color: reached ? AppColors.success : AppColors.brandLight,
      trackColor: Colors.white.withValues(alpha: .14),
      center: Text(
        reached ? '✓' : '${(fraction * 100).toStringAsFixed(1)}%',
        style: AppText.label(Colors.white).copyWith(
          fontSize: reached ? 20 : 12.5,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

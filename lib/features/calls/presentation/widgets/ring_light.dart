import 'package:flutter/material.dart';

/// The screen's own edges, turned into a light.
///
/// 🔴 **Edges only, and that is the entire point.** A white overlay across
/// the whole screen would light your face and hide the person you called.
/// This leaves the middle untouched: the glow lives in a band around the
/// rim, fading inward, the way a real ring light sits around a lens.
///
/// ⚠️ Follows the screen rather than the card. It is painted at whatever
/// size it is given — hand it the full screen — and its corners are rounded
/// to sit inside a modern phone's own radius. Square corners on a rounded
/// display read as a bright wedge hanging off each corner.
///
/// ⚠️ Inert. It sits over the call and must never take a touch: the controls
/// underneath are the ones that end the call.
class RingLight extends StatelessWidget {
  const RingLight({
    super.key,
    this.thickness = 32,
    this.cornerRadius = 44,
    this.intensity = 1,
  });

  /// How far the light reaches inward before it is gone.
  ///
  /// ⚠️ 32, halved from 64. At 64 it was a lit border rather than a rim —
  /// it ate the corners of the video and the controls sat inside a glow.
  final double thickness;

  /// Rounded to sit inside the display's own curve.
  final double cornerRadius;

  /// 0 to 1. Animated on the way in so the screen does not simply flash.
  final double intensity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _RingLightPainter(
            thickness: thickness,
            cornerRadius: cornerRadius,
            intensity: intensity.clamp(0, 1),
          ),
        ),
      );
}

class _RingLightPainter extends CustomPainter {
  const _RingLightPainter({
    required this.thickness,
    required this.cornerRadius,
    required this.intensity,
  });

  final double thickness, cornerRadius, intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    // Warm white: a true white edge reads blue against skin, which is the
    // thing a ring light is bought to avoid.
    const glow = Color(0xFFFFF4E8);
    final reach = thickness.clamp(1.0, size.shortestSide / 2);

    // 🔴 Concentric rounded strokes, not four gradient bands. Bands were the
    // obvious way and they seam: where the top one crosses the left one the
    // corner is brighter than either, with the diagonal join visible across
    // it. Rings follow the screen's own curve the whole way round, so the
    // rim is even and the corners are corners.
    const steps = 56;
    final band = reach / steps;
    for (var i = 0; i < steps; i++) {
      final t = i / (steps - 1);
      final inset = t * reach;
      // Squared, so it is bright at the very rim and gone well before the
      // middle — a linear fade reads as a grey wash over the whole screen.
      final alpha = (1 - t) * (1 - t) * intensity;
      if (alpha <= 0) continue;
      final radius = (cornerRadius - inset).clamp(0.0, cornerRadius);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(inset, inset, size.width - inset * 2,
              size.height - inset * 2),
          Radius.circular(radius),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          // Overlapped deliberately: a hairline per ring would leave gaps.
          ..strokeWidth = band * 2
          ..color = glow.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_RingLightPainter old) =>
      old.intensity != intensity ||
      old.thickness != thickness ||
      old.cornerRadius != cornerRadius;
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The screen's own edges, turned into a light.
///
/// 🔴 **Edges only, and that is the entire point.** A white overlay across
/// the whole screen would light your face and hide the person you called.
/// This leaves the middle untouched: the glow lives in a band around the
/// rim, fading inward, the way a real ring light sits around a lens.
///
/// ⚠️ Follows the screen rather than the card. It is painted at whatever
/// size it is given — hand it the full screen.
///
/// 🔴 **Square at the rim, round inside.** It used to be rounded all the way
/// out, to sit inside a phone's own corner radius, and on a phone whose
/// corners are tighter than that guess the four corners were simply dark:
/// the video showed through a wedge at each one, and the light looked like
/// a frame that did not reach the edge. The outermost ring is now the
/// screen's own rectangle, lit into every corner, and each ring inward is a
/// little rounder, so the light still ends in a soft curve.
///
/// ⚠️ Inert. It sits over the call and must never take a touch: the controls
/// underneath are the ones that end the call.
class RingLight extends StatelessWidget {
  const RingLight({
    super.key,
    this.thickness = defaultThickness,
    this.intensity = 1,
  });

  /// How far the light reaches inward before it is gone. Set by the person
  /// on the call (RingLightWidth), between [minThickness] and
  /// [maxThickness].
  final double thickness;

  /// 40 by default: a rim, not a border. At 64 it ate the edges of the
  /// video and the controls sat inside a glow, which is the person's choice
  /// to make with the slider, not the default's.
  static const defaultThickness = 40.0;

  /// Warm white: a true white edge reads blue against skin, which is the
  /// thing a ring light is bought to avoid. Also the navigation bar's colour
  /// while the light is on, so the light carries on past the app's edge.
  static const glow = Color(0xFFFFF4E8);
  static const minThickness = 16.0;
  static const maxThickness = 110.0;

  /// 0 to 1. Animated on the way in so the screen does not simply flash.
  final double intensity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _RingLightPainter(
            thickness: thickness,
            intensity: intensity.clamp(0, 1),
          ),
        ),
      );
}

class _RingLightPainter extends CustomPainter {
  const _RingLightPainter({
    required this.thickness,
    required this.intensity,
  });

  final double thickness, intensity;

  /// The light as a picture, drawn once per screen size and width. A video
  /// call repaints every frame the picture moves, and a blur that size is
  /// worth doing once, not thirty times a second.
  static ui.Image? _image;
  static (Size, double)? _imageFor;

  /// 🔴 One soft blur of the screen's frame, not rings.
  ///
  /// Four gradient bands seamed where they crossed at the corners. Rounded
  /// rings then fixed the seams but left the corners dark, and square-cut
  /// rings lit the corners but hatched them with diagonal lines where one
  /// ring's curve slipped past the next. A frame (everything outside a
  /// rounded rectangle a little inside the screen) blurred once has none of
  /// that: bright at the rim and into every corner, fading inward the same
  /// way along every edge, and rounding itself off where the corners turn.
  static ui.Image _glow(Size size, double reach) {
    final key = (size, reach);
    final cached = _image;
    if (cached != null && _imageFor == key) return cached;

    // The fade takes about three and a third blurs from rim to nothing,
    // shaped much like the squared falloff the rings had: bright at the
    // very edge and gone well before the middle.
    final sigma = reach / 3.3;
    final core = sigma * 1.3;
    final screen = Offset.zero & size;
    final frame = Path()
      ..fillType = PathFillType.evenOdd
      // Far past the screen, so the blur has only light to pull in from
      // outside and the rim stays bright to the very edge.
      ..addRect(screen.inflate(reach * 2))
      ..addRRect(RRect.fromRectAndRadius(
          screen.deflate(core), Radius.circular(reach)));

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawPath(
      frame,
      Paint()
        ..color = RingLight.glow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
    final picture = recorder.endRecording();
    final image =
        picture.toImageSync(size.width.ceil(), size.height.ceil());
    picture.dispose();
    // A frame already drawn keeps its own hold on the old picture.
    _image?.dispose();
    _image = image;
    _imageFor = key;
    return image;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0 || size.isEmpty) return;
    final reach = thickness.clamp(1.0, size.shortestSide / 2).toDouble();
    canvas.drawImage(
      _glow(size, reach),
      Offset.zero,
      // The paint's opacity dims the whole light, for the fade in.
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, intensity)
        ..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_RingLightPainter old) =>
      old.intensity != intensity || old.thickness != thickness;
}

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/rendering.dart';

/// How a photo has been moved inside the space it fills: zoomed, tilted and
/// slid, by pinching and twisting it before it is sent.
///
/// Relative to the photo filling its space the way it always has, covering
/// it and centred: scale 1, no turn and no slide is exactly that, and is
/// [none]. [offset] is a fraction of the space's own width and height, so the
/// same adjustment means the same thing in the preview on the phone and in
/// the picture composed at 1280px.
///
/// 🔴 **The photo always covers its space.** A photo turned without being
/// zoomed leaves its corners empty, and an empty corner in a frame's window
/// is a hole through the paper. [clampedTo] zooms in as far as a tilt needs
/// and pulls a slide back until nothing shows through, so no gesture can
/// leave a gap.
@immutable
class PhotoAdjust {
  const PhotoAdjust({
    this.scale = 1,
    this.rotation = 0,
    this.offset = Offset.zero,
  });

  static const none = PhotoAdjust();

  /// As far in as a pinch goes. Past this a phone photo is only pixels.
  static const maxScale = 5.0;

  /// Tilts nearer level than this snap to level when the fingers lift: a
  /// photo a degree off looks like a mistake, not a choice.
  static const snap = 3 * math.pi / 180;

  final double scale;

  /// Clockwise, in radians.
  final double rotation;
  final Offset offset;

  bool get isNone => scale == 1 && rotation == 0 && offset == Offset.zero;

  /// Where a photo of [photo]'s shape is drawn to cover [box], centred,
  /// before any adjustment.
  static Rect coverRect(Size photo, Rect box) {
    final s = math.max(box.width / photo.width, box.height / photo.height);
    return Rect.fromCenter(
        center: box.center,
        width: photo.width * s,
        height: photo.height * s);
  }

  /// The slide in pixels, in a space of [box]'s size.
  Offset shiftIn(Rect box) =>
      Offset(offset.dx * box.width, offset.dy * box.height);

  /// Takes the photo, drawn at [coverRect], to where it shows in [box].
  Matrix4 matrixIn(Rect box) {
    final shift = shiftIn(box);
    return Matrix4.identity()
      ..translateByDouble(
          box.center.dx + shift.dx, box.center.dy + shift.dy, 0, 1)
      ..rotateZ(rotation)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-box.center.dx, -box.center.dy, 0, 1);
  }

  /// The least zoom at which a photo turned by [rotation] still covers
  /// [box] when centred.
  static double minScaleFor(Size photo, Rect box, double rotation) {
    final cover = coverRect(photo, box);
    final c = math.cos(rotation).abs(), s = math.sin(rotation).abs();
    return math.max((box.width * c + box.height * s) / cover.width,
        (box.width * s + box.height * c) / cover.height);
  }

  /// Whether the photo, adjusted like this, covers every corner of [box].
  bool covers(Size photo, Rect box) {
    final cover = coverRect(photo, box).inflate(.5);
    final shift = shiftIn(box);
    final cos = math.cos(rotation), sin = math.sin(rotation);
    for (final corner in [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ]) {
      // Back through the adjustment, to where on the photo this corner is.
      final p = corner - box.center - shift;
      final x = (p.dx * cos + p.dy * sin) / scale;
      final y = (-p.dx * sin + p.dy * cos) / scale;
      if (!cover.contains(box.center + Offset(x, y))) return false;
    }
    return true;
  }

  /// This, made to cover [box]: zoomed in as far as its tilt needs, and its
  /// slide pulled back toward the middle until nothing shows through.
  PhotoAdjust clampedTo(Size photo, Rect box) {
    final least = minScaleFor(photo, box, rotation);
    final s = scale.clamp(least, math.max(least, maxScale)).toDouble();
    final zoomed = PhotoAdjust(scale: s, rotation: rotation, offset: offset);
    if (zoomed.covers(photo, box)) return zoomed;
    // Centred always covers at this zoom, so the answer lies between.
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 16; i++) {
      final mid = (lo + hi) / 2;
      final tried =
          PhotoAdjust(scale: s, rotation: rotation, offset: offset * mid);
      if (tried.covers(photo, box)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return PhotoAdjust(scale: s, rotation: rotation, offset: offset * lo);
  }

  /// This, moved by a pinch that started at [from] (a point in [box]) and
  /// is now at [to], zoomed by [zoom] and turned by [turn] since it began.
  ///
  /// About the fingers, not the middle: the part of the photo under them at
  /// the start stays under them, the way a photo on a table moves.
  PhotoAdjust followed({
    required Rect box,
    required Offset from,
    required Offset to,
    required double zoom,
    required double turn,
  }) {
    final shift = shiftIn(box);
    // Where the fingers started, on the photo, from its middle.
    final p = from - box.center - shift;
    final cos = math.cos(-rotation), sin = math.sin(-rotation);
    final onPhoto = Offset(p.dx * cos - p.dy * sin, p.dx * sin + p.dy * cos) /
        scale;
    final s = scale * zoom;
    final r = rotation + turn;
    final c2 = math.cos(r), s2 = math.sin(r);
    final moved = Offset(onPhoto.dx * c2 - onPhoto.dy * s2,
            onPhoto.dx * s2 + onPhoto.dy * c2) *
        s;
    final newShift = to - box.center - moved;
    return PhotoAdjust(
      scale: s,
      rotation: r,
      offset: Offset(newShift.dx / box.width, newShift.dy / box.height),
    );
  }

  /// Level again, if it is nearly level.
  PhotoAdjust snapped() => rotation.abs() < snap
      ? PhotoAdjust(scale: scale, offset: offset)
      : this;

  @override
  bool operator ==(Object other) =>
      other is PhotoAdjust &&
      other.scale == scale &&
      other.rotation == rotation &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(scale, rotation, offset);
}

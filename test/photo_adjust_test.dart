import 'dart:math' as math;

import 'package:dayflower/core/frames/photo_adjust.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// A photo pinched and twisted before it is sent. Everything here is about
/// one promise: however it is moved, it still covers its space, so nothing
/// behind it ever shows through a frame's window.
void main() {
  const photo = Size(1200, 1600);
  const box = Rect.fromLTWH(0, 0, 300, 400);
  const wide = Rect.fromLTWH(20, 30, 400, 260);

  test('unmoved, it covers, and needs no zoom to', () {
    expect(PhotoAdjust.none.covers(photo, box), isTrue);
    expect(PhotoAdjust.minScaleFor(photo, box, 0), closeTo(1, 1e-9));
    // A photo of another shape covers by overflowing, never by squashing.
    expect(PhotoAdjust.none.covers(photo, wide), isTrue);
  });

  test('a tilt zooms in as far as it has to, and no further', () {
    for (final degrees in [5, 17, 30, 45, 90, 135, -20]) {
      final turn = degrees * math.pi / 180;
      final tilted = const PhotoAdjust().copyTurned(turn).clampedTo(photo, wide);
      expect(tilted.covers(photo, wide), isTrue, reason: '$degrees°');
      // Never zoomed out by a tilt: a portrait photo turned a quarter in a
      // wide window already overflows it, and stays at the zoom it had.
      final least = PhotoAdjust.minScaleFor(photo, wide, turn);
      expect(tilted.scale, closeTo(math.max(1, least), 1e-9),
          reason: '$degrees°');
      if (least > 1) {
        // Any less and a corner shows.
        final less = PhotoAdjust(scale: tilted.scale * .97, rotation: turn);
        expect(less.covers(photo, wide), isFalse, reason: '$degrees°');
      }
    }
  });

  test('a slide too far is pulled back until it covers', () {
    const far = PhotoAdjust(scale: 1.5, offset: Offset(2, -3));
    expect(far.covers(photo, box), isFalse);
    final held = far.clampedTo(photo, box);
    expect(held.covers(photo, box), isTrue);
    expect(held.scale, 1.5, reason: 'the zoom it was given is kept');
    // Pulled back along the same line, as far out as it can still be.
    expect(held.offset.direction, closeTo(far.offset.direction, 1e-9));
    final further = PhotoAdjust(scale: 1.5, offset: held.offset * 1.05);
    expect(further.covers(photo, box), isFalse);
  });

  test('zoom has a ceiling', () {
    const lots = PhotoAdjust(scale: 40);
    expect(lots.clampedTo(photo, box).scale, PhotoAdjust.maxScale);
  });

  test('a pinch moves the photo about the fingers', () {
    // Whatever was under the fingers when they landed is still under them.
    const start = PhotoAdjust(scale: 1.4, rotation: .2, offset: Offset(.05, -.02));
    const from = Offset(90, 120);
    const to = Offset(140, 180);
    final moved = start.followed(
        box: wide, from: from, to: to, zoom: 1.6, turn: -.35);
    Offset onPhoto(PhotoAdjust a, Offset p) {
      final shift = a.shiftIn(wide);
      final q = p - wide.center - shift;
      final c = math.cos(a.rotation), s = math.sin(a.rotation);
      return Offset(q.dx * c + q.dy * s, -q.dx * s + q.dy * c) / a.scale;
    }

    final before = onPhoto(start, from);
    final after = onPhoto(moved, to);
    expect(after.dx, closeTo(before.dx, 1e-6));
    expect(after.dy, closeTo(before.dy, 1e-6));
    expect(moved.scale, closeTo(1.4 * 1.6, 1e-9));
    expect(moved.rotation, closeTo(.2 - .35, 1e-9));
  });

  test('nearly level snaps level, a real tilt stays', () {
    expect(const PhotoAdjust(rotation: .03).snapped().rotation, 0);
    expect(const PhotoAdjust(rotation: .2).snapped().rotation, .2);
  });
}

extension on PhotoAdjust {
  PhotoAdjust copyTurned(double turn) =>
      PhotoAdjust(scale: scale, rotation: turn, offset: offset);
}

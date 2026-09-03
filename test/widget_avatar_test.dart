import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:dayflower/features/widget/widget_sync.dart';

/// The home-screen widget's avatar is cut to a circle in Dart because
/// RemoteViews cannot clip a bitmap. Nothing on the Android side would
/// notice if it came out square — it would simply render a square face in a
/// round header, on a home screen, where nobody is looking for a bug.

Uint8List _solid(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(220, 60, 140));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('the corners are transparent and the middle is not', () {
    final out = circleAvatarPng(_solid(400, 400));
    final decoded = img.decodeImage(out!)!;

    expect(decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2).a,
        greaterThan(0),
        reason: 'the face itself must survive');
    // ⚠️ The whole test. A square PNG passes every other assertion here.
    expect(decoded.getPixel(0, 0).a, 0, reason: 'top-left must be cut away');
    expect(decoded.getPixel(decoded.width - 1, 0).a, 0);
    expect(decoded.getPixel(0, decoded.height - 1).a, 0);
    expect(decoded.getPixel(decoded.width - 1, decoded.height - 1).a, 0);
  });

  test('it comes out square and small', () {
    // It draws at 30dp. Anything larger is spending the RemoteViews bitmap
    // budget that the day photo behind it needs.
    final decoded = img.decodeImage(circleAvatarPng(_solid(1200, 800))!)!;
    expect(decoded.width, decoded.height);
    expect(decoded.width, 96);
  });

  test('a non-square photo is cropped, not squashed', () {
    // A wide photo squeezed into a circle stretches a face sideways.
    final wide = img.Image(width: 400, height: 100);
    img.fill(wide, color: img.ColorRgb8(20, 20, 20));
    img.fillCircle(wide, x: 200, y: 50, radius: 40,
        color: img.ColorRgb8(250, 250, 250));
    final decoded =
        img.decodeImage(circleAvatarPng(Uint8List.fromList(img.encodePng(wide)))!)!;
    // The bright centre survived the crop rather than being scaled away.
    expect(decoded.getPixel(48, 48).r, greaterThan(200));
  });

  test('garbage returns null instead of throwing', () {
    // ⚠️ `img.decodeImage` throws on truncated bytes rather than returning
    // null, and this runs inside a `compute` isolate during a widget sync —
    // an uncaught throw there takes the sync down silently.
    expect(circleAvatarPng(Uint8List.fromList([1, 2, 3])), isNull);
    expect(circleAvatarPng(Uint8List(0)), isNull);
  });

  test('null is never confused with the original bytes', () {
    // Returning the input on failure would put a square PNG in the round
    // header — the exact failure this file exists to prevent.
    final junk = Uint8List.fromList(List.filled(64, 9));
    expect(circleAvatarPng(junk), isNot(equals(junk)));
  });
}

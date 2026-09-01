import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:dayflower/features/tulip/presentation/widgets/share_your_day.dart';

/// The front camera hands back the selfie view, so text reads backwards and
/// a parting swaps sides. These check the correction actually reverses the
/// image rather than merely re-encoding it.
void main() {
  /// A 4x1 strip: red, green, blue, white. Asymmetric on purpose — a
  /// symmetric image would pass whether or not the flip happened.
  Uint8List stripe() {
    final image = img.Image(width: 4, height: 1);
    image.setPixelRgb(0, 0, 255, 0, 0);
    image.setPixelRgb(1, 0, 0, 255, 0);
    image.setPixelRgb(2, 0, 0, 0, 255);
    image.setPixelRgb(3, 0, 255, 255, 255);
    return Uint8List.fromList(img.encodeJpg(image, quality: 100));
  }

  test('reverses the image horizontally', () {
    final out = img.decodeImage(unmirrorJpeg(stripe()))!;
    final before = img.decodeImage(stripe())!;

    expect(out.width, 4);
    expect(out.height, 1);
    // Column 0 should now hold what column 3 held, and vice versa. JPEG is
    // lossy, so compare channel-dominance rather than exact values.
    final leftOut = out.getPixel(0, 0);
    final rightBefore = before.getPixel(3, 0);
    expect(leftOut.r > 200 && leftOut.g > 200 && leftOut.b > 200, isTrue,
        reason: 'left edge should now be the white end');
    expect(rightBefore.r > 200, isTrue);

    final rightOut = out.getPixel(3, 0);
    expect(rightOut.r > 150 && rightOut.g < 120 && rightOut.b < 120, isTrue,
        reason: 'right edge should now be the red end');
  });

  test('flipping twice returns the original orientation', () {
    final once = img.decodeImage(unmirrorJpeg(stripe()))!;
    final twice = img.decodeImage(unmirrorJpeg(unmirrorJpeg(stripe())))!;
    final original = img.decodeImage(stripe())!;

    final p0 = twice.getPixel(0, 0);
    final o0 = original.getPixel(0, 0);
    expect((p0.r - o0.r).abs() < 40, isTrue);
    expect(once.getPixel(0, 0).b, isNot(closeTo(o0.b, 5)));
  });

  test('undecodable input is returned untouched, never thrown', () {
    // A photo the wrong way round beats a photo that vanished.
    final junk = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(unmirrorJpeg(junk), same(junk));
  });
}

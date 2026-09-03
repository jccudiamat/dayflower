import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:dayflower/core/services/avatar_image.dart';

/// Avatar processing runs in a background isolate and its output goes
/// straight to Storage, so nothing in the app sees it fail. A squashed
/// face, a sideways one, or a 4MB upload behind every screen would all go
/// unnoticed until somebody looked closely at a photo they had already
/// stopped thinking about.

/// An image with a deliberately off-centre marker, so a crop can be shown
/// to have taken the *middle* rather than a corner.
Uint8List _striped({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(30, 30, 30));
  // A bright block dead centre. A centre crop must keep it; a top-left
  // crop of a wide image would not.
  img.fillRect(
    image,
    x1: width ~/ 2 - width ~/ 20,
    y1: height ~/ 2 - height ~/ 20,
    x2: width ~/ 2 + width ~/ 20,
    y2: height ~/ 2 + height ~/ 20,
    color: img.ColorRgb8(250, 250, 250),
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

void main() {
  test('a landscape photo comes out square', () {
    final out = squareAvatarJpeg(_striped(width: 1600, height: 900));
    final decoded = img.decodeImage(out!);
    expect(decoded!.width, decoded.height);
    // Cropped to the short edge, not padded out to the long one.
    expect(decoded.width, lessThanOrEqualTo(900));
  });

  test('a portrait photo comes out square too', () {
    final out = squareAvatarJpeg(_striped(width: 800, height: 1400));
    final decoded = img.decodeImage(out!);
    expect(decoded!.width, decoded.height);
  });

  test('the crop takes the middle, not a corner', () {
    // The one that actually matters for faces: a centre crop keeps them,
    // a top-left crop beheads half the people who upload a wide photo.
    final out = squareAvatarJpeg(_striped(width: 2000, height: 800));
    final decoded = img.decodeImage(out!)!;
    final centre = decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);
    expect(centre.r, greaterThan(200),
        reason: 'the bright centre block should have survived the crop');
  });

  test('a big photo is capped at the stored size', () {
    final out = squareAvatarJpeg(_striped(width: 3000, height: 3000));
    final decoded = img.decodeImage(out!)!;
    expect(decoded.width, avatarSize);
    // The real point of the cap: this is fetched on nearly every screen.
    expect(out.length, lessThan(300 * 1024));
  });

  test('a small photo is not blown up', () {
    // Upscaling makes the file bigger and the picture no better.
    final out = squareAvatarJpeg(_striped(width: 200, height: 200));
    final decoded = img.decodeImage(out!)!;
    expect(decoded.width, 200);
  });

  test('garbage returns null instead of throwing', () {
    // ⚠️ `img.decodeImage` throws on truncated bytes rather than returning
    // null — its format sniffers read past the end of a short buffer. This
    // is the test that says the try/catch is load-bearing, not decoration.
    expect(squareAvatarJpeg(Uint8List.fromList([1, 2, 3, 4, 5])), isNull);
    expect(squareAvatarJpeg(Uint8List(0)), isNull);
  });

  test('null is never confused with the original bytes', () {
    // The tempting "simplification" is to return the input on failure, the
    // way unmirrorJpeg does. It would be wrong here: unmirror falls back to
    // a correct photo, whereas this would upload something the app has just
    // proved it cannot decode.
    final junk = Uint8List.fromList(List.filled(64, 7));
    expect(squareAvatarJpeg(junk), isNot(equals(junk)));
  });
}

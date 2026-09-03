/// Turns whatever the camera or the gallery handed over into an avatar.
///
/// One square JPEG, at most [avatarSize] on a side. Everything about that
/// is deliberate:
///
/// - **Square, centre-cropped.** Every surface in the app draws an avatar in
///   a circle. A portrait photo squeezed into a circle is either distorted
///   or has its top and bottom quietly cut off by the clip anyway — doing
///   the crop here means what is uploaded is what will be seen.
/// - **512px.** Larger than the biggest place it is drawn (66pt in Settings,
///   so ~200px on a 3× screen) with headroom, and small enough that the
///   whole file is tens of kilobytes. An avatar is fetched on nearly every
///   screen; a 2MB one would be felt.
/// - **Orientation baked in.** A phone photo carries its rotation in EXIF
///   rather than in the pixels, and a renderer that ignores the tag shows a
///   sideways face. Baking it makes the bytes true on their own.
///
/// There is no in-app crop UI, and that is a deliberate omission rather
/// than an oversight: `image_cropper` is in pubspec but has never been
/// wired up, and using it needs a `UCropActivity` entry in the Android
/// manifest. Adding platform config is the one change most likely to break
/// the release build — and the release build is what ships every update.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;



/// The edge length of a stored avatar, in pixels.
const int avatarSize = 512;

/// JPEG quality. 88 is where a face at this size stops improving.
const int _quality = 88;

/// Processes [bytes], or returns null if they are not an image this can
/// read.
///
/// Null rather than a throw or a passthrough: the caller has to be able to
/// say "that file didn't work" instead of uploading something the app will
/// then fail to render. ⚠️ Do not "simplify" the null away by returning the
/// input — `img.decodeImage` throws on truncated or garbage bytes rather
/// than returning null (its format sniffers read past the end of a short
/// buffer), which is why everything here sits inside one try.
///
/// Runs off the UI thread via `compute` — decoding, cropping and
/// re-encoding a 12-megapixel photo is hundreds of milliseconds and would
/// visibly freeze the sheet it is triggered from.
Uint8List? squareAvatarJpeg(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // Before the crop, or the rotation moves the square off the face.
    final upright = img.bakeOrientation(decoded);

    final edge = upright.width < upright.height ? upright.width : upright.height;
    final square = img.copyCrop(
      upright,
      x: (upright.width - edge) ~/ 2,
      y: (upright.height - edge) ~/ 2,
      width: edge,
      height: edge,
    );

    // Only ever downwards. Upscaling a small photo to 512 makes the file
    // bigger and the picture no better.
    final sized = edge > avatarSize
        ? img.copyResize(square, width: avatarSize, height: avatarSize)
        : square;

    return Uint8List.fromList(img.encodeJpg(sized, quality: _quality));
  } catch (_) {
    return null;
  }
}

import 'dart:typed_data';
import 'dart:ui' as ui;

/// A photo's shape, carried in its storage path so a bubble can be drawn at
/// its final size before a single byte of it has downloaded.
///
/// 🔴 **Why the loading box was a sliver.** A photo in the thread sizes
/// itself from the picture, and until the picture arrives there is nothing
/// to size from: the grey box had a height and no width, so the bubble
/// shrank to its widest other line, the time. The shape now travels with
/// the photo. `<pair>/<uuid>_240x320.jpg` is 3:4, known from the path
/// alone, and the box is the photo's exact box from the first frame. The
/// numbers are a shape, measured on a small decode, not the pixel size.
///
/// ⚠️ In the path rather than in a column: a column is a migration pasted
/// into the SQL editor by hand, and every reader of a path (the home-screen
/// widget, the viewer, Save) already treats it as an opaque name. Photos
/// sent before this have no shape in their path and fall back to a
/// full-width box; see [photoAspectOf].

final _shape = RegExp(r'_(\d+)x(\d+)\.[A-Za-z0-9]+$');

/// Width over height, or null for a path that does not say (anything sent
/// before shapes were recorded).
double? photoAspectOf(String path) {
  final m = _shape.firstMatch(path);
  if (m == null) return null;
  final w = int.parse(m.group(1)!), h = int.parse(m.group(2)!);
  if (w <= 0 || h <= 0) return null;
  return w / h;
}

/// [path] with the shape written in just before its extension:
/// `a/b.jpg` → `a/b_1200x1600.jpg`.
String withPhotoShape(String path, int width, int height) {
  final dot = path.lastIndexOf('.');
  final slash = path.lastIndexOf('/');
  if (dot <= slash) return '${path}_${width}x$height';
  return '${path.substring(0, dot)}_${width}x$height${path.substring(dot)}';
}

/// The shape of [bytes] as it will be drawn, or null if it cannot be read.
///
/// ⚠️ Decoded, small, rather than read from the file header: a phone's JPEG
/// is often stored sideways with an EXIF note to turn it, and the header's
/// width and height are the sideways ones. The decoder applies the turn, so
/// what it reports is what the thread will show.
Future<(int, int)?> measurePhoto(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 240);
    final frame = await codec.getNextFrame();
    final size = (frame.image.width, frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return size.$1 > 0 && size.$2 > 0 ? size : null;
  } catch (_) {
    // A shape is a nicety. A photo that cannot be measured still sends.
    return null;
  }
}

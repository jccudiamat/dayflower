import 'dart:ui' show Rect;

/// The paper a photo is shown on: polaroids, torn notes, a drawn cloud.
///
/// ⚠️ **The art is a cut-out with a hole in it, not a border.** A photo is
/// drawn *behind* the frame and shows through the transparent window, which
/// is why every frame carries [windows] and why they are fractions rather
/// than pixels: the same numbers hold whatever size the card is drawn at.
///
/// The fractions were measured from the artwork itself rather than typed by
/// hand — the alpha channel's interior holes are the windows, so they cannot
/// drift from the picture they describe.
class PhotoFrame {
  const PhotoFrame({
    required this.id,
    required this.name,
    required this.aspect,
    required this.windows,
  });

  /// Matches the asset name, and is what a sent message would store. ⚠️ Not
  /// the index: reordering this list must never repoint an old message at a
  /// different frame.
  final String id;

  /// For a picker, in the couple's own language rather than the file's.
  final String name;

  /// Width over height of the artwork.
  final double aspect;

  /// Where photos go, largest first, as fractions of the frame's box.
  ///
  /// Empty for a frame that holds no picture at all — `torn_note` is a sheet
  /// of paper to write on, and giving it a window would put a photo where
  /// the words belong.
  final List<Rect> windows;

  String get asset => 'assets/images/frames/$id.webp';

  /// How many photos it takes.
  int get slots => windows.length;
}

/// Every frame that ships, in the order a picker should offer them: the
/// plain ones first, because most days are one photo and no occasion.
const photoFrames = <PhotoFrame>[
  PhotoFrame(
    id: 'polaroid_kraft',
    name: 'Kraft polaroid',
    aspect: 746 / 760,
    windows: [
      Rect.fromLTWH(0.1688, 0.0875, 0.7625, 0.7188),
    ],
  ),
  PhotoFrame(
    id: 'polaroid_aged',
    name: 'Aged polaroid',
    aspect: 753 / 760,
    windows: [
      Rect.fromLTWH(0.2, 0.1062, 0.6438, 0.7),
    ],
  ),
  PhotoFrame(
    id: 'polaroid_sun',
    name: 'Sunny polaroid',
    aspect: 756 / 760,
    windows: [
      Rect.fromLTWH(0.2188, 0.1187, 0.6375, 0.6562),
    ],
  ),
  PhotoFrame(
    id: 'torn_paper',
    name: 'Torn paper',
    aspect: 728 / 760,
    windows: [
      Rect.fromLTWH(0.2062, 0.1062, 0.7, 0.7688),
    ],
  ),
  PhotoFrame(
    id: 'torn_kraft_sun',
    name: 'Torn kraft',
    aspect: 760 / 757,
    windows: [
      Rect.fromLTWH(0.1125, 0.1313, 0.8313, 0.7063),
    ],
  ),
  PhotoFrame(
    id: 'duo_offset',
    name: 'Two, offset',
    aspect: 707 / 760,
    windows: [
      Rect.fromLTWH(0.1938, 0.1, 0.6375, 0.5875),
      Rect.fromLTWH(0.5188, 0.5, 0.3937, 0.3625),
    ],
  ),
  PhotoFrame(
    id: 'duo_heart_sparkle',
    name: 'Two, with hearts',
    aspect: 760 / 736,
    windows: [
      Rect.fromLTWH(0.4125, 0.0625, 0.5188, 0.6562),
      Rect.fromLTWH(0.0938, 0.4813, 0.375, 0.3563),
    ],
  ),
  PhotoFrame(
    id: 'duo_sun_heart',
    name: 'Two, sun & heart',
    aspect: 760 / 701,
    windows: [
      Rect.fromLTWH(0.0938, 0.1125, 0.525, 0.65),
      Rect.fromLTWH(0.4938, 0.3875, 0.4437, 0.4875),
    ],
  ),
  PhotoFrame(
    id: 'duo_pinned',
    name: 'Two, pinned',
    aspect: 744 / 760,
    windows: [
      Rect.fromLTWH(0.3375, 0.0938, 0.5687, 0.7188),
      Rect.fromLTWH(0.1375, 0.4813, 0.325, 0.375),
    ],
  ),
  PhotoFrame(
    id: 'cloud_moon',
    name: 'Cloud & moon',
    aspect: 760 / 750,
    windows: [
      Rect.fromLTWH(0.1313, 0.1875, 0.7812, 0.5563),
    ],
  ),
  PhotoFrame(
    id: 'torn_note',
    name: 'Torn note',
    aspect: 760 / 675,
    windows: [],
  ),
];

/// The frame with this id, or null for one this build has never heard of.
///
/// ⚠️ Null rather than a fallback. A message that names a frame we do not
/// have is from a newer build, and quietly drawing a different frame would
/// misrepresent what they actually sent.
PhotoFrame? frameById(String? id) {
  if (id == null) return null;
  for (final frame in photoFrames) {
    if (frame.id == id) return frame;
  }
  return null;
}

/// The frames that hold [count] photos.
Iterable<PhotoFrame> framesForPhotos(int count) =>
    photoFrames.where((f) => f.slots == count);

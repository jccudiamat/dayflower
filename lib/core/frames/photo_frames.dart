import 'dart:ui' show Offset, Path, Rect, Size;

import 'frame_windows.dart';

/// The paper a photo is shown on: polaroids, torn notes, a drawn cloud.
///
/// ⚠️ **The art is a cut-out with a hole in it, not a border.** A photo is
/// drawn *behind* the frame and shows through the transparent window, which
/// is why every frame carries [windows] and why they are fractions rather
/// than pixels: the same numbers hold whatever size the card is drawn at.
///
/// The windows are traced from the artwork itself rather than typed by hand
/// (tool/trace_frame_windows.py), so they cannot drift from the picture they
/// describe. A new frame needs its entry here and a run of that script.
class PhotoFrame {
  const PhotoFrame({
    required this.id,
    required this.name,
    required this.aspect,
  });

  /// Matches the asset name, and is what a sent message would store. ⚠️ Not
  /// the index: reordering this list must never repoint an old message at a
  /// different frame.
  final String id;

  /// For a picker, in the couple's own language rather than the file's.
  final String name;

  /// Width over height of the artwork.
  final double aspect;

  /// The blank paper under a window, where Home writes whose day it is.
  /// Null for a frame with nowhere to write: a torn edge, no window.
  FrameCaptionStrip? get captionStrip => frameCaptionStrips[id];

  /// Where photos go, largest first.
  ///
  /// Empty for a frame that holds no picture at all — `torn_note` is a sheet
  /// of paper to write on, and giving it a window would put a photo where
  /// the words belong.
  List<FrameWindow> get windows => frameWindows[id] ?? const [];

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
  ),
  PhotoFrame(
    id: 'polaroid_aged',
    name: 'Aged polaroid',
    aspect: 753 / 760,
  ),
  PhotoFrame(
    id: 'polaroid_sun',
    name: 'Sunny polaroid',
    aspect: 756 / 760,
  ),
  PhotoFrame(
    id: 'torn_paper',
    name: 'Torn paper',
    aspect: 728 / 760,
  ),
  PhotoFrame(
    id: 'torn_kraft_sun',
    name: 'Torn kraft',
    aspect: 760 / 757,
  ),
  PhotoFrame(
    id: 'duo_offset',
    name: 'Two, offset',
    aspect: 707 / 760,
  ),
  PhotoFrame(
    id: 'duo_heart_sparkle',
    name: 'Two, with hearts',
    aspect: 760 / 736,
  ),
  PhotoFrame(
    id: 'duo_sun_heart',
    name: 'Two, sun & heart',
    aspect: 760 / 701,
  ),
  PhotoFrame(
    id: 'duo_pinned',
    name: 'Two, pinned',
    aspect: 744 / 760,
  ),
  PhotoFrame(
    id: 'cloud_moon',
    name: 'Cloud & moon',
    aspect: 760 / 750,
  ),
  PhotoFrame(
    id: 'torn_note',
    name: 'Torn note',
    aspect: 760 / 675,
  ),
];

/// One hole in a frame: where a photo shows through the paper.
///
/// 🔴 **A shape, not a rectangle.** Windows used to be the box around each
/// hole, and the photo filled the box. On the cloud that put the photo in
/// the box's corners, past the cloud's outline where the paper is clear, so
/// it showed outside the frame; and the box, measured on a coarse grid, fell
/// three pixels short of the hole's bottom, leaving a thin line of whatever
/// was behind the picture. A photo is now cut to [outline], which is the
/// hole's own edge grown a few pixels to run under the paper.
class FrameWindow {
  const FrameWindow(this.bounds, this.outline);

  /// The smallest box around [outline], as fractions of the frame's box.
  /// A photo is cover-fitted to this and then cut to the outline.
  final Rect bounds;

  /// The hole's edge as x, y pairs, as fractions of the frame's box.
  final List<double> outline;

  /// [bounds] in a frame drawn at [size].
  Rect boundsIn(Size size) => Rect.fromLTWH(bounds.left * size.width,
      bounds.top * size.height, bounds.width * size.width,
      bounds.height * size.height);

  /// [outline] in a frame drawn at [size], shifted by [origin]: pass the
  /// window's own top left to cut a child that is laid out in [bounds].
  Path pathIn(Size size, {Offset origin = Offset.zero}) {
    final path = Path()
      ..moveTo(outline[0] * size.width - origin.dx,
          outline[1] * size.height - origin.dy);
    for (var i = 2; i + 1 < outline.length; i += 2) {
      path.lineTo(outline[i] * size.width - origin.dx,
          outline[i + 1] * size.height - origin.dy);
    }
    return path..close();
  }
}

/// The blank paper under a window: the bottom of a polaroid, where a pen
/// would write the date. Measured from the artwork like the windows, tilt
/// and all (tool/trace_frame_windows.py).
class FrameCaptionStrip {
  const FrameCaptionStrip(this.center, this.size, this.angle);

  /// Its middle, as fractions of the frame's box.
  final Offset center;

  /// Its width and height before it is tilted, as fractions of the frame's
  /// box.
  final Size size;

  /// How far it is turned, in radians, clockwise: the paper's own tilt.
  final double angle;

  /// The strip, untilted, in a frame drawn at [frame]. Turn what is drawn
  /// in it by [angle] about its middle.
  Rect rectIn(Size frame) => Rect.fromCenter(
      center: Offset(center.dx * frame.width, center.dy * frame.height),
      width: size.width * frame.width,
      height: size.height * frame.height);
}

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

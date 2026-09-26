import 'dart:ui' as ui;

import 'dart:math' as math;

import 'package:dayflower/core/frames/photo_frames.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The frames are artwork with holes in them, and everything about them that
/// can be wrong is silent: an asset that is not bundled draws a grey box, a
/// window measured against the wrong picture puts a photo through the paper.
/// Both are checked against the real files here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every frame is bundled, and is the shape it claims', () async {
    for (final frame in photoFrames) {
      final bytes = await rootBundle.load(frame.asset);
      expect(bytes.lengthInBytes, greaterThan(0), reason: frame.id);

      final image = await (await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(),
      ))
          .getNextFrame();
      addTearDown(image.image.dispose);
      expect(
        image.image.width / image.image.height,
        closeTo(frame.aspect, 0.01),
        reason: '${frame.id} is drawn at its declared aspect',
      );
    }
  });

  test('windows sit inside the frame', () {
    for (final frame in photoFrames) {
      for (final FrameWindow(bounds: window, :outline) in frame.windows) {
        expect(window.left, greaterThanOrEqualTo(0), reason: frame.id);
        expect(window.top, greaterThanOrEqualTo(0), reason: frame.id);
        expect(window.right, lessThanOrEqualTo(1), reason: frame.id);
        expect(window.bottom, lessThanOrEqualTo(1), reason: frame.id);
        // A sliver is a measuring mistake, not a place for a photo.
        expect(window.width * window.height, greaterThan(0.02),
            reason: '${frame.id} window is big enough to be one');
        // The outline is a shape, and its box is the box around it: the
        // photo is fitted to the box, so a point outside it would be left
        // uncovered.
        expect(outline.length, greaterThan(6), reason: frame.id);
        expect(outline.length.isEven, isTrue, reason: frame.id);
        for (var i = 0; i < outline.length; i += 2) {
          expect(window.inflate(1e-4).contains(
                  ui.Offset(outline[i], outline[i + 1])),
              isTrue, reason: '${frame.id} outline inside its bounds');
        }
      }
    }
  });

  test('a caption strip is blank paper, under the photo', () async {
    for (final frame in photoFrames) {
      final strip = frame.captionStrip;
      if (strip == null) continue;
      final art = (await (await ui.instantiateImageCodec(
        (await rootBundle.load(frame.asset)).buffer.asUint8List(),
      ))
              .getNextFrame())
          .image;
      addTearDown(art.dispose);
      final rgba = (await art.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      final size = ui.Size(art.width.toDouble(), art.height.toDouble());
      final box = strip.rectIn(size);
      // Across the strip, turned as it is drawn: every point is on the
      // paper, and none is in a window where the photo shows.
      for (var i = 0; i <= 8; i++) {
        for (var j = 0; j <= 2; j++) {
          final dx = box.width * (i / 8 - .5), dy = box.height * (j / 2 - .5);
          final x = box.center.dx +
              dx * math.cos(strip.angle) -
              dy * math.sin(strip.angle);
          final y = box.center.dy +
              dx * math.sin(strip.angle) +
              dy * math.cos(strip.angle);
          final alpha = rgba[(y.floor() * art.width + x.floor()) * 4 + 3];
          expect(alpha, greaterThan(200),
              reason: '${frame.id} strip is on paper at $x,$y');
          for (final window in frame.windows) {
            expect(window.pathIn(size).contains(ui.Offset(x, y)), isFalse,
                reason: '${frame.id} strip is clear of the photo');
          }
        }
      }
      // Under the photo: below the middle of the first window.
      expect(strip.center.dy, greaterThan(frame.windows.first.bounds.center.dy),
          reason: frame.id);
    }
    // Every polaroid has one; the torn note, with no photo, does not.
    for (final id in ['polaroid_kraft', 'polaroid_aged', 'polaroid_sun']) {
      expect(frameById(id)!.captionStrip, isNotNull, reason: id);
    }
    expect(frameById('torn_note')!.captionStrip, isNull);
  });

  test("a framed photo's name says which frame it is on", () {
    FlowerMessage photo(String name) => FlowerMessage(
        id: 'm',
        pairId: 'pair',
        senderId: 'me',
        imagePath: 'pair/$name',
        sentAt: DateTime(2026));
    final framed = photo('frame-polaroid_kraft-3f2a9c1e-77aa_240x245.webp');
    expect(framed.isFramed, isTrue);
    expect(framed.isOnPaper, isTrue);
    expect(framed.frameId, 'polaroid_kraft');
    expect(frameById(framed.frameId), isNotNull);
    // A plain day photo, and a strip, which is on paper but not a frame's.
    expect(photo('3f2a9c1e-77aa_240x320.jpg').frameId, isNull);
    expect(photo('3f2a9c1e-77aa_240x320.jpg').isOnPaper, isFalse);
    expect(photo('booth-3f2a9c1e_240x720.jpg').isOnPaper, isTrue);
    expect(photo('booth-3f2a9c1e_240x720.jpg').frameId, isNull);
  });

  test('ids are unique, and an unknown one resolves to nothing', () {
    final ids = photoFrames.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'no two frames share an id');
    expect(frameById('polaroid_kraft')?.name, 'Kraft polaroid');
    // 🔴 Null rather than a fallback: drawing a different frame would
    // misrepresent what a newer build actually sent.
    expect(frameById('from_a_newer_build'), isNull);
    expect(frameById(null), isNull);
  });

  test('the torn note holds words, not a picture', () {
    // Giving it a window would put a photo where the writing goes.
    expect(frameById('torn_note')!.slots, 0);
    expect(framesForPhotos(0).map((f) => f.id), ['torn_note']);
    expect(framesForPhotos(1).length, greaterThan(3));
    expect(framesForPhotos(2).length, greaterThan(3));
  });
}

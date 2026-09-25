import 'dart:ui' as ui;

import 'package:dayflower/core/frames/photo_frames.dart';
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
      for (final window in frame.windows) {
        expect(window.left, greaterThanOrEqualTo(0), reason: frame.id);
        expect(window.top, greaterThanOrEqualTo(0), reason: frame.id);
        expect(window.right, lessThanOrEqualTo(1), reason: frame.id);
        expect(window.bottom, lessThanOrEqualTo(1), reason: frame.id);
        // A sliver is a measuring mistake, not a place for a photo.
        expect(window.width * window.height, greaterThan(0.02),
            reason: '${frame.id} window is big enough to be one');
      }
    }
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

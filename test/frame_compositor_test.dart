import 'dart:ui' as ui;

import 'package:dayflower/core/frames/frame_compositor.dart';
import 'package:dayflower/core/frames/photo_frames.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A solid picture of [colour], [w] by [h].
Future<Uint8List> _photo(ui.Color colour, {int w = 600, int h = 400}) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
      .drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          ui.Paint()..color = colour);
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<ui.Image> _decode(Uint8List bytes) async =>
    (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;

/// The colour at a point, as 0xAARRGGBB.
Future<int> _pixel(ui.Image image, double fx, double fy) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final x = (image.width * fx).clamp(0, image.width - 1).toInt();
  final y = (image.height * fy).clamp(0, image.height - 1).toInt();
  final i = (y * image.width + x) * 4;
  final b = data!.buffer.asUint8List();
  return (b[i + 3] << 24) | (b[i] << 16) | (b[i + 1] << 8) | b[i + 2];
}

const _outside = 1, _hole = 2, _paper = 3;

/// Every pixel of a frame's artwork as outside the frame, inside one of its
/// holes, or paper. Clear means alpha under 250 (the paper sits at 250 to
/// 254); clear and reachable from an edge is outside, and a clear region the
/// paper encloses is a hole if it is big enough to hold a photo.
Uint8List _regions(Uint8List rgba, int w, int h) {
  final kind = Uint8List(w * h);
  bool clear(int i) => rgba[i * 4 + 3] < 250;

  List<int> fill(int start, int as) {
    final seen = <int>[start];
    kind[start] = as;
    for (var n = 0; n < seen.length; n++) {
      final i = seen[n], x = i % w;
      for (final j in [
        if (x > 0) i - 1,
        if (x < w - 1) i + 1,
        if (i >= w) i - w,
        if (i < w * (h - 1)) i + w,
      ]) {
        if (kind[j] == 0 && clear(j)) {
          kind[j] = as;
          seen.add(j);
        }
      }
    }
    return seen;
  }

  for (var i = 0; i < w * h; i++) {
    final x = i % w, y = i ~/ w;
    final edge = x == 0 || y == 0 || x == w - 1 || y == h - 1;
    if (edge && kind[i] == 0 && clear(i)) fill(i, _outside);
  }
  for (var i = 0; i < w * h; i++) {
    if (kind[i] != 0) continue;
    if (!clear(i)) {
      kind[i] = _paper;
      continue;
    }
    final region = fill(i, _hole);
    // A speck inside a sparkle is a gap in the drawing, not a window.
    if (region.length < w * h * .01) {
      for (final j in region) {
        kind[j] = _paper;
      }
    }
  }
  return kind;
}

/// Whether every pixel within three of ([x], [y]) is the same region, so
/// resampling to the composed size cannot move the point across an edge.
bool _settled(Uint8List kind, int w, int x, int y) {
  final here = kind[y * w + x];
  for (var dy = -3; dy <= 3; dy++) {
    for (var dx = -3; dx <= 3; dx++) {
      if (kind[(y + dy) * w + x + dx] != here) return false;
    }
  }
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(FrameCompositor.evict);

  test('the photo lands in the window, and the paper stays on top', () async {
    final frame = frameById('polaroid_kraft')!;
    final out = await FrameCompositor.compose(
      frame: frame,
      photos: [await _photo(const ui.Color(0xFF00FF00))],
    );
    final image = await _decode(out);
    addTearDown(image.dispose);

    // Its shape is the frame's, not the photo's: a 3:2 picture in a square
    // polaroid must not stretch the paper.
    expect(image.width / image.height, closeTo(frame.aspect, 0.01));

    final window = frame.windows.first.bounds;
    final green = await _pixel(image, window.center.dx, window.center.dy);
    expect(green, 0xFF00FF00, reason: 'the photo shows through the window');

    // 🔴 The paper is drawn after the photo. A corner outside the window is
    // the frame's own artwork, and it must not be the photo.
    final corner = await _pixel(image, 0.5, 0.97);
    expect(corner, isNot(0xFF00FF00), reason: 'paper covers the photo');
  });

  test('a photo of the wrong shape is cropped, never squashed', () async {
    // Very wide against a tall-ish window: a squash would show as the
    // colours meeting somewhere other than the middle.
    final frame = frameById('polaroid_aged')!;
    final out = await FrameCompositor.compose(
      frame: frame,
      photos: [await _photo(const ui.Color(0xFF0000FF), w: 1600, h: 200)],
    );
    final image = await _decode(out);
    addTearDown(image.dispose);
    final window = frame.windows.first.bounds;
    // Filled corner to corner inside the window, which only happens if it
    // was scaled to cover rather than fitted with gaps.
    // ⚠️ Not the very corners: the artwork draws an inner shadow over the
    // photo there, so a corner reads as a darkened blue rather than blue.
    // A quarter in is inside the picture and clear of the bevel.
    for (final (fx, fy) in [
      (window.center.dx, window.top + window.height * .25),
      (window.center.dx, window.top + window.height * .75),
    ]) {
      expect(await _pixel(image, fx, fy), 0xFF0000FF,
          reason: 'a very wide photo still fills the window top to bottom');
    }
  });

  test('two windows take two photos, in order', () async {
    final frame = photoFrames.firstWhere((f) => f.slots == 2);
    final out = await FrameCompositor.compose(frame: frame, photos: [
      await _photo(const ui.Color(0xFFFF0000)),
      await _photo(const ui.Color(0xFF00FF00)),
    ]);
    final image = await _decode(out);
    addTearDown(image.dispose);
    expect(await _pixel(image, frame.windows[0].bounds.center.dx,
        frame.windows[0].bounds.center.dy), 0xFFFF0000);
    expect(await _pixel(image, frame.windows[1].bounds.center.dx,
        frame.windows[1].bounds.center.dy), 0xFF00FF00);
  });

  test('fewer photos than windows leaves the rest empty, and does not throw',
      () async {
    final frame = photoFrames.firstWhere((f) => f.slots == 2);
    final out =
        await FrameCompositor.compose(frame: frame, photos: [await _photo(
            const ui.Color(0xFFFF0000))]);
    final image = await _decode(out);
    addTearDown(image.dispose);
    expect(await _pixel(image, frame.windows[0].bounds.center.dx,
        frame.windows[0].bounds.center.dy), 0xFFFF0000);
    // The second window is still a hole, so it is transparent rather than
    // filled with the first photo.
    final second = await _pixel(image, frame.windows[1].bounds.center.dx,
        frame.windows[1].bounds.center.dy);
    expect(second >> 24, 0, reason: 'an unfilled window stays empty');
  });

  // 🔴 Build 115 cut every photo to the box around its hole. On the cloud
  // the photo showed in the box's corners, outside the cloud's outline, and
  // the box stopped three pixels short of the hole's bottom, which left a
  // thin line showing through under the picture. This reads the artwork
  // itself, not the traced outlines, so it checks the tracing too.
  test('every photo stays inside its paper and fills its hole', () async {
    for (final frame in photoFrames.where((f) => f.slots > 0)) {
      final out = await FrameCompositor.compose(frame: frame, photos: [
        for (var i = 0; i < frame.slots; i++)
          await _photo(const ui.Color(0xFFFF00FF)),
      ]);
      final image = await _decode(out);
      final composed = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();

      final art = await _decode(
          (await rootBundle.load(frame.asset)).buffer.asUint8List());
      final kind = _regions(
          (await art.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List(),
          art.width,
          art.height);

      var outside = 0, inside = 0;
      for (var y = 3; y < art.height - 3; y += 3) {
        for (var x = 3; x < art.width - 3; x += 3) {
          final here = kind[y * art.width + x];
          if (here == _paper || !_settled(kind, art.width, x, y)) continue;
          final cx = ((x + .5) * image.width / art.width).floor();
          final cy = ((y + .5) * image.height / art.height).floor();
          final alpha = composed[(cy * image.width + cx) * 4 + 3];
          if (here == _outside) {
            outside++;
            expect(alpha, lessThan(250),
                reason: '${frame.id}: photo past the paper at $x,$y');
          } else {
            inside++;
            expect(alpha, 255,
                reason: '${frame.id}: gap in the window at $x,$y');
          }
        }
      }
      // Enough of each looked at for the passes above to mean something.
      expect(outside, greaterThan(1000), reason: frame.id);
      expect(inside, greaterThan(1000), reason: frame.id);
      image.dispose();
      art.dispose();
    }
  });

  test('the torn note takes no photo at all', () async {
    final frame = frameById('torn_note')!;
    final out = await FrameCompositor.compose(
      frame: frame,
      photos: [await _photo(const ui.Color(0xFFFF0000))],
    );
    final image = await _decode(out);
    addTearDown(image.dispose);
    // Nowhere for it to go, so the paper comes back as paper rather than
    // the photo leaking out around it.
    expect(await _pixel(image, .5, .5), isNot(0xFFFF0000));
  });

  test('it is stored as WebP where the phone can write one, PNG otherwise',
      () async {
    final png = await FrameCompositor.compose(
      frame: frameById('polaroid_kraft')!,
      photos: [await _photo(const ui.Color(0xFF00FF00))],
    );

    // No channel, as on a build without the Android side: the PNG, whole.
    final plain = await FrameCompositor.forSending(png);
    expect(plain.extension, 'png');
    expect(plain.bytes, png);

    // 🔴 The reason this exists: as PNG a framed photo was about a
    // megabyte, four to six times an ordinary one, and kept forever.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('dayflower/media');
    final small = Uint8List.fromList(List.filled(1000, 1));
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'encodeWebp');
      expect((call.arguments as Map)['quality'], FrameCompositor.webpQuality);
      return small;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final webp = await FrameCompositor.forSending(png);
    expect(webp.extension, 'webp');
    expect(webp.bytes, small);

    // An encoder that gives nothing back is not a reason to send nothing.
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect((await FrameCompositor.forSending(png)).extension, 'png');
  });
}

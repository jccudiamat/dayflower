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

    final window = frame.windows.first;
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
    final window = frame.windows.first;
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
    expect(await _pixel(image, frame.windows[0].center.dx,
        frame.windows[0].center.dy), 0xFFFF0000);
    expect(await _pixel(image, frame.windows[1].center.dx,
        frame.windows[1].center.dy), 0xFF00FF00);
  });

  test('fewer photos than windows leaves the rest empty, and does not throw',
      () async {
    final frame = photoFrames.firstWhere((f) => f.slots == 2);
    final out =
        await FrameCompositor.compose(frame: frame, photos: [await _photo(
            const ui.Color(0xFFFF0000))]);
    final image = await _decode(out);
    addTearDown(image.dispose);
    expect(await _pixel(image, frame.windows[0].center.dx,
        frame.windows[0].center.dy), 0xFFFF0000);
    // The second window is still a hole, so it is transparent rather than
    // filled with the first photo.
    final second = await _pixel(
        image, frame.windows[1].center.dx, frame.windows[1].center.dy);
    expect(second >> 24, 0, reason: 'an unfilled window stays empty');
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

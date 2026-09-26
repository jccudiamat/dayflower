import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;

import 'photo_frames.dart';

/// Puts a photo behind a frame and bakes the two into one picture.
///
/// 🔴 **Baked, not layered at render time.** The result is sent as an
/// ordinary day photo, so it has to *be* a photo: the widget draws it, the
/// thread draws it, saving it to the gallery saves what you saw. A frame
/// kept as a separate layer would mean every one of those surfaces knowing
/// about frames, and a photo that looked different everywhere it appeared.
///
/// The photo is drawn **cover**, centred in the window: a picture is almost
/// never the window's shape, and letterboxing inside a polaroid would show
/// the background through the gaps where the paper is transparent.
class FrameCompositor {
  FrameCompositor._();

  /// Longest side of the result. Big enough to look right on a phone and to
  /// survive a crop.
  ///
  /// ⚠️ Size is decided by [forSending], not by this. As PNG a framed photo
  /// came out at about a megabyte whatever went into it — the paper's
  /// texture dominates — which is four to six times an ordinary photo.
  static const maxSide = 1280.0;

  /// Android's own encoder, behind the channel MediaSaver answers on.
  static const _media = MethodChannel('dayflower/media');

  /// WebP quality. 82 is where the paper's grain stops changing to the eye.
  static const webpQuality = 82;

  /// Frame artwork, decoded once each. There are eleven of them and they are
  /// small; decoding on every shutter press would stall the capture.
  static final _frames = <String, ui.Image>{};

  static Future<ui.Image> _frameImage(PhotoFrame frame) async {
    final known = _frames[frame.id];
    if (known != null) return known;
    final data = await rootBundle.load(frame.asset);
    final image = await decodeImageFromList(data.buffer.asUint8List());
    return _frames[frame.id] = image;
  }

  /// [photos] fill the frame's windows in order, largest window first.
  ///
  /// ⚠️ Fewer photos than windows is allowed and leaves the rest empty,
  /// which is what a half-finished two-photo frame looks like. More are
  /// ignored rather than overflowing onto the paper.
  static Future<Uint8List> compose({
    required PhotoFrame frame,
    required List<Uint8List> photos,
  }) async {
    final art = await _frameImage(frame);
    final scale = maxSide / (art.width > art.height ? art.width : art.height);
    final width = (art.width * scale).roundToDouble();
    final height = (art.height * scale).roundToDouble();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, height));

    final decoded = <ui.Image>[];
    try {
      for (var i = 0; i < frame.windows.length && i < photos.length; i++) {
        final photo = await decodeImageFromList(photos[i]);
        decoded.add(photo);
        final window = frame.windows[i];
        final size = ui.Size(width, height);
        final box = window.boundsIn(size);
        canvas.save();
        // 🔴 Cut to the hole's own shape, not to its box. The box of a
        // cloud reaches past the cloud into corners where the paper is
        // clear, and the photo showed there, outside the frame. The outline
        // also keeps the two photos of a pair apart: each hole is its own
        // shape, with paper between them, so the back photo cannot reach
        // into the front frame's window.
        canvas.clipPath(window.pathIn(size));
        canvas.drawImageRect(photo, _coverSource(photo, box), box,
            ui.Paint()..filterQuality = ui.FilterQuality.high);
        canvas.restore();
      }

      // The paper last, over the photos: the art is a cut-out, and its
      // tape, stickers and torn edges have to sit on top of the picture.
      canvas.drawImageRect(
        art,
        ui.Rect.fromLTWH(0, 0, art.width.toDouble(), art.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, width, height),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.round(), height.round());
      picture.dispose();
      try {
        // ⚠️ PNG, not JPEG. The paper's edges are transparent — a torn note
        // is not a rectangle — and JPEG would fill that with black.
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        return bytes!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      for (final image in decoded) {
        image.dispose();
      }
    }
  }

  /// [png] as it should be stored: WebP where this phone can write it, the
  /// PNG itself where it cannot.
  ///
  /// 🔴 **Not JPEG, and not left as PNG.** JPEG has no transparency, and a
  /// torn note is not a rectangle; PNG kept the edges and cost a megabyte a
  /// photo, for photos that are kept forever. WebP keeps the edges at about
  /// a tenth of that. A phone that cannot encode it — or a build with no
  /// channel, like a test — still sends the PNG: heavier, never wrong.
  static Future<({Uint8List bytes, String extension})> forSending(
    Uint8List png,
  ) async {
    try {
      final webp = await _media.invokeMethod<Uint8List>(
        'encodeWebp',
        {'bytes': png, 'quality': webpQuality},
      );
      if (webp != null && webp.isNotEmpty) {
        return (bytes: webp, extension: 'webp');
      }
    } catch (_) {
      // No channel, or the encode failed. The PNG is below.
    }
    return (bytes: png, extension: 'png');
  }

  /// The part of [photo] that fills [box] without squashing it: the largest
  /// centred rectangle of the photo with the box's proportions.
  static ui.Rect _coverSource(ui.Image photo, ui.Rect box) {
    final photoAspect = photo.width / photo.height;
    final boxAspect = box.width / box.height;
    if (photoAspect > boxAspect) {
      // Wider than the window: take a full-height slice from the middle.
      final w = photo.height * boxAspect;
      return ui.Rect.fromLTWH((photo.width - w) / 2, 0, w, photo.height.toDouble());
    }
    final h = photo.width / boxAspect;
    return ui.Rect.fromLTWH(0, (photo.height - h) / 2, photo.width.toDouble(), h);
  }

  /// Frees the decoded artwork. For tests; the app keeps eleven small images
  /// for as long as it runs, which is the point of caching them.
  static void evict() {
    for (final image in _frames.values) {
      image.dispose();
    }
    _frames.clear();
  }
}

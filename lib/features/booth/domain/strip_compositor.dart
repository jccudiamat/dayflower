import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import 'strip_templates.dart';

/// Renders the finished strip: photos framed on the template's paper.
///
/// Composited **on the client, by whoever completes the strip**. There is no
/// server-side image pipeline (that would need an edge function), and doing
/// it at completion means the result is an ordinary JPEG — so it posts as a
/// normal day photo and the chat, widget and 24h expiry all work unchanged
/// rather than needing a second code path.
class StripCompositor {
  StripCompositor._();

  /// Long edge of the output. Big enough to look right full-screen, small
  /// enough to upload on a phone connection.
  static const _canvasWidth = 1080;

  /// Runs the encode off the UI thread — compositing two photos is hundreds
  /// of milliseconds of pure CPU and will visibly hitch the camera preview.
  static Future<Uint8List> render({
    required StripTemplate template,
    required Uint8List first,
    Uint8List? second,
  }) {
    return compute(
      _renderSync,
      _Job(
        templateId: template.id,
        first: first,
        second: second,
      ),
    );
  }
}

class _Job {
  const _Job({
    required this.templateId,
    required this.first,
    this.second,
  });
  final String templateId;
  final Uint8List first;
  final Uint8List? second;
}

/// Top-level so it can be handed to [compute] — closures cannot cross an
/// isolate boundary.
Uint8List _renderSync(_Job job) {
  final t = StripTemplate.byId(job.templateId);

  final a = _tryDecode(job.first);
  if (a == null) return job.first; // Undecodable: ship the original.
  final b = job.second == null ? null : _tryDecode(job.second!);

  const w = StripCompositor._canvasWidth;
  // Frame proportions borrowed from a real photo booth: a wide margin at the
  // bottom is what makes a polaroid read as a polaroid.
  final pad = (w * 0.045).round();
  final caption = (w * 0.11).round();

  final panes = <img.Image>[a, if (b != null) b];
  final sideBySide = panes.length == 2 && !t.stacked;

  final paneW =
      sideBySide ? ((w - pad * 3) ~/ 2) : (w - pad * 2);
  // 4:5 portrait per pane — the shape a phone camera actually produces.
  final paneH = (paneW * 1.25).round();

  final canvasH = sideBySide
      ? paneH + pad * 2 + caption
      : paneH * panes.length + pad * (panes.length + 1) + caption;

  final canvas = img.Image(width: w, height: canvasH);
  img.fill(canvas, color: _color(t.paper));

  for (var i = 0; i < panes.length; i++) {
    // copyResizeCropSquare would centre-crop to a square; we want the pane's
    // own aspect, so resize-to-cover then crop the overflow.
    final fitted = _cover(panes[i], paneW, paneH);
    final x = sideBySide ? pad + i * (paneW + pad) : pad;
    final y = sideBySide ? pad : pad + i * (paneH + pad);
    img.compositeImage(canvas, fitted, dstX: x, dstY: y);
    // Hairline in the accent colour so the pane edge reads against the paper.
    img.drawRect(
      canvas,
      x1: x,
      y1: y,
      x2: x + paneW - 1,
      y2: y + paneH - 1,
      color: _color(t.accent),
      thickness: 2,
    );
  }

  return Uint8List.fromList(img.encodeJpg(canvas, quality: 88));
}

/// `decodeImage` **throws** on truncated or non-image bytes rather than
/// returning null — its own format sniffers read past the end of a short
/// buffer. Without this a corrupt photo takes the whole isolate down and the
/// send fails with nothing useful to show the user.
img.Image? _tryDecode(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
}

/// Resize so the image covers [w]x[h], then centre-crop the overflow.
img.Image _cover(img.Image src, int w, int h) {
  final scale = (w / src.width) > (h / src.height)
      ? w / src.width
      : h / src.height;
  final resized = img.copyResize(
    src,
    width: (src.width * scale).ceil(),
    height: (src.height * scale).ceil(),
    interpolation: img.Interpolation.cubic,
  );
  return img.copyCrop(
    resized,
    x: ((resized.width - w) / 2).round().clamp(0, resized.width),
    y: ((resized.height - h) / 2).round().clamp(0, resized.height),
    width: w,
    height: h,
  );
}

img.ColorRgb8 _color(dynamic c) {
  final v = (c as dynamic).toARGB32() as int;
  return img.ColorRgb8((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
}

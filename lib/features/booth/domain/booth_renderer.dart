import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'booth_design.dart';

class BoothRenderer {
  static Future<Uint8List> render(BoothDesign design, List<Uint8List> photos) =>
      compute(_render, (design.id, photos));

  /// A versioned studio template stores each partner's shots as a contact
  /// sheet in the existing private strip slot. No schema or public bucket.
  static Future<Uint8List> pack(List<Uint8List> photos) =>
      compute(_pack, photos);

  static Uint8List combine(BoothDesign design, Uint8List a, Uint8List b) {
    final first = _unpack(a, design.layout.shots);
    final second = _unpack(b, design.layout.shots);
    return _render((
      design.id,
      [
        for (var i = 0; i < first.length; i++) _pair(first[i], second[i]),
      ]
    ));
  }
}

img.Image _decode(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('Could not read photo');
  return img.bakeOrientation(image);
}

img.Image _cover(img.Image source, int w, int h) {
  final scale = (w / source.width) > (h / source.height)
      ? w / source.width
      : h / source.height;
  final resized = img.copyResize(source,
      width: (source.width * scale).ceil(),
      height: (source.height * scale).ceil());
  return img.copyCrop(resized,
      x: (resized.width - w) ~/ 2,
      y: (resized.height - h) ~/ 2,
      width: w,
      height: h);
}

Uint8List _render((String, List<Uint8List>) job) {
  final design = BoothDesign.parse(job.$1)!;
  if (job.$2.length != design.layout.shots) {
    throw ArgumentError('Every frame needs a distinct photo');
  }
  const width = 960;
  final height = (width / design.layout.aspect).round();
  final paper = design.look.paper.toARGB32();
  final canvas = img.Image(width: width, height: height);
  img.fill(canvas,
      color:
          img.ColorRgb8((paper >> 16) & 255, (paper >> 8) & 255, paper & 255));
  for (var i = 0; i < design.panes.length; i++) {
    final rect = design.panes[i];
    final photo = _cover(_decode(job.$2[i]), (rect.width * width).round(),
        (rect.height * height).round());
    img.compositeImage(canvas, photo,
        dstX: (rect.left * width).round(), dstY: (rect.top * height).round());
  }
  final ink = design.look.ink.toARGB32();
  img.drawString(canvas, 'DAYFLOWER',
      font: img.arial24,
      x: width ~/ 2 - 75,
      y: height - 64,
      color: img.ColorRgb8((ink >> 16) & 255, (ink >> 8) & 255, ink & 255));
  return Uint8List.fromList(img.encodeJpg(canvas, quality: 92));
}

Uint8List _pack(List<Uint8List> photos) {
  if (photos.isEmpty || photos.length > 4) {
    throw ArgumentError('Invalid shot count');
  }
  final sheet = img.Image(width: 600, height: 900 * photos.length);
  for (var i = 0; i < photos.length; i++) {
    img.compositeImage(sheet, _cover(_decode(photos[i]), 600, 900),
        dstY: i * 900);
  }
  return Uint8List.fromList(img.encodeJpg(sheet, quality: 94));
}

List<img.Image> _unpack(Uint8List bytes, int count) {
  final sheet = _decode(bytes);
  if (sheet.width != 600 || sheet.height != 900 * count) {
    throw const FormatException('This booth needs its original photo set');
  }
  return [
    for (var i = 0; i < count; i++)
      img.copyCrop(sheet, x: 0, y: i * 900, width: 600, height: 900)
  ];
}

Uint8List _pair(img.Image a, img.Image b) {
  final result = img.Image(width: 1200, height: 900);
  img.compositeImage(result, _cover(a, 600, 900));
  img.compositeImage(result, _cover(b, 600, 900), dstX: 600);
  return Uint8List.fromList(img.encodeJpg(result, quality: 94));
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:dayflower/features/booth/domain/strip_compositor.dart';
import 'package:dayflower/features/booth/domain/strip_templates.dart';

/// The compositor is the one piece of this feature with no visual feedback
/// loop — it runs in a background isolate and its output goes straight to
/// Storage. If it silently produces a broken JPEG nothing surfaces that
/// until a partner opens a corrupt bubble, so it is worth pinning here.
void main() {
  late Uint8List portrait;
  late Uint8List landscape;

  setUpAll(() {
    final a = img.Image(width: 800, height: 1200);
    img.fill(a, color: img.ColorRgb8(200, 90, 120));
    portrait = Uint8List.fromList(img.encodeJpg(a));

    // Deliberately the wrong shape: phone photos and webcam grabs disagree,
    // and the compositor has to cover-crop rather than squash.
    final b = img.Image(width: 1600, height: 900);
    img.fill(b, color: img.ColorRgb8(90, 140, 200));
    landscape = Uint8List.fromList(img.encodeJpg(b));
  });

  test('solo template renders a single decodable pane', () async {
    final out = await StripCompositor.render(
      template: StripTemplate.byId('aesthetic'),
      first: portrait,
    );
    final decoded = img.decodeImage(out);
    expect(decoded, isNotNull);
    expect(decoded!.width, 1080);
    expect(decoded.height, greaterThan(1080));
  });

  test('duo stacked template is taller than the side-by-side one', () async {
    final stacked = await StripCompositor.render(
      template: StripTemplate.byId('classic'),
      first: portrait,
      second: landscape,
    );
    final side = await StripCompositor.render(
      template: StripTemplate.byId('split'),
      first: portrait,
      second: landscape,
    );

    final s = img.decodeImage(stacked)!;
    final t = img.decodeImage(side)!;
    expect(s.width, 1080);
    expect(t.width, 1080);
    // Two panes above each other must exceed two panes beside each other.
    expect(s.height, greaterThan(t.height));
  });

  test('a mismatched aspect ratio is cropped, never squashed', () async {
    // Both panes come from the same landscape source; if the compositor
    // squashed instead of cropping, the output height would collapse.
    final out = await StripCompositor.render(
      template: StripTemplate.byId('film_strip'),
      first: landscape,
      second: landscape,
    );
    final decoded = img.decodeImage(out)!;
    // Two 4:5 panes plus padding and caption — comfortably portrait.
    expect(decoded.height, greaterThan(decoded.width));
  });

  test('undecodable input falls through instead of throwing', () async {
    final junk = Uint8List.fromList(const [1, 2, 3, 4, 5]);
    final out = await StripCompositor.render(
      template: StripTemplate.byId('classic'),
      first: junk,
    );
    // Ships the original rather than crashing the send.
    expect(out, junk);
  });

  test('every template id resolves, and unknown ids fall back', () {
    for (final t in StripTemplate.all) {
      expect(StripTemplate.byId(t.id).id, t.id);
    }
    expect(StripTemplate.byId('nope-not-a-template'), StripTemplate.all.first);
    expect(StripTemplate.duo.length + StripTemplate.solo.length,
        StripTemplate.all.length);
  });
}

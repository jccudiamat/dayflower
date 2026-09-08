import 'dart:io';

import 'package:dayflower/features/tulip/domain/flower_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// 🔴 The home-screen widget draws a flower's **artwork** now, falling back
/// to [Flower.emoji] only when the asset cannot be read. That fallback used
/// to be the only thing the widget ever showed — sending "Peach Tulips" to
/// somebody's home screen put a generic 🌷 on it — and it is silent by
/// design, so a flower shipped without its painting would look like the bug
/// coming back rather than like a missing file.
void main() {
  group('flower artwork', () {
    test('every flower a person can send ships its painting', () {
      final missing = [
        for (final flower in FlowerCatalog.pickable)
          if (!File(flower.asset).existsSync()) '${flower.id} (${flower.asset})',
      ];
      expect(missing, isEmpty,
          reason: 'These would draw as a bare emoji on the widget');
    });

    test('the two without artwork are retired, and stay retired', () {
      // Sunflower and Hibiscus predate the painted catalogue. They are out of
      // the picker, so nobody can send one — but old messages still
      // reference them, and those fall back to the glyph, which is exactly
      // what the fallback is for.
      for (final id in ['sunflower', 'hibiscus']) {
        final flower = FlowerCatalog.all.firstWhere((f) => f.id == id);
        expect(flower.retired, isTrue, reason: '$id has no artwork');
        expect(File(flower.asset).existsSync(), isFalse);
      }
    });

    test('the asset path is derived from the id, not stored twice', () {
      // A second field would be a second thing to keep in step; the widget's
      // cache filename is derived from the id for the same reason.
      final flower = FlowerCatalog.all.first;
      expect(flower.asset, 'assets/images/flowers/${flower.id}.webp');
    });
  });
}

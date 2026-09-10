import 'package:dayflower/features/tulip/domain/flower_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 🔴 The home-screen widget copies a flower's artwork out of the app bundle
/// with `rootBundle.load(flower.asset)`, and the failure is **silent**: the
/// cache helper catches, returns null, and the widget quietly draws the emoji
/// — which is exactly what "the widget still shows no image" looks like.
///
/// A file existing on disk is not the same as it being reachable under that
/// key at runtime; only the `assets:` list in pubspec makes it so.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every pickable flower loads from the bundle by its asset key',
      () async {
    final broken = <String>[];
    for (final flower in FlowerCatalog.pickable) {
      try {
        final data = await rootBundle.load(flower.asset);
        if (data.lengthInBytes == 0) broken.add('${flower.id} (empty)');
      } catch (e) {
        broken.add('${flower.id} (${flower.asset})');
      }
    }
    expect(broken, isEmpty, reason: 'these would draw as a bare emoji');
  });

  test('the one on screen right now resolves', () async {
    final f = FlowerCatalog.all.firstWhere((f) => f.id == 'tulips_and_lilies');
    final data = await rootBundle.load(f.asset);
    expect(data.lengthInBytes, greaterThan(1000));
  });
}

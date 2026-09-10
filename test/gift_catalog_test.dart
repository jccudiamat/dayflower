import 'package:dayflower/features/gifts/data/gift_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rows from the dashboard', () {
    test('a full row maps across', () {
      final p = GiftProduct.fromMap({
        'id': 'soy-candle',
        'name': 'Soy candle',
        'merchant': 'mianhae.ph',
        'category': 'Home',
        'price': 199,
        'price_max': 249,
        'voucher': true,
        'recipients': ['Partner'],
        'url': 'https://shopee.ph/x?affiliate=me',
        'image_url': 'https://cdn.example/x.jpg',
        'image_source': 'https://cdn.example/x.jpg',
      });
      expect(p.id, 'soy-candle');
      expect(p.priceLabel, '₱199–₱249');
      expect(p.url, contains('affiliate=me'));
      expect(p.imageUrl, 'https://cdn.example/x.jpg');
    });

    test('a sparse row does not take the screen down with it', () {
      // ⚠️ These rows are edited by hand in a dashboard. One missing field
      // should cost that field, not the whole catalogue.
      final p = GiftProduct.fromMap({'id': 'mystery'});
      expect(p.id, 'mystery');
      expect(p.name, 'Gift');
      expect(p.price, 0);
      expect(p.recipients, isEmpty);
      expect(p.imageUrl, isNull);
    });

    test('an empty image_url means the bundled asset, not a broken URL', () {
      // 🔴 A blank cell in a dashboard is '' far more often than it is null,
      // and Image.network('') throws.
      for (final blank in ['', '   ', null]) {
        final p = GiftProduct.fromMap({'id': 'coffee-set', 'image_url': blank});
        expect(p.imageUrl, isNull, reason: 'blank was ${blank.runtimeType}');
        expect(p.asset, 'assets/images/gifts/coffee-set.jpg');
      }
    });

    test('the asset path is derived from the id, so ids must match filenames',
        () {
      final p = GiftProduct.fromMap({'id': 'crochet-bouquet'});
      expect(p.asset, 'assets/images/gifts/crochet-bouquet.jpg');
    });
  });

  group('the bundled fallback', () {
    test('is not empty — it is what fills the screen offline', () {
      expect(giftProducts, isNotEmpty);
    });

    test('every bundled product has a link and a price', () {
      for (final p in giftProducts) {
        expect(p.url, startsWith('http'), reason: p.id);
        expect(p.price, greaterThan(0), reason: p.id);
      }
    });

    test('ids are unique — they are the primary key on the server', () {
      final ids = giftProducts.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}

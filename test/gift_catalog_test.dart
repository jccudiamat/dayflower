import 'dart:io';
import 'package:dayflower/features/gifts/data/gift_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Catalog has varied gifts, seller destinations and bundled images', () {
    expect(giftProducts.length, greaterThanOrEqualTo(9));
    expect(giftProducts.map((p) => p.category).toSet().length,
        greaterThanOrEqualTo(8));
    expect(giftProducts.map((p) => p.id).toSet().length, giftProducts.length);
    for (final product in giftProducts) {
      final uri = Uri.parse(product.url);
      expect(uri.scheme, 'https');
      expect(uri.host, 'shopee.ph');
      expect(uri.path, matches(r'i\.\d+\.\d+$'));
      expect(File(product.asset).lengthSync(), greaterThan(1000));
    }
  });
  test('Recipient, type, search and price range filters combine', () {
    final card = giftProducts.firstWhere((p) => p.id == 'anniversary-card');
    expect(card.matches(recipient: 'Partner', category: 'Cards', budget: 200),
        isTrue);
    expect(card.matches(recipient: 'Friends'), isFalse);
    expect(card.matches(category: 'Coffee'), isFalse);
    expect(card.matches(query: ' PAPEL '), isTrue);
    final coffee = giftProducts.firstWhere((p) => p.id == 'coffee-set');
    expect(coffee.matches(budget: 400), isFalse);
    expect(coffee.matches(budget: 500), isTrue);
  });
}

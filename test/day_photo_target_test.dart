import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';

/// Two rules that decide where a photo ends up, and one that decides whether
/// a website bouquet is visible in the app at all. Both were wrong once and
/// neither fails loudly — a photo simply turns up somewhere nobody asked for
/// it, and a bouquet simply never appears — so they are pinned here.

FlowerMessage photo({
  required bool toWidget,
  required bool toChat,
  Duration age = Duration.zero,
  String sender = 'me',
}) =>
    FlowerMessage(
      id: 'm',
      pairId: 'p',
      senderId: sender,
      imagePath: 'pair/photo.jpg',
      sentAt: DateTime.now().subtract(age),
      toWidget: toWidget,
      toChat: toChat,
    );

FlowerMessage text(String body) => FlowerMessage(
      id: 'm',
      pairId: 'p',
      senderId: 'me',
      note: body,
      sentAt: DateTime.now(),
    );

void main() {
  group('a photo only counts for the home screen if it was sent there', () {
    test('chat-only photo is never fresh for the widget', () {
      // 🔴 The regression: this was a plain age check, so choosing "Chat" as
      // the destination did nothing — the photo still landed on My Day, on
      // the partner's story ring, and in the widget rotation.
      final chatOnly = photo(toWidget: false, toChat: true);
      expect(chatOnly.isFreshForWidget, isFalse);
    });

    test('a widget photo is fresh for its first day', () {
      expect(photo(toWidget: true, toChat: false).isFreshForWidget, isTrue);
      expect(
        photo(toWidget: true, toChat: false, age: const Duration(hours: 23))
            .isFreshForWidget,
        isTrue,
      );
    });

    test('a widget photo stops being fresh after its day', () {
      expect(
        photo(toWidget: true, toChat: false, age: const Duration(hours: 25))
            .isFreshForWidget,
        isFalse,
      );
    });

    test('"both" still reaches the home screen', () {
      expect(photo(toWidget: true, toChat: true).isFreshForWidget, isTrue);
    });

    test('a chat-only photo has no home-screen countdown', () {
      // Otherwise the bubble counts down to leaving a place it never was.
      expect(photo(toWidget: false, toChat: true).widgetTimeLeft, isNull);
      expect(photo(toWidget: true, toChat: false).widgetTimeLeft, isNotNull);
    });
  });

  group('a bouquet is recognised by its gift link', () {
    test('reads the id out of a pasted link', () {
      final m = text('I made you something. https://mydayflower.com/g/9zqvdBvR1Ppi');
      expect(m.isBouquet, isTrue);
      expect(m.bouquetGiftId, '9zqvdBvR1Ppi');
      expect(m.bouquetUrl, 'https://mydayflower.com/g/9zqvdBvR1Ppi');
      expect(m.bouquetCardUrl,
          'https://mydayflower.com/g/9zqvdBvR1Ppi/opengraph-image');
    });

    test('accepts www and http', () {
      expect(text('http://www.mydayflower.com/g/GBdIg5FMvfUm').bouquetGiftId,
          'GBdIg5FMvfUm');
    });

    test('ignores anything that is not one of our gift links', () {
      // Deliberately narrow: our host, our /g/ path, our id shape. Everything
      // else is just a link someone sent, and dressing it up as a bouquet
      // would be worse than leaving it alone.
      for (final body in [
        'https://mydayflower.com/bouquet',
        'https://mydayflower.com/photobooth',
        'https://example.com/g/9zqvdBvR1Ppi',
        'https://notmydayflower.com.evil.test/g/9zqvdBvR1Ppi',
        'just a message',
        '',
      ]) {
        expect(text(body).isBouquet, isFalse, reason: body);
      }
    });

    test('a bouquet says so on a lock screen, rather than reading out a URL',
        () {
      final m = text('https://mydayflower.com/g/9zqvdBvR1Ppi');
      expect(m.alertLine, 'Sent you a bouquet 💐');
    });
  });

  group('a preview is written from the reader\'s side', () {
    test('your own message never says it was sent to you', () {
      final m = text('https://mydayflower.com/g/9zqvdBvR1Ppi');
      expect(m.previewFor(mine: true), 'You sent a bouquet 💐');
      expect(m.previewFor(mine: false), 'Sent you a bouquet 💐');
    });

    test('a captionless photo reads differently for each side', () {
      final m = photo(toWidget: false, toChat: true);
      expect(m.previewFor(mine: true), contains('You shared'));
      expect(m.previewFor(mine: false), isNot(contains('You shared')));
    });
  });
}

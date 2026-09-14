import 'package:dayflower/features/tulip/data/reaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reacting is a toggle, like the mood chip — see migration 0045.
///
/// The rule is one line, which is exactly why it is worth pinning: a
/// "reactions" feature that can only ever add is the easy thing to build and
/// leaves somebody laughing at a message that stopped being funny.

void main() {
  group('tapping', () {
    test('the same one again takes it back', () {
      expect(tapRemoves(mine: '❤️', tapped: '❤️'), isTrue);
    });

    test('a different one moves rather than clearing', () {
      // 🔴 If this removed instead, changing your mind would cost two
      // long-presses and land on nothing in between.
      expect(tapRemoves(mine: '❤️', tapped: '😂'), isFalse);
    });

    test('the first one is always a set', () {
      expect(tapRemoves(mine: null, tapped: '🥺'), isFalse);
    });
  });

  group('the choices', () {
    test('are few enough to hit without reading', () {
      // A row, not a grid. If this ever grows past what fits on the
      // narrowest phone, it needs to become a different control — not
      // smaller taps.
      expect(reactionChoices.length, lessThanOrEqualTo(6));
    });

    test('have no duplicates', () {
      expect(reactionChoices.toSet().length, reactionChoices.length);
    });

    test('are each a single short grapheme the database will accept', () {
      // The column is `check (char_length(emoji) between 1 and 16)`. A
      // multi-codepoint emoji (❤️ is two) still has to fit.
      for (final emoji in reactionChoices) {
        expect(emoji.isNotEmpty, isTrue);
        expect(emoji.length, lessThanOrEqualTo(16), reason: emoji);
      }
    });
  });
}

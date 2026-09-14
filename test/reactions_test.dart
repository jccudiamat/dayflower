import 'package:dayflower/features/tulip/data/reaction_choices.dart';
import 'package:dayflower/features/tulip/data/reaction_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reacting is a toggle, like the mood chip — see migration 0045.
///
/// The rule is one line, which is exactly why it is worth pinning: a
/// "reactions" feature that can only ever add is the easy thing to build and
/// leaves somebody laughing at a message that stopped being funny.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    test('fill the bar exactly', () {
      // A row, not a grid: six is what clears the narrowest phone without
      // the taps getting small enough to miss.
      expect(defaultReactions.length, reactionSlots);
    });

    test('have no duplicates', () {
      // 🔴 Two identical slots is a bar with a dead button: tapping either
      // sets the same reaction, and one of them can never take it back.
      expect(defaultReactions.toSet().length, defaultReactions.length);
      expect(reactionPalette.toSet().length, reactionPalette.length);
    });

    test('are each short enough for the column to accept', () {
      // The column is `check (char_length(emoji) between 1 and 16)`. A
      // multi-codepoint emoji (❤️ is two) still has to fit.
      for (final emoji in [...defaultReactions, ...reactionPalette]) {
        expect(emoji.isNotEmpty, isTrue);
        expect(emoji.length, lessThanOrEqualTo(16), reason: emoji);
      }
    });

    test('every default is offered in the palette', () {
      // ⚠️ Otherwise swapping a slot away from a default would make it
      // unreachable — you could lose the heart and never get it back.
      for (final emoji in defaultReactions) {
        expect(reactionPalette, contains(emoji), reason: emoji);
      }
    });
  });

  /// What a stored set has to look like before it is trusted.
  group('a set read back from storage', () {
    test('a good one is kept', () {
      const stored = ['❤️', '😂', '😮', '😢', '🌹', '🌻'];
      expect(ReactionChoices.sanitise(stored), stored);
    });

    test('nothing saved yet falls back to the defaults', () {
      expect(ReactionChoices.sanitise(null), defaultReactions);
    });

    test('the wrong number of slots falls back', () {
      // 🔴 Covers the upgrade: a build that adds a seventh slot would read
      // a six-long list and draw a gap where a button should be.
      expect(ReactionChoices.sanitise(['❤️']), defaultReactions);
      expect(
        ReactionChoices.sanitise(['❤️', '😂', '😮', '😢', '🌷', '🌼', '🔥']),
        defaultReactions,
      );
    });

    test('a blank slot falls back rather than drawing a hole', () {
      expect(
        ReactionChoices.sanitise(['❤️', '😂', '😮', '😢', '🌷', '  ']),
        defaultReactions,
      );
    });

    test('a duplicated slot falls back', () {
      expect(
        ReactionChoices.sanitise(['❤️', '❤️', '😮', '😢', '🌷', '🌼']),
        defaultReactions,
      );
    });
  });

  group('swapping a slot', () {
    Future<ReactionChoices> choices() async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(reactionChoicesProvider.notifier);
      // Let the constructor's own load land before touching it.
      await Future<void>.delayed(Duration.zero);
      return notifier;
    }

    test('puts the new emoji in that slot and leaves the rest alone', () async {
      final bar = await choices();
      await bar.replaceAt(4, '🌹');
      expect(bar.state[4], '🌹');
      expect(bar.state[0], defaultReactions[0]);
      expect(bar.state.length, reactionSlots);
    });

    test('survives a restart', () async {
      final bar = await choices();
      await bar.replaceAt(0, '🥰');

      final prefs = await SharedPreferences.getInstance();
      expect(ReactionChoices.sanitise(prefs.getStringList('chat_reactions'))[0],
          '🥰');
    });

    test('refuses one that is already on the bar', () async {
      // 🔴 Two identical slots is a button that can never take its own
      // reaction back — see sanitise.
      final bar = await choices();
      final before = [...bar.state];
      await bar.replaceAt(1, before[3]);
      expect(bar.state, before);
    });

    test('ignores a slot that does not exist', () async {
      final bar = await choices();
      final before = [...bar.state];
      await bar.replaceAt(9, '🔥');
      await bar.replaceAt(-1, '🔥');
      expect(bar.state, before);
    });

    test('reset puts the six back', () async {
      final bar = await choices();
      await bar.replaceAt(2, '🔥');
      await bar.reset();
      expect(bar.state, defaultReactions);
    });
  });
}

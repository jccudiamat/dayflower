import 'package:dayflower/features/reminders/domain/sticky_note.dart';
import 'package:flutter_test/flutter_test.dart';

/// A note's paper has to be the same every time it is drawn — in the app, on
/// the home screen, after a reinstall, on the other phone. None of that is
/// observable by looking at one screen once, which is what these pin down.

void main() {
  const ids = [
    '0f3f7069-bdca-47f5-900b-f3651401212d',
    '89e2f32e-23a7-4b9e-ac75-94bd655f147e',
    'a',
    '',
    '🌷-emoji-in-an-id',
  ];

  group('the paper', () {
    test('is the same every time for the same id', () {
      for (final id in ids) {
        expect(stickyNotePaperFor(id), same(stickyNotePaperFor(id)));
      }
    });

    test('is always one of the five papers', () {
      for (final id in ids) {
        expect(kStickyNotePapers, contains(stickyNotePaperFor(id)));
      }
    });

    test('spreads across the palette rather than favouring one', () {
      // A hash that collapsed to one bucket would still pass the two tests
      // above and produce a wall of identical notes.
      final used = <StickyNotePaper>{};
      for (var i = 0; i < 200; i++) {
        used.add(stickyNotePaperFor('reminder-$i'));
      }
      expect(used.length, kStickyNotePapers.length);
    });
  });

  group('the tilt', () {
    test('is small enough to read as carelessness, not decoration', () {
      for (var i = 0; i < 200; i++) {
        final tilt = stickyNoteTiltFor('reminder-$i');
        expect(tilt.abs(), lessThanOrEqualTo(2.6));
      }
    });

    test('leans both ways', () {
      final tilts = [for (var i = 0; i < 60; i++) stickyNoteTiltFor('r$i')];
      expect(tilts.any((t) => t < -0.4), isTrue);
      expect(tilts.any((t) => t > 0.4), isTrue);
    });

    test('is not correlated with the paper', () {
      // 🔴 Using one hash for both made every blush note lean left and every
      // mint one lean right — which reads as a pattern rather than as a
      // person pressing notes on without looking.
      final byPaper = <StickyNotePaper, Set<double>>{};
      for (var i = 0; i < 300; i++) {
        final id = 'reminder-$i';
        byPaper
            .putIfAbsent(stickyNotePaperFor(id), () => <double>{})
            .add(stickyNoteTiltFor(id));
      }
      for (final tilts in byPaper.values) {
        expect(tilts.length, greaterThan(3),
            reason: 'one paper must not imply one tilt');
      }
    });
  });

  test('the hash does not use String.hashCode', () {
    // Dart does not promise hashCode is stable across VM launches, so a note
    // could change colour on restart. This pins the actual FNV-1a values:
    // if the implementation is ever swapped, this fails loudly rather than
    // every existing note quietly re-papering itself.
    expect(stickyNotePaperFor('dayflower'), stickyNotePaperFor('dayflower'));
    final index = kStickyNotePapers.indexOf(stickyNotePaperFor('dayflower'));
    expect(index, isNonNegative);
    // Recorded from the current implementation, on purpose.
    expect(index, 1);
  });
}

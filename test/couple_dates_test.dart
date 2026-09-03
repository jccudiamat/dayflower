import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/features/us/domain/couple_dates.dart';

/// The monthsary and the anniversary are never entered by anyone — they are
/// derived from one start date and then shown as fact on the Events page. A
/// wrong day here does not look like a bug; it looks like the couple's
/// anniversary, on the wrong day, with nothing to notice it by.

void main() {
  // The example from the request: together since 10 April 2022.
  final start = DateTime(2022, 4, 10);

  group('monthsary', () {
    test('is the same day of the month, every month', () {
      expect(nextMonthsary(start, DateTime(2026, 9, 3)), DateTime(2026, 9, 10));
      expect(nextMonthsary(start, DateTime(2026, 9, 11)),
          DateTime(2026, 10, 10));
    });

    test('today counts as today, not next month', () {
      // "Monthsary in 30 days" on the morning of your monthsary is the
      // difference between the app noticing and the app being useless.
      expect(nextMonthsary(start, DateTime(2026, 9, 10)),
          DateTime(2026, 9, 10));
    });

    test('rolls the year over in December', () {
      expect(nextMonthsary(start, DateTime(2026, 12, 20)),
          DateTime(2027, 1, 10));
    });

    test('a 31st couple clamps to the end of a short month', () {
      // ⚠️ The one that silently misfires: April has no 31st. Rolling into
      // May would skip the month entirely and land the "monthsary" on 1 May.
      final endOfMonth = DateTime(2021, 1, 31);
      expect(nextMonthsary(endOfMonth, DateTime(2026, 4, 1)),
          DateTime(2026, 4, 30));
      expect(nextMonthsary(endOfMonth, DateTime(2026, 2, 1)),
          DateTime(2026, 2, 28));
      // And a leap February still gets the 29th.
      expect(nextMonthsary(endOfMonth, DateTime(2028, 2, 1)),
          DateTime(2028, 2, 29));
    });

    test('never skips a month', () {
      // Walk two years for a 31st couple; every month must produce a date
      // inside that same month.
      final endOfMonth = DateTime(2020, 8, 31);
      for (var m = 0; m < 24; m++) {
        final first = DateTime(2026 + m ~/ 12, (m % 12) + 1, 1);
        final next = nextMonthsary(endOfMonth, first);
        expect(next.month, first.month,
            reason: 'month ${first.month}/${first.year} was skipped');
        expect(next.year, first.year);
      }
    });
  });

  group('anniversary', () {
    test('is the same month and day, every year', () {
      expect(nextAnniversary(start, DateTime(2026, 9, 3)),
          DateTime(2027, 4, 10));
      expect(nextAnniversary(start, DateTime(2026, 1, 1)),
          DateTime(2026, 4, 10));
    });

    test('today counts as today', () {
      expect(nextAnniversary(start, DateTime(2026, 4, 10)),
          DateTime(2026, 4, 10));
    });

    test('counts which one it is', () {
      expect(anniversaryNumber(start, DateTime(2027, 4, 10)), 5);
    });

    test('a leap-day couple stays inside February', () {
      // 1 March would be the lazy answer and it is the wrong month.
      final leap = DateTime(2020, 2, 29);
      expect(nextAnniversary(leap, DateTime(2026, 1, 1)),
          DateTime(2026, 2, 28));
      expect(nextAnniversary(leap, DateTime(2028, 1, 1)),
          DateTime(2028, 2, 29));
    });
  });

  group('how long', () {
    test('days between ignores the time of day', () {
      expect(daysBetween(DateTime(2026, 9, 1, 23), DateTime(2026, 9, 2, 1)), 1);
    });

    test('months tick over on the day itself, not before', () {
      expect(monthsBetween(start, DateTime(2022, 5, 9)), 0);
      expect(monthsBetween(start, DateTime(2022, 5, 10)), 1);
      expect(monthsBetween(start, DateTime(2026, 9, 3)), 52);
    });

    test('reads as a length of time once there is a year of it', () {
      expect(togetherLabel(start, DateTime(2026, 9, 3)), '4 years, 4 months');
      expect(togetherLabel(start, DateTime(2023, 4, 10)), '1 year');
      expect(togetherLabel(start, DateTime(2022, 6, 10)), '2 months');
    });

    test('the first month is still counted in days', () {
      // "0 months" on day three would be a strange thing to show somebody.
      expect(togetherLabel(start, DateTime(2022, 4, 13)), '3 days');
      expect(togetherLabel(start, DateTime(2022, 4, 11)), '1 day');
      expect(togetherLabel(start, DateTime(2022, 4, 10)), 'Today');
    });

    test('a future start date does not read as negative', () {
      // Somebody mis-taps the year in the picker; the card must not say
      // "-4 years".
      expect(monthsBetween(DateTime(2030, 1, 1), DateTime(2026, 9, 3)), 0);
      expect(togetherLabel(DateTime(2030, 1, 1), DateTime(2026, 9, 3)),
          'Today');
    });
  });
}

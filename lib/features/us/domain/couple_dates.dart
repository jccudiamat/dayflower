/// The dates a couple never enters, because their start date already said
/// them: the monthsary and the anniversary.
///
/// Pure functions over a start date, so the Us page, the Events page and
/// anything later all derive the same answer rather than each doing their
/// own arithmetic. The awkward cases here are real ones — a couple who
/// started on the 31st has no monthsary in February, and one who started on
/// 29 February has an anniversary only every fourth year — and both of them
/// silently produce a *wrong day* rather than an error if nobody thinks
/// about them.
library;

/// Calendar days between [from] and [to], ignoring time of day.
///
/// Built from the date parts rather than `Duration.inDays`, which counts
/// 24-hour blocks: across a daylight-saving change one of those blocks is
/// 23 or 25 hours long, and "days together" would jump or stall by one for
/// no reason the couple could see.
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Whole months elapsed since [start], as of [now].
///
/// Counts completed monthsaries: on the day itself the count ticks over.
int monthsBetween(DateTime start, DateTime now) {
  var months = (now.year - start.year) * 12 + (now.month - start.month);
  if (_dayOfMonthFor(now.year, now.month, start.day) > now.day) months -= 1;
  return months < 0 ? 0 : months;
}

/// The next monthsary on or after [from].
///
/// ⚠️ **A start day past the 28th does not exist in every month.** Someone
/// who got together on the 31st has no 31st in April, and pretending they
/// do rolls the date silently into May. It clamps to the last day of the
/// short month instead — the 30th in April, the 28th in February — which is
/// how people actually treat it, and never skips a month.
DateTime nextMonthsary(DateTime start, DateTime from) {
  final today = DateTime(from.year, from.month, from.day);
  var year = today.year;
  var month = today.month;

  for (var i = 0; i < 2; i++) {
    final candidate =
        DateTime(year, month, _dayOfMonthFor(year, month, start.day));
    if (!candidate.isBefore(today)) return candidate;
    month += 1;
    if (month > 12) {
      month = 1;
      year += 1;
    }
  }
  // Unreachable: at most one advance is ever needed. Kept total rather than
  // throwing, because a wrong date here is a card, and an exception here is
  // a blank screen.
  return DateTime(year, month, _dayOfMonthFor(year, month, start.day));
}

/// The next anniversary on or after [from].
///
/// ⚠️ **29 February.** A leap-day couple has a real anniversary only every
/// fourth year; this gives them the 28th in between rather than 1 March,
/// which keeps it inside the right month.
DateTime nextAnniversary(DateTime start, DateTime from) {
  final today = DateTime(from.year, from.month, from.day);
  final thisYear =
      DateTime(today.year, start.month, _dayOfMonthFor(today.year, start.month, start.day));
  if (!thisYear.isBefore(today)) return thisYear;
  final next = today.year + 1;
  return DateTime(next, start.month, _dayOfMonthFor(next, start.month, start.day));
}

/// Which anniversary the one on [date] is — 1st, 2nd, 3rd…
int anniversaryNumber(DateTime start, DateTime date) =>
    date.year - start.year;

/// [day], clamped to the last day that exists in that month.
int _dayOfMonthFor(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return day > lastDay ? lastDay : day;
}

/// "3 years, 2 months" — the long form under the start date.
///
/// Months rather than days past the first year, because "1,187 days" is a
/// number and "3 years, 2 months" is a length of time.
String togetherLabel(DateTime start, DateTime now) {
  final months = monthsBetween(start, now);
  if (months < 1) {
    final days = daysBetween(start, now);
    if (days <= 0) return 'Today';
    return days == 1 ? '1 day' : '$days days';
  }
  final years = months ~/ 12;
  final rest = months % 12;
  final parts = <String>[
    if (years > 0) years == 1 ? '1 year' : '$years years',
    if (rest > 0) rest == 1 ? '1 month' : '$rest months',
  ];
  return parts.join(', ');
}

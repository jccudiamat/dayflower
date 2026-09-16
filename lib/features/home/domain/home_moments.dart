import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_profile.dart';
import '../../dates/data/event_repository.dart';
import '../../onboarding/data/user_repository.dart';
import '../../pairing/data/pair_repository.dart';
import '../../reunion/data/reunion_repository.dart';
import '../../us/domain/couple_dates.dart';

/// Minute updates refresh local time, date boundaries and relative labels.
final homeClockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

enum HomeMomentKind { reunion, anniversary, birthday, monthsary, custom }

class HomeMoment {
  const HomeMoment(
      {required this.id,
      required this.kind,
      required this.title,
      required this.date,
      this.note = '',
      this.location = ''});
  final String id, title, note, location;
  final HomeMomentKind kind;
  final DateTime date;
  String get artwork => switch (kind) {
        HomeMomentKind.birthday => 'birthday',
        HomeMomentKind.reunion => 'reunion',
        HomeMomentKind.anniversary || HomeMomentKind.monthsary => 'monthsary',
        HomeMomentKind.custom => 'calendar',
      };
  int daysFrom(DateTime now) => DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(now.year, now.month, now.day))
      .inDays;
  String countdown(DateTime now) => switch (daysFrom(now)) {
        0 => 'Today',
        1 => 'Tomorrow',
        final n => 'In $n days',
      };
}

/// Uses the same milestone arithmetic as Events, and never persists derived dates.
List<HomeMoment> collectHomeMoments(
    {required DateTime now,
    DateTime? start,
    UserProfile? me,
    UserProfile? partner,
    Reunion? reunion,
    List<Map<String, dynamic>> custom = const []}) {
  final events = <HomeMoment>[];
  if (start != null && !start.isAfter(now)) {
    final anniversary = nextAnniversary(start, now);
    final monthsary = nextMonthsary(start, now);
    if (monthsary != anniversary) {
      events.add(HomeMoment(
          id: 'monthsary',
          kind: HomeMomentKind.monthsary,
          title: 'Our monthsary',
          date: monthsary,
          note: '${monthsBetween(start, monthsary)} months together'));
    }
    events.add(HomeMoment(
        id: 'anniversary',
        kind: HomeMomentKind.anniversary,
        title: 'Our anniversary',
        date: anniversary,
        note: '${anniversaryNumber(start, anniversary)} years together'));
  }
  for (final person in [me, partner]) {
    if (person?.birthday == null) continue;
    final name = person!.petName ?? person.displayName;
    events.add(HomeMoment(
        id: 'birthday-${person.id}',
        kind: HomeMomentKind.birthday,
        title: person.id == me?.id ? 'Your birthday' : '$name’s birthday',
        date: nextBirthday(person.birthday!, now)));
  }
  if (reunion != null) {
    events.add(HomeMoment(
        id: 'reunion-${reunion.id}',
        kind: HomeMomentKind.reunion,
        title: reunion.title,
        date: reunion.happensAt,
        location: reunion.destination ?? '',
        note: reunion.note ?? ''));
  }
  for (final row in custom) {
    final date = DateTime.tryParse(row['date']?.toString() ?? '');
    if (date == null) continue;
    events.add(HomeMoment(
        id: 'event-${row['id']}',
        kind: HomeMomentKind.values.firstWhere((k) => k.name == row['kind'],
            orElse: () => HomeMomentKind.custom),
        title: row['title']?.toString() ?? 'Our special day',
        date: date,
        note: row['note']?.toString() ?? '',
        location: row['location']?.toString() ?? ''));
  }
  return events.where((e) => e.daysFrom(now) >= 0).toList()
    ..sort((a, b) {
      final day = a.daysFrom(now).compareTo(b.daysFrom(now));
      if (day != 0) return day;
      final priority = a.kind.index.compareTo(b.kind.index);
      return priority != 0 ? priority : a.id.compareTo(b.id);
    });
}

final homeMomentsProvider = Provider.autoDispose<List<HomeMoment>>((ref) {
  final now = ref.watch(homeClockProvider).valueOrNull ?? DateTime.now();
  return collectHomeMoments(
      now: now,
      start: ref.watch(currentPairProvider).valueOrNull?.togetherSince,
      me: ref.watch(userProfileProvider).valueOrNull,
      partner: ref.watch(partnerProfileProvider).valueOrNull,
      reunion: ref.watch(reunionProvider).valueOrNull,
      custom: ref.watch(customEventsProvider).valueOrNull ?? const []);
});

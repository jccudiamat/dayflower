import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/features/home/domain/home_moments.dart';
import 'package:dayflower/features/reunion/data/reunion_repository.dart';

void main() {
  test('No data produces no invented events', () {
    expect(collectHomeMoments(now: DateTime(2026, 9, 15)), isEmpty);
  });
  test('Sorts real occasions and filters expired or invalid custom dates', () {
    final now = DateTime(2026, 9, 15, 20);
    final events = collectHomeMoments(
        now: now,
        start: DateTime(2022, 4, 16),
        reunion: Reunion(
            id: 'r',
            pairId: 'p',
            title: 'Next hug',
            happensAt: DateTime(2026, 9, 15, 22)),
        partner: UserProfile(
            id: 'b', displayName: 'Wifey', birthday: DateTime(1999, 9, 17)),
        custom: [
          {'id': 1, 'title': 'Old', 'date': '2026-09-14', 'kind': 'custom'},
          {'id': 2, 'title': 'Invalid', 'date': 'not-a-date', 'kind': 'custom'},
          {
            'id': 3,
            'title': 'Movie night',
            'date': '2026-09-18',
            'kind': 'custom'
          },
        ]);
    expect(events.take(4).map((e) => e.title),
        ['Next hug', 'Our monthsary', 'Wifey’s birthday', 'Movie night']);
    expect(events.first.countdown(now), 'Today');
    expect(events[1].countdown(now), 'Tomorrow');
    expect(events[2].countdown(now), 'In 2 days');
  });
  test('Anniversary replaces duplicate monthsary on the same date', () {
    final events = collectHomeMoments(
        now: DateTime(2026, 4, 15), start: DateTime(2022, 4, 16));
    expect(events.length, 1);
    expect(events.single.kind, HomeMomentKind.anniversary);
  });
  test('Short-month monthsary and leap-day birthday follow Events rules', () {
    final events = collectHomeMoments(
        now: DateTime(2027, 2, 1),
        start: DateTime(2022, 1, 31),
        partner: UserProfile(
            id: 'b', displayName: 'Partner', birthday: DateTime(2000, 2, 29)));
    expect(events.first.date, DateTime(2027, 2, 28));
    expect(events.firstWhere((e) => e.kind == HomeMomentKind.birthday).date,
        DateTime(2027, 3, 1));
  });
  test('Today remains visible until local midnight', () {
    final input = [
      {'id': 1, 'title': 'Date night', 'date': '2026-09-15', 'kind': 'custom'}
    ];
    expect(
        collectHomeMoments(now: DateTime(2026, 9, 15, 23, 59), custom: input)
            .length,
        1);
    expect(
        collectHomeMoments(now: DateTime(2026, 9, 16), custom: input), isEmpty);
  });
  test('Artwork follows the event kind without inferring from its title', () {
    final events = collectHomeMoments(now: DateTime(2026, 9, 15), custom: [
      {'id': 1, 'title': 'Our party', 'date': '2026-09-16', 'kind': 'birthday'},
      {'id': 2, 'title': 'Home soon', 'date': '2026-09-17', 'kind': 'reunion'},
      {'id': 3, 'title': 'Special', 'date': '2026-09-18', 'kind': 'unknown'},
    ]);
    expect(events.map((e) => e.artwork), ['birthday', 'reunion', 'calendar']);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/features/home/data/mood_prefs.dart';

/// The chat header shows your partner's mood where it used to count the
/// flowers between you. A count could not be wrong; a mood can — and the way
/// it goes wrong is by being *old*, which looks exactly like being right.

UserProfile _profile({String? mood, DateTime? at}) => UserProfile(
      id: 'u1',
      displayName: 'Sheena',
      mood: mood,
      moodAt: at,
    );

void main() {
  group('freshness', () {
    test('a mood set just now is shown', () {
      final profile = _profile(mood: 'happy', at: DateTime.now());
      expect(profile.freshMood, 'happy');
      expect(Mood.fromName(profile.freshMood), Mood.happy);
    });

    test('a mood set two days ago is not', () {
      // ⚠️ The whole point. Without the timestamp check this would report
      // Tuesday's feeling as how they are on Thursday, with nothing on
      // screen to suggest it was old.
      final profile = _profile(
        mood: 'low',
        at: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(profile.freshMood, isNull);
    });

    test('the boundary is a day, and it holds on both sides', () {
      final justInside = _profile(
        mood: 'calm',
        at: DateTime.now().subtract(const Duration(hours: 23, minutes: 30)),
      );
      final justOutside = _profile(
        mood: 'calm',
        at: DateTime.now().subtract(const Duration(hours: 24, minutes: 30)),
      );
      expect(justInside.freshMood, 'calm');
      expect(justOutside.freshMood, isNull);
    });

    test('a mood with no timestamp is not trusted', () {
      // Rows written before 0024 have the column but nothing in it. An
      // undated mood cannot be told from one set last week.
      expect(_profile(mood: 'tired').freshMood, isNull);
    });

    test('no mood at all is no mood', () {
      expect(_profile(at: DateTime.now()).freshMood, isNull);
      expect(_profile(mood: '', at: DateTime.now()).freshMood, isNull);
      expect(_profile().freshMood, isNull);
    });
  });

  group('parsing', () {
    test('every mood round-trips through its stored name', () {
      // The column is free text and the enum is the source of truth for
      // what is valid — this is the join between them.
      for (final mood in Mood.values) {
        expect(Mood.fromName(mood.name), mood);
      }
    });

    test('a mood this build has never heard of reads as none', () {
      // Lets a newer build add a seventh mood without a migration having to
      // land in front of it. Null renders as "Tap to say hello", not a
      // crash.
      expect(Mood.fromName('ecstatic'), isNull);
      expect(Mood.fromName(null), isNull);
    });
  });

  group('rows off the wire', () {
    test('a profile from before 0024 still parses', () {
      final profile = UserProfile.fromMap({
        'id': 'u1',
        'display_name': 'Sheena',
        'timezone': 'Asia/Manila',
      });
      expect(profile.mood, isNull);
      expect(profile.moodAt, isNull);
      expect(profile.freshMood, isNull);
    });

    test('mood_at comes back local, not UTC', () {
      // Compared against DateTime.now(), which is local. A UTC timestamp
      // would make a mood set in Dubai look four hours older than it is —
      // and near the boundary, would hide one that is still current.
      final profile = UserProfile.fromMap({
        'id': 'u1',
        'display_name': 'Sheena',
        'mood': 'loved',
        'mood_at': DateTime.now().toUtc().toIso8601String(),
      });
      expect(profile.moodAt!.isUtc, isFalse);
      expect(profile.freshMood, 'loved');
    });
  });
}

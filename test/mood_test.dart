import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/features/home/data/mood_prefs.dart';
import 'package:dayflower/core/time/zones.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// The conversation card and the chat header both show your partner's mood.
/// The way a mood goes wrong is by being *old*, which looks exactly like
/// being right — so what counts as "still true" is pinned here.

UserProfile _profile({String? mood, DateTime? at, String zone = 'Asia/Manila'}) =>
    UserProfile(
      id: 'u1',
      displayName: 'Sheena',
      timezone: zone,
      mood: mood,
      moodAt: at,
    );

void main() {
  // ⚠️ Without this every zone silently resolves to UTC (see safeLocation),
  // and these tests would pass while testing something else.
  setUpAll(tzdata.initializeTimeZones);

  group('freshness', () {
    test('a mood set just now is shown', () {
      final profile = _profile(mood: 'happy', at: DateTime.now());
      expect(profile.freshMood, 'happy');
      expect(Mood.fromName(profile.freshMood), Mood.happy);
    });

    test('a mood set two days ago is not', () {
      // ⚠️ Without the timestamp check this would report Tuesday's feeling
      // as how they are on Thursday, with nothing on screen to suggest it
      // was old.
      final profile = _profile(
        mood: 'low',
        at: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(profile.freshMood, isNull);
    });

    test('the boundary is the day, not twenty-four hours', () {
      // 🔴 The regression this replaced. Manila is UTC+8, so these two
      // instants are 23 hours apart — inside the old rolling window — and
      // on different days. A mood set at 9pm Monday was still being
      // reported at 8pm Tuesday, about a day nobody was living in any
      // more, and so nobody was ever asked again.
      expect(
        isSameDayIn('Asia/Manila', DateTime.utc(2026, 6, 4, 13),
            now: DateTime.utc(2026, 6, 5, 12)),
        isFalse,
      );

      // And the other way: nearly 24 hours apart, still the same day, so a
      // mood set a minute after midnight lasts until midnight.
      expect(
        isSameDayIn('Asia/Manila', DateTime.utc(2026, 6, 4, 16, 1),
            now: DateTime.utc(2026, 6, 5, 15, 59)),
        isTrue,
      );
    });

    test('the day belongs to the setter, not the reader', () {
      // Long distance is the whole app: the two phones are routinely on
      // different dates. Both judge a mood against the zone on the profile
      // carrying it, so the card and the chat header can never disagree
      // about whether anything was said today.
      //
      // 13:00 UTC is the same instant as 21:00 in Manila and 17:00 in
      // Dubai — still the 4th in both. Six hours later it is the 5th in
      // Manila and not yet in Dubai, and that is the disagreement.
      final evening = DateTime.utc(2026, 6, 4, 13);
      final laterThatNight = DateTime.utc(2026, 6, 4, 19);
      expect(isSameDayIn('Asia/Manila', evening, now: laterThatNight), isFalse);
      expect(isSameDayIn('Asia/Dubai', evening, now: laterThatNight), isTrue);
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

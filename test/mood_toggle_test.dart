import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/features/home/data/mood_prefs.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// The mood chip is a toggle, and it empties overnight.
///
/// Both halves are easy to get quietly wrong. A toggle that only ever sets
/// leaves someone stuck saying they feel a way they no longer do, with no
/// way to take it back. And a chip that never expires stops being a
/// question: it sits there lit from Tuesday, so nobody is ever asked again
/// — which is what it did before, while the *partner* stopped seeing that
/// same mood after a day. The two sides disagreed about one fact.

/// No session, so `select()` stops before the server write. The local half
/// is what this file is about; the row is covered by mood_test.dart.
ProviderContainer containerWith({String zone = 'Asia/Manila'}) =>
    ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue(null),
        userProfileProvider.overrideWith(
          (ref) async => UserProfile(
            id: 'u1',
            displayName: 'Sheena',
            timezone: zone,
          ),
        ),
      ],
    );

/// Waits for the notifier's own `_load()` to land before asserting.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);

  group('tapping', () {
    test('a tap sets the mood, and tapping it again takes it back', () async {
      SharedPreferences.setMockInitialValues({});
      final container = containerWith();
      addTearDown(container.dispose);
      final moods = container.read(moodProvider.notifier);

      await moods.select(Mood.loved);
      expect(container.read(moodProvider), Mood.loved);

      await moods.select(Mood.loved);
      expect(container.read(moodProvider), isNull,
          reason: 'the same chip twice is how you say "never mind"');
    });

    test('tapping a different mood moves, rather than clearing', () async {
      SharedPreferences.setMockInitialValues({});
      final container = containerWith();
      addTearDown(container.dispose);
      final moods = container.read(moodProvider.notifier);

      await moods.select(Mood.happy);
      await moods.select(Mood.tired);
      expect(container.read(moodProvider), Mood.tired);
    });

    test('clearing forgets the timestamp too', () async {
      // ⚠️ A left-behind timestamp would make the *next* mood look as old as
      // the one that was cleared, and it would vanish at the wrong midnight.
      SharedPreferences.setMockInitialValues({});
      final container = containerWith();
      addTearDown(container.dispose);
      final moods = container.read(moodProvider.notifier);

      await moods.select(Mood.calm);
      await moods.select(Mood.calm);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('current_mood'), isNull);
      expect(prefs.getString('current_mood_at'), isNull);
    });
  });

  group('the day turning', () {
    test('yesterday\'s mood is gone on opening the app', () async {
      // 🔴 The regression: the local copy had no expiry at all, so your own
      // chip stayed lit from days ago.
      SharedPreferences.setMockInitialValues({
        'current_mood': 'stressed',
        'current_mood_at': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      });
      final container = containerWith();
      addTearDown(container.dispose);

      container.read(moodProvider);
      await settle();
      expect(container.read(moodProvider), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('current_mood'), isNull,
          reason: 'a stale mood should be forgotten, not just hidden');
    });

    test('today\'s mood survives a restart', () async {
      SharedPreferences.setMockInitialValues({
        'current_mood': 'happy',
        'current_mood_at': DateTime.now().toIso8601String(),
      });
      final container = containerWith();
      addTearDown(container.dispose);

      container.read(moodProvider);
      await settle();
      expect(container.read(moodProvider), Mood.happy);
    });

    test('a mood stored before this change is not trusted', () async {
      // Anyone upgrading has `current_mood` and no timestamp beside it. An
      // undated mood cannot be told from one set last week, so it goes.
      SharedPreferences.setMockInitialValues({'current_mood': 'low'});
      final container = containerWith();
      addTearDown(container.dispose);

      container.read(moodProvider);
      await settle();
      expect(container.read(moodProvider), isNull);
    });

    test('refresh clears a chip the day has passed under', () async {
      // The app was open across midnight; resume calls this.
      SharedPreferences.setMockInitialValues({});
      final container = containerWith();
      addTearDown(container.dispose);
      final moods = container.read(moodProvider.notifier);

      await moods.select(Mood.loved);
      expect(container.read(moodProvider), Mood.loved);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'current_mood_at',
        DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      );
      await moods.refresh();
      expect(container.read(moodProvider), isNull);
    });

    test('refresh leaves today alone', () async {
      SharedPreferences.setMockInitialValues({});
      final container = containerWith();
      addTearDown(container.dispose);
      final moods = container.read(moodProvider.notifier);

      await moods.select(Mood.calm);
      await moods.refresh();
      expect(container.read(moodProvider), Mood.calm);
    });
  });
}

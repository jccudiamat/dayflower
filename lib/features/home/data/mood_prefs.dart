import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/time/zones.dart';
import '../../onboarding/data/user_repository.dart';

/// The moods you can set.
///
/// Deliberately six. A longer list turns a one-tap check-in into a decision,
/// and the point of this card is that it costs nothing to answer honestly.
enum Mood {
  happy('😊', 'Happy'),
  loved('🥰', 'Loved'),
  calm('😌', 'Calm'),
  low('😔', 'Low'),
  stressed('😤', 'Stressed'),
  tired('😴', 'Tired');

  const Mood(this.emoji, this.label);

  final String emoji;
  final String label;

  static Mood? fromName(String? name) {
    if (name == null) return null;
    for (final m in Mood.values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// Your current mood.
///
/// **It reaches your partner now** (migration 0024). It used to be
/// device-local — persisted so the card survived a restart and going no
/// further — which made a couples app ask "how are you feeling?" and then
/// keep the answer.
///
/// ⚠️ **It is still written to SharedPreferences as well, and that is not
/// redundancy.** The local copy is what makes the chip fill the instant it
/// is tapped and what the card reads on a cold start before any network
/// call returns. The row is what the other phone sees. If the write fails,
/// the local one stands and the next tap tries again — the wrong failure
/// here would be un-selecting a chip somebody just chose because a request
/// timed out.
class MoodPrefs extends StateNotifier<Mood?> {
  MoodPrefs(this._ref) : super(null) {
    _load();
  }

  final Ref _ref;

  static const _kMood = 'current_mood';
  static const _kMoodAt = 'current_mood_at';

  /// Whether the person has tapped a chip since this was built.
  ///
  /// 🔴 [_load] runs off the constructor and finishes a frame or two later.
  /// A tap inside that window used to be overwritten by whatever was on
  /// disk — usually nothing, so the chip filled and then emptied on its own.
  /// Rare by hand and constant on a cold start, which is exactly when
  /// somebody opens the app to say how they are.
  bool _tapped = false;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_tapped) return;
      final stored = Mood.fromName(prefs.getString(_kMood));
      final at = DateTime.tryParse(prefs.getString(_kMoodAt) ?? '');
      // 🔴 The local copy used to have no expiry at all, so your own chip
      // stayed lit from days ago while your partner had long stopped seeing
      // it — the two sides of the same mood disagreeing. It expires on the
      // same rule now, which is the one in UserProfile.freshMood.
      state = _stillToday(at) ? stored : null;
      if (state == null && stored != null) await _forget(prefs);
    } catch (e) {
      debugPrint('mood load failed: $e');
    }
  }

  /// Clears the chip once the day has turned.
  ///
  /// ⚠️ Called on resume rather than on a timer. The realistic way a day
  /// turns under somebody is that the phone was asleep, and a midnight
  /// timer that fires in the background to blank a chip nobody is looking
  /// at is a wakeup for nothing.
  Future<void> refresh() async {
    if (state == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = DateTime.tryParse(prefs.getString(_kMoodAt) ?? '');
      if (_stillToday(at)) return;
      state = null;
      await _forget(prefs);
    } catch (e) {
      debugPrint('mood refresh failed: $e');
    }
  }

  /// The day is the one where the person setting it lives — their profile's
  /// zone, not the phone's — so this phone and theirs agree about whether
  /// anything has been said today. Falls back to the device's own day while
  /// the profile is still loading, and to "not today" for an undated mood,
  /// which is what every mood written before this change is.
  bool _stillToday(DateTime? at) {
    if (at == null) return false;
    final zone = _ref.read(userProfileProvider).valueOrNull?.timezone;
    if (zone != null) return isSameDayIn(zone, at);
    final now = DateTime.now();
    return at.year == now.year && at.month == now.month && at.day == now.day;
  }

  Future<void> _forget(SharedPreferences prefs) async {
    await prefs.remove(_kMood);
    await prefs.remove(_kMoodAt);
  }

  /// Tapping the mood you already have clears it — the toggle every
  /// single-select chip row uses, and the only way to say "never mind".
  Future<void> select(Mood mood) async {
    final next = state == mood ? null : mood;
    _tapped = true;
    state = next;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (next == null) {
        await _forget(prefs);
      } else {
        await prefs.setString(_kMood, next.name);
        // Stored beside the mood, not derived on read: without it the chip
        // cannot tell a mood set this morning from one set last week.
        await prefs.setString(_kMoodAt, DateTime.now().toIso8601String());
      }
    } catch (e) {
      debugPrint('mood save failed: $e');
    }

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      await _ref.read(userRepositoryProvider).setMood(userId, next?.name);
    } catch (e) {
      // Deliberately silent, and deliberately not rolled back. The chip
      // stays where it was tapped; the next change tries again.
      debugPrint('mood sync failed: $e');
    }
  }
}

final moodProvider =
    StateNotifierProvider<MoodPrefs, Mood?>((ref) => MoodPrefs(ref));

/// How your partner said they are feeling, or null when they haven't said
/// or it has gone stale.
///
/// Reads [UserProfile.freshMood] rather than the raw column, so a mood set
/// two days ago shows as nothing instead of as how they feel today.
final partnerMoodProvider = Provider.autoDispose<Mood?>((ref) {
  final partner = ref.watch(partnerProfileStreamProvider).valueOrNull;
  return Mood.fromName(partner?.freshMood);
});

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/providers/supabase_provider.dart';
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

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = Mood.fromName(prefs.getString(_kMood));
    } catch (e) {
      debugPrint('mood load failed: $e');
    }
  }

  /// Tapping the mood you already have clears it — the toggle every
  /// single-select chip row uses, and the only way to say "never mind".
  Future<void> select(Mood mood) async {
    final next = state == mood ? null : mood;
    state = next;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (next == null) {
        await prefs.remove(_kMood);
      } else {
        await prefs.setString(_kMood, next.name);
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

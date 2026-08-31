import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
/// **Device-local.** There is no `moods` table, so nothing here reaches your
/// partner yet — persisting it at least means the card survives a restart
/// instead of forgetting what you told it. Syncing needs a migration plus a
/// realtime stream, the same shape as `flower_messages`.
class MoodPrefs extends StateNotifier<Mood?> {
  MoodPrefs() : super(null) {
    _load();
  }

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
  }
}

final moodProvider =
    StateNotifierProvider<MoodPrefs, Mood?>((ref) => MoodPrefs());

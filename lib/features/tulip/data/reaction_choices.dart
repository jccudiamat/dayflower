import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The six on the bar.
///
/// Four of them are the ones every messenger has, because a reaction is a
/// reflex and a reflex should land where the hand already expects it. The
/// last two are where this app stops copying: a thumbs-up between two people
/// who are together is a strange thing to send, and 🙏 means half a dozen
/// things depending on who you ask. A tulip and a daisy mean one.
const defaultReactions = <String>['❤️', '😂', '😮', '😢', '🌷', '🌼'];

/// How many fit. Not a preference — the bar floats over a message and six is
/// what clears the narrowest phone without the taps getting small enough to
/// miss.
const reactionSlots = 6;

/// What a slot can be swapped for, in Chat settings.
///
/// ⚠️ Deliberately a short list rather than the system emoji keyboard. The
/// point of the bar is that you hit it without reading; a set drawn from
/// thousands is a set nobody can learn the shape of.
const reactionPalette = <String>[
  '❤️', '🥰', '😍', '😘', '💗', '💐',
  '😂', '🤣', '😮', '😢', '🥺', '😭',
  '🌷', '🌼', '🌸', '🌹', '🌻', '✨',
  '👍', '🙏', '🔥', '🎉', '☀️', '🌙',
];

/// The six this phone offers, remembered across launches.
///
/// ⚠️ **Device-local, not shared with the partner.** It is a choice about
/// your own thumb, not about the conversation — the same reasoning as the
/// theme and the pulse alerts. Syncing it would mean one person's taste
/// quietly rearranging the other's bar.
class ReactionChoices extends StateNotifier<List<String>> {
  ReactionChoices() : super(defaultReactions) {
    _load();
  }

  static const _key = 'chat_reactions';

  /// Anything that is not exactly [reactionSlots] usable emoji falls back to
  /// the defaults rather than rendering a short or empty bar.
  ///
  /// 🔴 Covers the upgrade too: a build that later adds a seventh slot would
  /// otherwise read a six-long list and draw a gap.
  @visibleForTesting
  static List<String> sanitise(List<String>? stored) {
    if (stored == null || stored.length != reactionSlots) {
      return defaultReactions;
    }
    if (stored.any((e) => e.trim().isEmpty)) return defaultReactions;
    // Two identical slots are a bar with a dead button on it — tapping
    // either sets the same reaction, and one of them can never be removed
    // by tapping the other.
    if (stored.toSet().length != stored.length) return defaultReactions;
    return List.unmodifiable(stored);
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = sanitise(prefs.getStringList(_key));
    } catch (e) {
      debugPrint('reaction choices load failed: $e');
    }
  }

  /// Puts [emoji] in slot [index]. A no-op if it already sits elsewhere on
  /// the bar — see [sanitise] on why duplicates are not allowed.
  Future<void> replaceAt(int index, String emoji) async {
    if (index < 0 || index >= state.length) return;
    if (state[index] == emoji) return;
    if (state.contains(emoji)) return;

    final next = [...state]..[index] = emoji;
    state = List.unmodifiable(next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, next);
    } catch (e) {
      debugPrint('reaction choices save failed: $e');
    }
  }

  Future<void> reset() async {
    state = defaultReactions;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('reaction choices reset failed: $e');
    }
  }
}

final reactionChoicesProvider =
    StateNotifierProvider<ReactionChoices, List<String>>(
  (ref) => ReactionChoices(),
);

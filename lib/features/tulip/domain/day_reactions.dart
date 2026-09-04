/// The one-tap reactions to somebody's day.
///
/// A reaction is a **reply to that photo**, not a flower and not a bare
/// message. It goes into the thread as text carrying `reply_to`, which is
/// what makes an emoji arriving three hours later still say what it was
/// answering.
///
/// ⚠️ The previous version sent a real `classic_tulip` **flower** instead.
/// That put a flower in the conversation — an event with its own weight in
/// this app, one you would have chosen deliberately from the catalog — in
/// answer to a tap meant to say "nice". Reacting and giving somebody a
/// flower are not the same gesture.
class DayReaction {
  const DayReaction({
    required this.id,
    required this.emoji,
    required this.label,
  });

  /// ⚠️ **This, not the emoji, is what crosses process boundaries.** The
  /// home-screen widget hands its tap to the background isolate as a URI,
  /// and an emoji in a URI is at the mercy of whoever percent-encodes it on
  /// the way through. An ascii id cannot be mangled.
  final String id;

  final String emoji;

  /// For screen readers and the widget's content description. Never drawn.
  final String label;

  static const heart = DayReaction(id: 'heart', emoji: '❤️', label: 'Love');
  static const like = DayReaction(id: 'like', emoji: '👍', label: 'Like');
  static const flower =
      DayReaction(id: 'flower', emoji: '🌷', label: 'Flower');
  static const sad = DayReaction(id: 'sad', emoji: '😢', label: 'Sad');
  static const haha = DayReaction(id: 'haha', emoji: '😂', label: 'Haha');

  /// ⚠️ Order and membership are mirrored by the widget layout's five views
  /// and by `TodaysTulipWidget.REACTIONS` — changing this list means
  /// changing both. Five because that is what fits across a widget without
  /// the targets getting too small to hit.
  static const values = [heart, like, flower, sad, haha];

  /// Null for an id this build does not know, which is how a widget left on
  /// an older layout after an update degrades: the tap does nothing rather
  /// than posting a mystery character into the conversation.
  static DayReaction? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final r in values) {
      if (r.id == id) return r;
    }
    return null;
  }
}

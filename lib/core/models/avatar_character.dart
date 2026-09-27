/// A drawn person to stand in for someone who has no photo: a boy or a girl,
/// chosen at sign-up ("Which one is you?") and changeable in Settings.
///
/// Stored as [id] on `users.avatar`, the same column a chosen flower goes
/// in, so one choice replaces the other. ⚠️ Never an id a flower uses. An
/// older build that does not know these ids reads them as no flower chosen,
/// and shows its default flower instead: never a crash, never blank.
enum AvatarCharacter {
  boy('boy', 'Boy', '👦'),
  girl('girl', 'Girl', '👧');

  const AvatarCharacter(this.id, this.label, this.emoji);

  final String id;

  /// For screen readers and the picker.
  final String label;

  /// Where only a character will do: the home-screen widget's header.
  final String emoji;

  String get asset => 'assets/images/avatars/$id.webp';

  static AvatarCharacter? byId(String? id) {
    for (final c in AvatarCharacter.values) {
      if (c.id == id) return c;
    }
    return null;
  }
}

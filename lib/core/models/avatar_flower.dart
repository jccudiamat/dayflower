/// The flower that stands in for a person.
///
/// Deliberately **not** the send catalog (`FlowerCatalog`): that one carries
/// artwork, meanings and retired entries, none of which an avatar needs, and
/// an avatar must never disappear because a sendable flower was retired.
///
/// Stored as [id] on `users.avatar` (migration 0015).
enum AvatarFlower {
  daisy('daisy', '🌼', 'Daisy'),
  tulip('tulip', '🌷', 'Tulip'),
  rose('rose', '🌹', 'Rose'),
  sunflower('sunflower', '🌻', 'Sunflower'),
  hibiscus('hibiscus', '🌺', 'Hibiscus'),
  blossom('blossom', '🌸', 'Blossom'),
  lavender('lavender', '🪻', 'Lavender'),
  lotus('lotus', '🪷', 'Lotus');

  const AvatarFlower(this.id, this.emoji, this.label);

  final String id;
  final String emoji;
  final String label;

  static const fallback = AvatarFlower.tulip;

  static AvatarFlower? byId(String? id) {
    if (id == null) return null;
    for (final f in AvatarFlower.values) {
      if (f.id == id) return f;
    }
    // An id written by a newer build than this one: fall back rather than
    // throw, so an out-of-date phone still renders the partner's row.
    return null;
  }

  /// What to show for someone who has never chosen.
  ///
  /// Gender only ever picks the *default*; [avatar] always wins when set, so
  /// anyone can pick anything and nothing is inferred once they have.
  static AvatarFlower forUser({String? avatar, String? gender}) {
    final chosen = byId(avatar);
    if (chosen != null) return chosen;
    return defaultFor(gender);
  }

  static AvatarFlower defaultFor(String? gender) {
    switch (gender?.trim().toLowerCase()) {
      case 'male':
      case 'm':
      case 'man':
        return AvatarFlower.daisy;
      case 'female':
      case 'f':
      case 'woman':
        return AvatarFlower.tulip;
      default:
        // Unset — including every account that existed before 0015. A neutral
        // default beats guessing from a name.
        return fallback;
    }
  }
}

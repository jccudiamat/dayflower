import 'dart:ui';

/// Every illustration Memories draws, by path.
///
/// ⚠️ The originals live in `design/memories/` in the main checkout, ~30 MB
/// of mockups. What ships is made by `tool/shrink_memories.py`: cut out of
/// its page, sized to what it is drawn at, WebP. The APK sits half a
/// megabyte under the 50 MiB the updater can publish, so run the script
/// rather than dropping an original in.
class MemoriesAssets {
  MemoriesAssets._();

  static const _dir = 'assets/images/memories';

  /// Across the top of Flowers: a garden, and a sign saying whose.
  static const gardenHero = '$_dir/garden_hero.webp';

  /// Its width over its height, so the garden is never cropped.
  static const gardenAspect = 1000 / 260;

  /// Thumbnails for memories with no picture of their own.
  static const timelineJournal = '$_dir/timeline_journal.webp';
  static const timelineCard = '$_dir/timeline_card.webp';
  static const timelineBouquet = '$_dir/timeline_bouquet.webp';

  static const _months = [
    'january', 'february', 'march', 'april', 'may', 'june', 'july',
    'august', 'september', 'october', 'november', 'december',
  ];

  /// [month] (1 to 12)'s journal cover.
  static String cover(int month) =>
      '$_dir/journal_${_months[(month - 1).clamp(0, 11)]}.webp';

  /// Where each cover's "goals · highlights" line was painted, as a share
  /// of the cover's height, and in what ink. The painted line is erased
  /// (it had no numbers, and would be 3pt tall on the shelf); the app
  /// writes the real counts there, in the same colour.
  ///
  /// Printed by `tool/shrink_memories.py`; regenerate them together.
  static const coverLabels = <(double, Color)>[
    (0.814, Color(0xFF777CA6)), // January
    (0.755, Color(0xFF9E5C6B)), // February
    (0.459, Color(0xFF717D6F)), // March
    (0.509, Color(0xFF845D73)), // April
    (0.472, Color(0xFF829C88)), // May
    (0.521, Color(0xFF86A2C0)), // June
    (0.848, Color(0xFF89698A)), // July
    (0.429, Color(0xFFAC5C5E)), // August
    (0.481, Color(0xFF4C6D90)), // September
    (0.359, Color(0xFFB3604C)), // October
    (0.796, Color(0xFF965148)), // November
    (0.803, Color(0xFF6E6E9A)), // December
  ];

  /// [month]'s label position and ink.
  static (double, Color) coverLabel(int month) =>
      coverLabels[(month - 1).clamp(0, 11)];
}

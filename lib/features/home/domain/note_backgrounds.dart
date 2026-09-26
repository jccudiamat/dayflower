/// A backdrop for a note: chosen by whoever writes the note, and shown on
/// the other one's Home behind the note and their My Day beside it.
///
/// ⚠️ **The id is what is stored** (users.home_note_bg, migration 0053).
/// Never rename one: a note written with it would lose its background. An
/// id this build does not know reads as none ([noteBackgroundById]).
class NoteBackground {
  const NoteBackground({
    required this.id,
    required this.name,
    required this.dark,
    required this.scrap,
  });

  final String id;

  /// For the picker, in the couple's own words.
  final String name;

  /// Whether words on it are written light. Measured, not guessed: the
  /// lightness of the half the note sits over (see PROGRESS, 2026-09-26).
  final bool dark;

  /// The scrap of paper your own note is written on while theirs has this
  /// background, chosen to sit well on it: golden paper in morning light,
  /// lavender under the stars.
  final NoteScrap scrap;

  String get asset => 'assets/images/note_backgrounds/$id.webp';
}

/// A scrap of paper to write a note on, drawn at its own shape so its torn
/// edges are not stretched.
class NoteScrap {
  const NoteScrap(this.asset, this.aspect, {this.inset = .16});

  final String asset;

  /// Width over height of the artwork, trimmed to the paper.
  final double aspect;

  /// How far in from the top and bottom the words start, as a share of the
  /// height: more on a tilted or torn scrap, whose corners are further in.
  final double inset;
}

const _kraft = NoteScrap('assets/images/note_scraps/kraft.webp', 2.46);

/// The scrap your note is written on when theirs has no background.
const defaultNoteScrap = NoteScrap('assets/images/note_paper.webp', 2.66);

/// Every background a note can have, in the order the picker offers them.
/// None, the default, is not one of them: it is no background at all.
const noteBackgrounds = <NoteBackground>[
  NoteBackground(
    id: 'morning_light',
    name: 'Morning light',
    dark: false,
    scrap: NoteScrap('assets/images/note_scraps/golden.webp', 1.60,
        inset: .24),
  ),
  NoteBackground(
    id: 'clear_sky',
    name: 'Clear sky',
    dark: false,
    scrap: NoteScrap('assets/images/note_scraps/white_rounded.webp', 2.42),
  ),
  NoteBackground(
    id: 'paper_sky',
    name: 'Paper sky',
    dark: false,
    scrap: NoteScrap('assets/images/note_scraps/cream_torn.webp', 2.08),
  ),
  NoteBackground(
    id: 'pink_pets',
    name: 'Pink pets',
    dark: false,
    scrap: NoteScrap('assets/images/note_scraps/pink.webp', 2.93),
  ),
  NoteBackground(
    id: 'scrapbook_star',
    name: 'Scrapbook',
    dark: false,
    scrap: _kraft,
  ),
  NoteBackground(
    id: 'paper_window',
    name: 'Paper window',
    dark: false,
    scrap: NoteScrap('assets/images/note_scraps/cream_rough.webp', 1.54,
        inset: .24),
  ),
  NoteBackground(
    id: 'starry_bears',
    name: 'Starry bears',
    dark: true,
    scrap: NoteScrap('assets/images/note_scraps/lavender_sky.webp', 2.99),
  ),
  NoteBackground(
    id: 'night_pets',
    name: 'Night pets',
    dark: true,
    scrap: NoteScrap('assets/images/note_scraps/cream_wavy.webp', 1.78,
        inset: .2),
  ),
  NoteBackground(
    id: 'cozy_night',
    name: 'Cozy night',
    dark: true,
    scrap: _kraft,
  ),
];

/// The background with [id], or null: none chosen, or one this build does
/// not have.
NoteBackground? noteBackgroundById(String? id) {
  if (id == null) return null;
  for (final b in noteBackgrounds) {
    if (b.id == id) return b;
  }
  return null;
}

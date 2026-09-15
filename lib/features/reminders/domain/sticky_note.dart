import 'package:flutter/material.dart';

/// What makes a reminder look like a note somebody stuck there, rather than
/// a row in a list.
///
/// Three things, and only three: a paper colour, a slight tilt, and ink
/// instead of UI text. Everything else — the tick, the time, the emoji — is
/// the same information the card always carried.
///
/// ## Why it is derived, not stored
///
/// A note's colour has to be the same every time it is drawn: in the app, on
/// the home screen, after a reinstall, on the other person's phone. Storing
/// it would mean a migration, a column nobody edits, and a default for every
/// row written before it existed. Deriving it from the reminder's id gives
/// all of that for free, and an id never changes.
///
/// ⚠️ **The widget does not re-derive this.** The resolved colour crosses to
/// Kotlin as a hex string in the sync payload — see `syncStickyNote`. Two
/// implementations of the same hash in two languages is exactly the kind of
/// thing that drifts silently, and the failure would be a note that changes
/// colour when you put it on your home screen.
@immutable
class StickyNotePaper {
  const StickyNotePaper({
    required this.fill,
    required this.edge,
    required this.ink,
  });

  /// The paper itself.
  final Color fill;

  /// A half-tone of the paper, for the fold at the top corner and the
  /// hairline. Not a grey: a shadow on coloured paper is that colour, darker.
  final Color edge;

  /// What is written on it. Plum rather than black — black on a tinted
  /// paper reads as a UI label, and the point is that this is handwriting.
  final Color ink;
}

/// The papers, in Dayflower's own hues rather than stationery-shop primaries.
///
/// ⚠️ Canary yellow and neon pink are what a real sticky note is, and both
/// would be the loudest thing in an app built on midnight plum and lavender.
/// These are the same five notes at a lower volume — still obviously paper,
/// still obviously this app.
const kStickyNotePapers = <StickyNotePaper>[
  // Blush, a shade off AppColors.blush.
  StickyNotePaper(
    fill: Color(0xFFFCE4EF),
    edge: Color(0xFFF3CBDF),
    ink: Color(0xFF4A2338),
  ),
  // Lavender.
  StickyNotePaper(
    fill: Color(0xFFEAE3FA),
    edge: Color(0xFFD5C9F0),
    ink: Color(0xFF332552),
  ),
  // Butter — the nod to what a sticky note actually is.
  StickyNotePaper(
    fill: Color(0xFFFBF0D2),
    edge: Color(0xFFEFDFB4),
    ink: Color(0xFF4A3D1C),
  ),
  // Mint.
  StickyNotePaper(
    fill: Color(0xFFDCF1E5),
    edge: Color(0xFFBFE2CF),
    ink: Color(0xFF1E4433),
  ),
  // Sky.
  StickyNotePaper(
    fill: Color(0xFFDDEAF9),
    edge: Color(0xFFBFD6EF),
    ink: Color(0xFF1F3A55),
  ),
];

/// The paper for one reminder. Stable for the life of the id.
StickyNotePaper stickyNotePaperFor(String id) =>
    kStickyNotePapers[_stableHash(id) % kStickyNotePapers.length];

/// How far this note sits off square, in degrees.
///
/// Small — between about −2.6° and +2.6°. A wall of notes each tilted ten
/// degrees is a scrapbook; this is what a real note does when a person
/// presses it on without looking.
///
/// ⚠️ Derived from a *different* mixing of the same id than the colour. Using
/// one hash for both makes every blush note lean left and every mint one
/// lean right, which reads as a pattern rather than as carelessness.
double stickyNoteTiltFor(String id) {
  final steps = _stableHash('tilt:$id') % 11; // 0..10
  return (steps - 5) * 0.52;
}

/// A small, deterministic, platform-independent hash.
///
/// ⚠️ **Not `String.hashCode`.** Dart makes no promise that it is stable
/// across runs — it is explicitly allowed to differ between VM launches —
/// so a note's colour could change every time the app restarted. This is
/// FNV-1a, which is fixed by its constants and will read the same in ten
/// years and in any other language that needs it.
int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

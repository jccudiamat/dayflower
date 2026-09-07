import 'dart:math';

/// The little emoji beside your name in the greeting, chosen once per launch.
///
/// It used to be a hardcoded 🌷 — correct for the app's name and completely
/// static, which after the twentieth morning is furniture rather than a
/// greeting. A different one each time you open the app costs nothing and
/// makes the top of the screen worth looking at again.
///
/// ⚠️ **Once per launch, not once per build.** [_chosen] is a lazily
/// initialised top-level, so the first read picks and every read after
/// returns the same one for the life of the process. Picking inside `build`
/// would reshuffle it on every keystroke, scroll and rebuild — a greeting
/// that flickers, which is worse than one that never changes.
String get greetingFlower => _chosen;

/// What the greeting is allowed to be.
///
/// 🔴 **Its own list, not `FlowerCatalog`.** It used to pull a random emoji
/// from the send catalog, whose entries are *artwork* — "Bench in Bloom",
/// "Fox in the Tulips", "Highland Tulips" — labelled with whatever emoji is
/// nearest the picture. So the morning greeting could open with a 🪑, a 🦊 or
/// a 🐢, which reads as a glitch rather than a greeting. The catalog is right
/// to have those; a greeting is not the place for them.
///
/// Everything here has to belong to one of a few families and mean something
/// warm on its own, with no caption to explain it:
///
/// - **hearts**, which is what the app is
/// - **flowers and plants**, which is what it is named after
/// - **sky** — sun, moon, stars, a rainbow
/// - **scenery**, the kind you would want to be standing in together
/// - **warm faces**, and only warm ones
///
/// ⚠️ No animals, no objects, no food, nothing that needs a story. If a new
/// entry would make someone ask "why that?", it does not go in.
const greetingEmojis = <String>[
  // ── Hearts ────────────────────────────────────
  '💗', '💖', '💞', '💕', '💘', '❤️', '🩷', '💛', '💜',
  // ── Flowers & plants ──────────────────────────
  '🌷', '🌹', '🌸', '🌺', '🌼', '🌻', '💐', '🪷', '🪻', '🍀', '🌿', '🌱',
  // ── Sky ───────────────────────────────────────
  '☀️', '🌙', '⭐', '✨', '🌤️', '🌈', '🌞', '🌝',
  // ── Scenery ───────────────────────────────────
  '🌅', '🌄', '🏞️', '🏔️', '🌊',
  // ── Warm faces ────────────────────────────────
  '😊', '🥰', '😍', '☺️', '😌', '🤗',
];

final String _chosen = _pick();

String _pick() =>
    // Seeded from the clock rather than a fixed seed, so two launches a
    // second apart still differ.
    greetingEmojis[Random(DateTime.now().microsecondsSinceEpoch)
        .nextInt(greetingEmojis.length)];

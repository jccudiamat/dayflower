/**
 * Landing-page copy.
 *
 * ⚠️ **This file ships to the browser.** Everything `page.tsx` imports ends
 * up readable in the JS bundle, whether it is rendered or not — so trimming
 * what the page *displays* is not enough. Deliberately kept to the minimum a
 * waitlist page needs: no feature list, no screen names, no roadmap, and in
 * particular **no flower meanings**, which are the original writing and the
 * easiest thing for anyone else to lift. The full catalog lives in
 * `lib/features/tulip/domain/flower_catalog.dart` and stays in the app.
 *
 * Before adding anything here, ask what a competitor could build from it.
 */

/** Why someone should want in. Vibe only — no mechanics. */
export const lines = [
  {
    emoji: "🌷",
    title: "One flower a day",
    text: "Something small and deliberate, every morning.",
  },
  {
    emoji: "🔒",
    title: "Just the two of you",
    text: "No feed, no followers, nothing public. Ever.",
  },
  {
    emoji: "🎨",
    title: "Made by hand",
    text: "Original artwork, written slowly, for one relationship at a time.",
  },
];

/**
 * The word that cycles in the headline: "One ___ a day".
 *
 * ⚠️ These do name features, which cuts against the rest of this file — a
 * deliberate trade the user asked for on 2026-09-06, because a moving word is
 * a much better hook than a static one. They are kept to plain nouns anyone
 * would guess from "an app for two people"; no screen names, no mechanics,
 * nothing that says *how* any of it works.
 */
export const headlineWords = [
  "flower",
  "heartbeat",
  "photo",
  "note",
  "reminder",
  "call",
];

/**
 * The polaroid deck in the hero. Captions are written for the site — none of
 * them are catalog meanings, which stay in the app. Tilts match the app's own
 * stack in booth_screen.dart.
 */
export const polaroids = [
  {
    bloom: "fox_in_tulips",
    caption: "he sat there the whole time",
    date: "Apr 20",
    isNew: true,
    tilt: -2,
  },
  {
    bloom: "garden_path",
    caption: "walked this one thinking of you",
    date: "Apr 12",
    tilt: 4,
  },
  {
    bloom: "sunset_shore",
    caption: "the light was doing something",
    date: "Mar 30",
    tilt: -6,
  },
  {
    bloom: "classic_tulip",
    caption: "found these on the way home",
    date: "Mar 21",
    tilt: 3,
  },
];

export const stripBlooms = [
  "classic_tulip",
  "sunset_shore",
  "lavender_roses",
  "alpine_meadow",
  "misty_blossom",
  "garden_path",
];

/**
 * Where the Dayflower world is in its day, and what that looks like.
 *
 * One number, `phase`, runs 0 → 1 across dawn → night and every visual in the
 * scene reads from it. Keeping it here, as plain data with no three.js in
 * sight, means the palette can be reasoned about and tested without a GPU.
 */

export type Daylight = {
  readonly key: string;
  /** Position of this stop on the 0..1 day. */
  readonly at: number;
  readonly skyTop: string;
  readonly skyLow: string;
  readonly ground: string;
  readonly hills: string;
  /** Colour of the single directional light. */
  readonly sun: string;
  /** Ambient fill, which is what stops night from going black. */
  readonly fill: string;
  readonly sunIntensity: number;
  readonly fillIntensity: number;
  /** Height of the sun in the sky, -1 (below) to 1 (overhead). */
  readonly sunHeight: number;
  /** Fireflies out, flowers closing. */
  readonly nocturnal: number;
};

/**
 * ⚠️ Night is deliberately a deep blue-violet, never black, and its fill stays
 * high enough to keep foreground petals readable. Section 4 of the brief asks
 * for a night scene; a page nobody can read at 11pm is not worth the mood.
 */
export const STOPS: readonly Daylight[] = [
  { key: "dawn",    at: 0.00, skyTop: "#b9c6e8", skyLow: "#f7d9cf", ground: "#c9d3bd", hills: "#aebcc0", sun: "#ffd9bd", fill: "#c8cfe6", sunIntensity: 0.75, fillIntensity: 0.85, sunHeight: 0.08, nocturnal: 0.15 },
  { key: "morning", at: 0.22, skyTop: "#9fc3ea", skyLow: "#e8f0f6", ground: "#bcd0a6", hills: "#a9c0b4", sun: "#fff3dd", fill: "#dce8f5", sunIntensity: 1.05, fillIntensity: 0.9,  sunHeight: 0.42, nocturnal: 0 },
  { key: "midday",  at: 0.45, skyTop: "#86b6e8", skyLow: "#dfeefb", ground: "#b6cf9c", hills: "#9dbaad", sun: "#fffaf0", fill: "#e6f1fb", sunIntensity: 1.2,  fillIntensity: 0.95, sunHeight: 0.85, nocturnal: 0 },
  { key: "golden",  at: 0.68, skyTop: "#8fa7d4", skyLow: "#f7cfa6", ground: "#c2c294", hills: "#b2a9a6", sun: "#ffc98a", fill: "#dcd3e0", sunIntensity: 1.0,  fillIntensity: 0.8,  sunHeight: 0.18, nocturnal: 0.1 },
  { key: "dusk",    at: 0.83, skyTop: "#5d5f92", skyLow: "#e3a894", ground: "#8f8f88", hills: "#7d7a91", sun: "#ff9f78", fill: "#9a9cc0", sunIntensity: 0.6,  fillIntensity: 0.7,  sunHeight: -0.05, nocturnal: 0.55 },
  { key: "night",   at: 1.00, skyTop: "#232544", skyLow: "#43436d", ground: "#3f4a52", hills: "#33364f", sun: "#9fb0e8", fill: "#6f74a6", sunIntensity: 0.35, fillIntensity: 0.75, sunHeight: 0.35, nocturnal: 1 },
];

const hex = (c: string): [number, number, number] => [
  parseInt(c.slice(1, 3), 16),
  parseInt(c.slice(3, 5), 16),
  parseInt(c.slice(5, 7), 16),
];

const toHex = (v: number) => Math.round(v).toString(16).padStart(2, "0");

/** Mixes in plain sRGB. Good enough for adjacent stops, and cheap. */
export function mixColour(a: string, b: string, t: number): string {
  const [ar, ag, ab] = hex(a);
  const [br, bg, bb] = hex(b);
  return `#${toHex(ar + (br - ar) * t)}${toHex(ag + (bg - ag) * t)}${toHex(ab + (bb - ab) * t)}`;
}

const clamp01 = (n: number) => (n < 0 ? 0 : n > 1 ? 1 : n);
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

/** The light at any point in the day, interpolated between the two stops around it. */
export function daylightAt(phase: number): Daylight {
  const p = clamp01(phase);
  let i = 0;
  while (i < STOPS.length - 2 && STOPS[i + 1].at < p) i++;
  const a = STOPS[i];
  const b = STOPS[i + 1];
  const span = b.at - a.at;
  const t = span <= 0 ? 0 : clamp01((p - a.at) / span);

  return {
    key: t < 0.5 ? a.key : b.key,
    at: p,
    skyTop: mixColour(a.skyTop, b.skyTop, t),
    skyLow: mixColour(a.skyLow, b.skyLow, t),
    ground: mixColour(a.ground, b.ground, t),
    hills: mixColour(a.hills, b.hills, t),
    sun: mixColour(a.sun, b.sun, t),
    fill: mixColour(a.fill, b.fill, t),
    sunIntensity: lerp(a.sunIntensity, b.sunIntensity, t),
    fillIntensity: lerp(a.fillIntensity, b.fillIntensity, t),
    sunHeight: lerp(a.sunHeight, b.sunHeight, t),
    nocturnal: lerp(a.nocturnal, b.nocturnal, t),
  };
}

/**
 * Where the visitor's own clock puts them on that 0..1 day.
 *
 * ⚠️ Not a straight `hour / 24`. That would open the scene at pitch night for
 * anyone arriving after 9pm and dump a third of all visitors into the darkest
 * frame the site has. The waking hours are stretched across most of the range
 * and the small hours are compressed into the tail, so an evening visitor
 * lands at dusk rather than midnight.
 */
export function phaseForHour(hour: number): number {
  const h = ((hour % 24) + 24) % 24;
  if (h < 5) return 0.95;             // small hours: night, but not the very end
  if (h < 8) return lerp(0.00, 0.22, (h - 5) / 3);   // 05-08 dawn
  if (h < 12) return lerp(0.22, 0.45, (h - 8) / 4);  // 08-12 morning
  if (h < 16) return lerp(0.45, 0.68, (h - 12) / 4); // 12-16 afternoon
  if (h < 19) return lerp(0.68, 0.83, (h - 16) / 3); // 16-19 golden
  return lerp(0.83, 1.0, (h - 19) / 5);              // 19-24 dusk into night
}

/**
 * The day the visitor actually travels through.
 *
 * Section 4 wants the scene to match the visitor's local time; section 11 wants
 * scrolling to carry them toward night. Local time sets where the day opens and
 * the page bottom is always night, so the closing act is always under the night
 * sky the copy is written for.
 *
 * 🔴 It does NOT wrap. An earlier version let a late arrival run past night and
 * back around, which put an evening visitor at the foot of the page in bright
 * morning, directly under "A little closer. Even from here." The cost of not
 * wrapping is that someone arriving at 11pm travels barely at all, which is the
 * honest answer: their day really is nearly over.
 */
export function phaseFromScroll(startPhase: number, scrolled: number): number {
  return clamp01(startPhase) + clamp01(scrolled) * (1 - clamp01(startPhase));
}

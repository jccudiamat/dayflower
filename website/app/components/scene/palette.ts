/**
 * The Dayflower world, in two lights.
 *
 * ⚠️ One world, two palettes, and deliberately the same geometry underneath:
 * the visitor arrives at sunrise and leaves at night, and the closing scene
 * only reads as *later* rather than *elsewhere* because the mountains, the
 * lake and the town below it have not moved. Change a shape in `Scenery` and
 * it changes in both, which is the point.
 */
export type Time = "dawn" | "night";

export type Palette = {
  /** Sky, top of frame to horizon. */
  sky: [string, string, string, string, string];
  glow: string;
  orb: string;
  cloud: string;
  cloudWarm: string;
  far: [string, string];
  mid: [string, string];
  ridge: [string, string];
  water: [string, string];
  waterLight: string;
  roof: string;
  wall: string;
  window: string;
  conifer: string;
  hills: [[string, string], [string, string], [string, string]];
  stone: [string, string];
  grass: [string, string];
  leaf: string;
  leafDeep: string;
  petalWarm: string;
  petalPink: string;
  petalDeep: string;
  petalPale: string;
  heart: string;
  wood: [string, string];
  woodDark: string;
  ink: string;
};

export const PALETTE: Record<Time, Palette> = {
  dawn: {
    sky: ["#a4bbe8", "#c5c9ec", "#e9cbda", "#fbd0ab", "#ffe6bd"],
    glow: "#ffeab0",
    orb: "#fffdf5",
    cloud: "#ffffff",
    cloudWarm: "#f7d6dc",
    far: ["#a3aed2", "#ccd1e5"],
    mid: ["#7e8cb8", "#a8b1d1"],
    ridge: ["#71809e", "#98a3bd"],
    water: ["#d3ddf1", "#a9b9dd"],
    waterLight: "#ffe6bb",
    roof: "#bd7a66",
    wall: "#efdccd",
    window: "#ffc978",
    conifer: "#5c7767",
    hills: [
      ["#bccaa2", "#a2b987"],
      ["#93ad75", "#74915b"],
      ["#658450", "#48653a"],
    ],
    stone: ["#e8dbc6", "#cdb99b"],
    grass: ["#587b45", "#33502c"],
    leaf: "#628748",
    leafDeep: "#3d5d31",
    petalWarm: "#fdf6e6",
    petalPink: "#f3a3c0",
    petalDeep: "#e4749f",
    petalPale: "#fdfbf4",
    heart: "#e4749f",
    wood: ["#b18a61", "#8a6743"],
    woodDark: "#6d5236",
    ink: "#6b4a34",
  },
  night: {
    sky: ["#0d1730", "#14203f", "#1b2a4d", "#24355c", "#334667"],
    glow: "#9fb4dd",
    orb: "#f6f3e6",
    cloud: "#2c3d62",
    cloudWarm: "#31446b",
    far: ["#1b2643", "#2b3859"],
    mid: ["#16203c", "#232f4f"],
    ridge: ["#121b33", "#1d2743"],
    water: ["#273858", "#16233f"],
    waterLight: "#dbe4f7",
    roof: "#3a3450",
    wall: "#4a4360",
    window: "#ffca7d",
    conifer: "#13251f",
    hills: [
      ["#1c3327", "#16291f"],
      ["#152a1d", "#102117"],
      ["#0e1d14", "#0a160f"],
    ],
    stone: ["#4a4a52", "#35353d"],
    grass: ["#10231a", "#091610"],
    leaf: "#16301f",
    leafDeep: "#0a180f",
    petalWarm: "#efe7d4",
    petalPink: "#e9c2d4",
    petalDeep: "#c78aa8",
    petalPale: "#f4efe2",
    heart: "#f0a7c4",
    wood: ["#5f4e3f", "#41352b"],
    woodDark: "#241d17",
    ink: "#efe7d4",
  },
};

/**
 * A fixed sequence, never `Math.random`.
 *
 * 🔴 The scatter runs on the server too. A random meadow would send one field
 * of flowers in the HTML and draw a different one on hydration, which React
 * reports as a mismatch and the visitor sees as a flicker.
 */
export function seeded(seed: number) {
  let s = seed;
  return () => ((s = (s * 1664525 + 1013904223) % 4294967296) / 4294967296);
}

export const flowers = [
  { name: "Tulip", detail: "A little love", color: "#e89cb4" },
  { name: "Rose", detail: "Always you", color: "#a54765" },
  { name: "Daisy", detail: "Just because", color: "#dfbe63" },
  { name: "Sunflower", detail: "You are sunshine", color: "#dfa63d" },
  { name: "Lavender", detail: "A moment of calm", color: "#9f88c5" },
  { name: "Peony", detail: "Something lovely", color: "#d994b1" },

  // Indexes 6+ come from flowers-a|b|c|d.webp, 12 to a sheet in this exact
  // order — `flowerSprite` maps index → sheet by arithmetic, so a sheet is all
  // or nothing. **Never reorder or remove:** gift links store the index, and a
  // shuffle here rewrites every bouquet anyone has already sent.
  { name: "Lily", detail: "Pure and true", color: "#e8e2d6" },
  { name: "Orchid", detail: "Rare, like you", color: "#c473c0" },
  { name: "Hydrangea", detail: "A whole armful", color: "#e58ab0" },
  { name: "Gerbera", detail: "Instant cheer", color: "#e87a2a" },
  { name: "Carnation", detail: "Sweet and steady", color: "#e5697c" },
  { name: "Poppy", detail: "A bright hello", color: "#d9382a" },
  { name: "Anemone", detail: "Soft and brave", color: "#7b6fd0" },
  { name: "Ranunculus", detail: "Layers of lovely", color: "#e8902a" },
  { name: "Dahlia", detail: "Bold and kind", color: "#d63a86" },
  { name: "Iris", detail: "Good news soon", color: "#3f5fd0" },
  { name: "Calla lily", detail: "Simply elegant", color: "#eee9dc" },
  { name: "Camellia", detail: "My admiration", color: "#e8769f" },
  { name: "Daffodil", detail: "New beginnings", color: "#e8c02a" },
  { name: "Gardenia", detail: "A secret joy", color: "#eee8dc" },
  { name: "Magnolia", detail: "Gentle strength", color: "#e195b4" },
  { name: "Jasmine", detail: "Sweet on you", color: "#eae6d8" },
  { name: "Sweet pea", detail: "Thank you for today", color: "#e6e0d4" },
  { name: "Delphinium", detail: "Reaching for you", color: "#4a63c4" },
  { name: "Snapdragon", detail: "Playful and strong", color: "#e892a8" },
  { name: "Cornflower", detail: "A small blue wish", color: "#4a6ad0" },
  { name: "Cosmos", detail: "Peace and quiet", color: "#e9e4da" },
  { name: "Zinnia", detail: "Thinking of you", color: "#e0588e" },
  { name: "Marigold", detail: "Warm as the sun", color: "#e8801f" },
  { name: "Aster", detail: "Patient love", color: "#9a7ad0" },
  { name: "Chrysanthemum", detail: "Long life and joy", color: "#ece8dc" },
  { name: "Lisianthus", detail: "Quietly devoted", color: "#e284a6" },
  { name: "Freesia", detail: "Trust and friendship", color: "#e88fae" },
  { name: "Alstroemeria", detail: "Our little bond", color: "#d63c34" },
  { name: "Scabiosa", detail: "I remember", color: "#7f8fd0" },
  { name: "Stock", detail: "A lasting bond", color: "#a87ad0" },
  { name: "Amaryllis", detail: "Proud of you", color: "#d02f2f" },
  { name: "Hyacinth", detail: "Play and springtime", color: "#5a76d4" },
  { name: "Muscari", detail: "Small and certain", color: "#6a80d0" },
  { name: "Allium", detail: "Wonderfully odd", color: "#a86ad0" },
  { name: "Hellebore", detail: "Steady in winter", color: "#a8c07a" },
  { name: "Lily of the valley", detail: "Happiness returns", color: "#ebe7db" },
  { name: "Forget-me-not", detail: "Don’t forget me", color: "#6a92d8" },
  { name: "Baby’s breath", detail: "Everlasting", color: "#ece9df" },
  { name: "Protea", detail: "Brave and rare", color: "#d6607e" },
  { name: "Bird of paradise", detail: "Somewhere far", color: "#e8801f" },
  { name: "Anthurium", detail: "Open-hearted", color: "#e0778c" },
  { name: "Lotus", detail: "A calm start", color: "#e38fb0" },
  { name: "Craspedia", detail: "A pocket of sun", color: "#e8c62a" },
  { name: "Snowdrop", detail: "Hope, early", color: "#ebe8de" },
  { name: "Crocus", detail: "First of spring", color: "#9a72c8" },
  { name: "Agapanthus", detail: "Love letters", color: "#5f7ace" },
  { name: "Bleeding heart", detail: "All my heart", color: "#e0708f" },
  { name: "Mimosa", detail: "A soft surprise", color: "#e8c73a" },
] as const;

export const papers = [
  { name: "Rose & ivory", background: "#f7edf0", ink: "#703e54", sprite: 6 },
  { name: "Lilac love", background: "#eee9f7", ink: "#65507c", sprite: 7 },
  { name: "Just the stems", background: "#edf2ec", ink: "#4b6554", sprite: -1 },
  { name: "Midnight", background: "#f0edf2", ink: "#4c4357", sprite: 7 },
  { name: "Blush", background: "#f9ecee", ink: "#7f465a", sprite: 6 },
] as const;

export type Stem = { id: number; flower: number; x: number; y: number; angle: number; scale: number; z?: number };
export const photoFrames = ["Polaroid", "Sticker", "Cutout", "Heart", "Circle", "Arch", "Postage stamp"] as const;
export type Photo = { id: number; src: string; frame: number; x: number; y: number; angle: number; scale: number; zoom: number; cropX: number; cropY: number; caption: string; layer: "back" | "front"; z?: number };
export type Bouquet = { v: 1; stems: Stem[]; paper: number; to: string; from: string; message: string; photos?: Photo[]; vessel?: number; print?: number; printOpacity?: number; wrapScale?: number; wrapAngle?: number; stemFlower?: number };

/** The wrapper turns and grows about its tie, not its middle, so it leans the way a held bouquet does. */
export const WRAP_PIVOT = { x: 360, y: 690 };

/**
 * The highest a bloom may reach before the card starts cutting it.
 *
 * ⚠️ Must stay **below both** the card clip and the taper, which are the two
 * things that actually cut. They were 100 and 112 while this was 108, so the
 * fit aimed at a height the taper then shaved. All three move together. Stems are allowed as high as y=490 at scale 1.15, which puts a
 * bloom tip well off the top of the card — raising the header cannot buy back
 * anything like enough room, so the arrangement is scaled instead.
 */
export const FIT_CEILING = 112;

/**
 * How much the whole arrangement has to shrink so nothing is clipped.
 *
 * Render-time only: it never touches stored values, so a gift made before
 * this simply stops being cut rather than being rewritten. Scaled about the
 * tie, so a too-tall bouquet settles toward its own wrapping instead of
 * drifting off-centre.
 *
 * ⚠️ `point()` in the editor applies the inverse, or dragging would be offset
 * from the art by exactly this factor.
 */
export function fitScale(bouquet: Bouquet) {
  let top = Infinity;
  const raise = (x: number, y: number, lx: number, ly: number, angle: number) =>
    { top = Math.min(top, y + lx * Math.sin(angle) + ly * Math.cos(angle)); };
  for (const stem of bouquet.stems) {
    const { w, h, angle } = stemGeometry(stem);
    // The art fills a w × h box hanging from (-w/2, -h*.94) in the stem's own
    // frame; tilted, either upper corner can be the highest point.
    raise(stem.x, stem.y, -w / 2, -h * .94, angle);
    raise(stem.x, stem.y, w / 2, -h * .94, angle);
  }
  for (const photo of bouquet.photos ?? []) {
    const { w, h, angle } = photoGeometry(photo);
    raise(photo.x, photo.y, -w / 2, -h / 2, angle);
    raise(photo.x, photo.y, w / 2, -h / 2, angle);
  }
  if (!Number.isFinite(top) || top >= FIT_CEILING) return 1;
  return (WRAP_PIVOT.y - FIT_CEILING) / (WRAP_PIVOT.y - top);
}

/**
 * One stack for flowers and photos together, so either can be moved forward or
 * back past the other.
 *
 * **Everything in this list draws between the wrapper's back and front halves**
 * — reordering can shuffle the contents, but nothing can climb out of the
 * paper or sink behind it. That is a property of where the loop sits in
 * renderBouquet, not a rule enforced here.
 *
 * Old links carry no `z`. The fallbacks reproduce exactly the order that used
 * to be hardcoded — photos marked "back", then stems in array order, then
 * photos marked "front" — so a bouquet sent before this feature renders
 * unchanged. `layer` is kept for those links and is no longer consulted once
 * an item has a real `z`.
 */
const STEM_BAND = 1000;
export type Layered = { kind: "stem"; z: number; stem: Stem } | { kind: "photo"; z: number; photo: Photo };
export function layeredItems(bouquet: Bouquet): Layered[] {
  const photos = bouquet.photos ?? [];
  return [
    ...photos.map((photo, i) => ({ kind: "photo" as const, photo, z: photo.z ?? (photo.layer === "back" ? i : STEM_BAND * 2 + i) })),
    ...bouquet.stems.map((stem, i) => ({ kind: "stem" as const, stem, z: stem.z ?? (STEM_BAND + i) })),
  ].sort((a, b) => a.z - b.z);
}
export function layerKey(item: Layered) { return item.kind === "stem" ? `stem:${item.stem.id}` : `photo:${item.photo.id}`; }

/** One step forward or back in the shared stack, renumbered 0..n-1 afterwards. */
export function reorder(bouquet: Bouquet, kind: "stem" | "photo", id: number, delta: 1 | -1): Bouquet {
  const list = layeredItems(bouquet);
  const from = list.findIndex(item => layerKey(item) === `${kind}:${id}`);
  const to = from + delta;
  if (from < 0 || to < 0 || to >= list.length) return bouquet;
  [list[from], list[to]] = [list[to], list[from]];
  const depth = new Map(list.map((item, i) => [layerKey(item), i]));
  const photos = (bouquet.photos ?? []).map(photo => ({ ...photo, z: depth.get(`photo:${photo.id}`) ?? photo.z }));
  return {
    ...bouquet,
    stems: bouquet.stems.map(stem => ({ ...stem, z: depth.get(`stem:${stem.id}`) ?? stem.z })),
    ...(photos.length ? { photos } : {}),
  };
}
/** Depth for something just added, so it lands on top of everything already there. */
export function topZ(bouquet: Bouquet) {
  const list = layeredItems(bouquet);
  return list.length ? list[list.length - 1].z + 1 : 0;
}

/**
 * How the bouquet arrives. The vessel is what the recipient sees *before*
 * anything opens — the preview card in a chat, the image in an email, the
 * bubble in the app — so it is deliberately separate from the paper the
 * flowers are wrapped in.
 *
 * Drawn in code for now (see renderVessel). Swapping in a sprite sheet later
 * means changing only that function; the ids and order below are stored in
 * gift links, so **never reorder them**.
 */
export const vessels = [
  { name: "Paper envelope", blurb: "Classic. A flap and a little wax seal." },
  { name: "Postcard", blurb: "A stamp, a postmark, a short hello." },
  { name: "Love letter", blurb: "Folded in three, sealed with a heart." },
  { name: "Carrier pigeon", blurb: "Takes the long way. Always arrives." },
  { name: "Single stem", blurb: "Just one flower. Swipe to choose it." },
  { name: "Gift box", blurb: "Lid, ribbon, and a moment before it lifts." },
] as const;

/** Stationery printed under everything. Borders frame the page; patterns tile it. */
export const prints = [
  { name: "Plain", kind: "none" },
  { name: "Hearts", kind: "pattern" },
  { name: "Little stars", kind: "pattern" },
  { name: "Bows", kind: "pattern" },
  { name: "Sprigs", kind: "pattern" },
  { name: "Gingham", kind: "pattern" },
  { name: "Vines", kind: "border" },
  { name: "Petals", kind: "border" },
  { name: "Scalloped", kind: "border" },
] as const;

export const DEFAULT_PRINT_OPACITY = 30;
export const VESSEL_W = 520;
export const VESSEL_H = 380;
export const MAX_STEMS = 24;
export const MAX_PHOTOS = 8;
export const MAX_PHOTO_LENGTH = 180_000;
export const ART_URL = "/bouquet/botanical-sprites.webp";
export const WRAPPER_URL = "/bouquet/wrapper-layers.webp";
export const EXTRA_ART_URLS = ["a", "b", "c", "d"].map(id => `/bouquet/flowers-${id}.webp`);
export function flowerSprite(index: number) {
  return index < 6 ? { url: ART_URL, index, rows: 2 } : { url: EXTRA_ART_URLS[Math.floor((index - 6) / 12)], index: (index - 6) % 12, rows: 3 };
}
export function photoCount(b: Bouquet) { return b.photos?.length ?? 0; }
/**
 * The bloom the Single stem vessel shows. Picked on its own, because the
 * vessel is what arrives first and deserves its own choice — but it falls
 * back to the bouquet's first flower so it is never empty or arbitrary.
 */
export function singleStem(b: Bouquet) {
  const chosen = b.stemFlower;
  if (Number.isInteger(chosen) && chosen! >= 0 && chosen! < flowers.length) return chosen!;
  return b.stems[0]?.flower ?? 0;
}
export function hasContents(b: Bouquet) { return b.stems.length > 0 || photoCount(b) > 0; }
export const WIDTH = 720;
export const HEIGHT = 960;

const arrangements = [ [4, 0, 5, 2, 0, 5, 2], [4, 1, 5, 1, 0, 5, 1], [4, 3, 2, 3, 2, 0, 2] ];
export function arrange(types: readonly number[]): Stem[] {
  return types.map((flower, i) => ({ id: i + 1, flower, x: 360 + (i % 3 - 1) * 15, y: 644 + (i % 2) * 24,
    angle: types.length === 1 ? 0 : -31 + i * 62 / (types.length - 1), scale: 1 - (i % 3) * .06 }));
}
export function makeBouquet(preset = 0): Bouquet {
  return { v: 1, stems: arrange(arrangements[preset] ?? arrangements[0]), paper: preset === 1 ? 1 : 0, to: "", from: "", message: "A little reminder that you make my world a lovelier place." };
}

function finiteIn(value: unknown, min: number, max: number): value is number {
  return typeof value === "number" && Number.isFinite(value) && value >= min && value <= max;
}
export function validateBouquet(value: unknown): Bouquet | null {
  if (!value || typeof value !== "object") return null;
  const b = value as Record<string, unknown>;
  if (b.v !== 1 || !Number.isInteger(b.paper) || !finiteIn(b.paper, 0, papers.length - 1) ||
      typeof b.to !== "string" || b.to.length > 40 || typeof b.from !== "string" || b.from.length > 40 ||
      typeof b.message !== "string" || b.message.length > 280 || !Array.isArray(b.stems) || b.stems.length > MAX_STEMS) return null;
  const stems: Stem[] = [];
  for (const item of b.stems) {
    if (!item || typeof item !== "object") return null;
    const s = item as Record<string, unknown>;
    if (!Number.isInteger(s.flower) || !finiteIn(s.flower, 0, flowers.length - 1) || !finiteIn(s.x, 220, 500) ||
        !finiteIn(s.y, 490, 690) || !finiteIn(s.angle, -45, 45) || !finiteIn(s.scale, .7, 1.15)) return null;
    const z = Number.isInteger(s.z) && finiteIn(s.z, 0, 9999) ? s.z as number : undefined;
    stems.push({ id: stems.length + 1, flower: s.flower, x: s.x, y: s.y, angle: s.angle, scale: s.scale, ...(z !== undefined ? { z } : {}) });
  }
  const photos: Photo[] = [];
  if (b.photos !== undefined) {
    if (!Array.isArray(b.photos) || b.photos.length > MAX_PHOTOS) return null;
    let total = 0;
    for (const item of b.photos) {
      if (!item || typeof item !== "object") return null;
      const p = item as Record<string, unknown>;
      if (typeof p.src !== "string" || p.src.length > MAX_PHOTO_LENGTH || !/^data:image\/(?:jpeg|png|webp);base64,[A-Za-z0-9+/]+={0,2}$/.test(p.src) ||
          !Number.isInteger(p.frame) || !finiteIn(p.frame, 0, photoFrames.length - 1) || !finiteIn(p.x, 110, 610) || !finiteIn(p.y, 190, 570) ||
          !finiteIn(p.angle, -45, 45) || !finiteIn(p.scale, .55, 1.5) || !finiteIn(p.zoom, 1, 3) || !finiteIn(p.cropX, 0, 100) || !finiteIn(p.cropY, 0, 100) ||
          typeof p.caption !== "string" || p.caption.length > 35 || (p.layer !== "back" && p.layer !== "front")) return null;
      total += p.src.length;
      // Must match what the editor can actually produce, or a full bouquet is
      // rejected on reload and the saved draft vanishes without a word.
      if (total > MAX_PHOTOS * MAX_PHOTO_LENGTH) return null;
      const pz = Number.isInteger(p.z) && finiteIn(p.z, 0, 9999) ? p.z as number : undefined;
      photos.push({ id: photos.length + 1, src: p.src, frame: p.frame, x: p.x, y: p.y, angle: p.angle, scale: p.scale, zoom: p.zoom, cropX: p.cropX, cropY: p.cropY, caption: p.caption, layer: p.layer, ...(pz !== undefined ? { z: pz } : {}) });
    }
  }
  // ⚠️ These three are **defaulted, not rejected**, unlike everything above.
  // Gift links sent before they existed carry none of them, and a link someone
  // already posted must never stop opening because the editor grew a feature.
  // Out-of-range values fall back for the same reason.
  const vessel = Number.isInteger(b.vessel) && finiteIn(b.vessel, 0, vessels.length - 1) ? b.vessel as number : 0;
  const print = Number.isInteger(b.print) && finiteIn(b.print, 0, prints.length - 1) ? b.print as number : 0;
  const printOpacity = finiteIn(b.printOpacity, 0, 100) ? Math.round(b.printOpacity as number) : DEFAULT_PRINT_OPACITY;
  const wrapScale = finiteIn(b.wrapScale, .75, 1.3) ? b.wrapScale as number : 1;
  const wrapAngle = finiteIn(b.wrapAngle, -20, 20) ? b.wrapAngle as number : 0;
  const stemFlower = Number.isInteger(b.stemFlower) && finiteIn(b.stemFlower, 0, flowers.length - 1) ? b.stemFlower as number : undefined;
  return {
    v: 1, stems, paper: b.paper, to: b.to, from: b.from, message: b.message,
    ...(photos.length ? { photos } : {}),
    // Defaults are left out so a plain bouquet's link stays as short as it was.
    ...(vessel ? { vessel } : {}), ...(print ? { print } : {}),
    ...(print && printOpacity !== DEFAULT_PRINT_OPACITY ? { printOpacity } : {}),
    ...(wrapScale !== 1 ? { wrapScale } : {}), ...(wrapAngle !== 0 ? { wrapAngle } : {}),
    ...(stemFlower !== undefined ? { stemFlower } : {}),
  };
}

// The gift travels in the URL fragment. No account, database row, or note upload is needed.
// This is an encoded gift, not encryption: anyone with the complete link can open it.
export function encodeBouquet(bouquet: Bouquet): string {
  const clean = validateBouquet(bouquet);
  if (!clean || !hasContents(clean)) throw new Error("Add at least one flower or photo before sharing.");
  // Only the private link comes through here now. A data URL will not fit in
  // a URL fragment, so this stays — but the message has to name the link that
  // actually refused, not imply photos cannot be shared at all.
  if (photoCount(clean)) throw new Error("A private link can’t carry photos. Use the gift link instead, or remove the photos.");
  const bytes = new TextEncoder().encode(JSON.stringify(clean));
  return btoa(Array.from(bytes, b => String.fromCharCode(b)).join("")).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}
export function decodeBouquet(encoded: string): Bouquet | null {
  if (!encoded || encoded.length > 9000 || !/^[\w-]+$/.test(encoded)) return null;
  try {
    const base64 = encoded.replaceAll("-", "+").replaceAll("_", "/");
    const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
    const result = validateBouquet(JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)));
    return result && hasContents(result) && !photoCount(result) ? result : null;
  } catch { return null; }
}

export function spriteRect(index: number, imageWidth: number, imageHeight: number, rows = 2) {
  return { x: index % 4 * imageWidth / 4, y: Math.floor(index / 4) * imageHeight / rows, w: imageWidth / 4, h: imageHeight / rows };
}
export function stemGeometry(stem: Stem) {
  const h = 470 * stem.scale;
  return { w: h * .75, h, angle: stem.angle * Math.PI / 180 };
}
/** Centre of the bloom end, which is what the selection ring circles. */
export function bloomPoint(stem: Stem) {
  const { h, angle } = stemGeometry(stem);
  return { x: stem.x + Math.sin(angle) * h * .70, y: stem.y - Math.cos(angle) * h * .70, r: h * .19 };
}
/**
 * The tilt grip, set *beside* the bloom rather than beyond it. Past the tip
 * would read more naturally, but a tall stem puts the bloom near the top of
 * the card and anything further up lands outside the clip — an invisible
 * handle. Perpendicular keeps it in the same band as the flower it turns.
 */
export function stemHandle(stem: Stem) {
  const bloom = bloomPoint(stem), { angle } = stemGeometry(stem);
  return { x: bloom.x + Math.cos(angle) * (bloom.r + 22), y: bloom.y + Math.sin(angle) * (bloom.r + 22), r: 19 };
}
/** The size grip, mirrored across the bloom from the tilt one so the two never overlap. */
export function stemScaleHandle(stem: Stem) {
  const bloom = bloomPoint(stem), { angle } = stemGeometry(stem);
  return { x: bloom.x - Math.cos(angle) * (bloom.r + 22), y: bloom.y - Math.sin(angle) * (bloom.r + 22), r: 19 };
}

/** A photo's grips ride its own corners, so they turn and grow with it. */
function photoCorner(photo: Photo, sx: number, sy: number) {
  const { w, h, angle } = photoGeometry(photo);
  const lx = sx * (w / 2 + 13), ly = sy * (h / 2 + 13);
  return { x: photo.x + lx * Math.cos(angle) - ly * Math.sin(angle), y: photo.y + lx * Math.sin(angle) + ly * Math.cos(angle), r: 19 };
}
export const photoTiltHandle = (photo: Photo) => photoCorner(photo, 1, -1);
export const photoScaleHandle = (photo: Photo) => photoCorner(photo, 1, 1);
/** Degrees that would point a photo's top edge away from (x, y). */
export function photoAngleToward(photo: Photo, x: number, y: number) {
  return Math.atan2(x - photo.x, -(y - photo.y)) * 180 / Math.PI;
}

/** Degrees that would point the stem from its base toward (x, y). */
export function angleToward(stem: Stem, x: number, y: number) {
  return Math.atan2(x - stem.x, -(y - stem.y)) * 180 / Math.PI;
}

export function hitStem(stems: Stem[], x: number, y: number): Stem | undefined {
  // Pick the bloom end, so overlapping transparent stem rectangles don't swallow clicks.
  return [...stems].reverse().find(stem => {
    const { h, angle } = stemGeometry(stem);
    const cx = stem.x + Math.sin(angle) * h * .70;
    const cy = stem.y - Math.cos(angle) * h * .70;
    return Math.hypot(x - cx, y - cy) < h * .22;
  });
}

function wrappedLines(ctx: CanvasRenderingContext2D, text: string, width: number): string[] {
  const lines: string[] = [];
  for (const paragraph of text.replace(/\s+/g, " ").trim().split("\n")) {
    let line = "";
    // Break at characters as well as spaces: long words and CJK must fit too.
    for (const word of paragraph.split(/(\s+)/)) {
      if (ctx.measureText(line + word).width <= width) { line += word; continue; }
      if (line.trim()) { lines.push(line.trimEnd()); line = ""; }
      for (const character of word.trimStart()) {
        if (ctx.measureText(line + character).width > width && line) { lines.push(line); line = ""; }
        line += character;
      }
    }
    lines.push(line.trimEnd());
  }
  return lines;
}

export function photoGeometry(photo: Photo) {
  return { w: 184 * photo.scale, h: (photo.frame === 0 ? 222 : 184) * photo.scale, angle: photo.angle * Math.PI / 180 };
}
export function hitPhoto(photos: Photo[], x: number, y: number): Photo | undefined {
  return [...photos].reverse().find(photo => {
    const { w, h, angle } = photoGeometry(photo), dx = x - photo.x, dy = y - photo.y;
    return Math.abs(dx * Math.cos(angle) + dy * Math.sin(angle)) <= w / 2 && Math.abs(-dx * Math.sin(angle) + dy * Math.cos(angle)) <= h / 2;
  });
}
function framePath(ctx: CanvasRenderingContext2D, frame: number, x: number, y: number, w: number, h: number) {
  ctx.beginPath();
  if (frame === 3) {
    ctx.moveTo(x + w / 2, y + h);
    ctx.bezierCurveTo(x - w * .45, y + h * .3, x + w * .1, y - h * .3, x + w / 2, y + h * .2);
    ctx.bezierCurveTo(x + w * .9, y - h * .3, x + w * 1.45, y + h * .3, x + w / 2, y + h);
    ctx.closePath();
  } else if (frame === 4) ctx.ellipse(x + w / 2, y + h / 2, w / 2, h / 2, 0, 0, Math.PI * 2);
  else if (frame === 5) { ctx.moveTo(x, y + h); ctx.lineTo(x, y + w / 2); ctx.arc(x + w / 2, y + w / 2, w / 2, Math.PI, 0); ctx.lineTo(x + w, y + h); ctx.closePath(); }
  else ctx.roundRect(x, y, w, h, frame === 1 ? 18 : 2);
}
function drawPhoto(ctx: CanvasRenderingContext2D, photo: Photo, image: HTMLImageElement, selected: boolean) {
  ctx.save(); ctx.translate(photo.x, photo.y); ctx.rotate(photo.angle * Math.PI / 180); ctx.scale(photo.scale, photo.scale);
  const w = 184, h = photo.frame === 0 ? 222 : 184, inset = photo.frame === 6 ? 13 : 10;
  const iw = w - inset * 2, ih = photo.frame === 0 ? 164 : h - inset * 2;
  if (photo.frame !== 2) {
    ctx.shadowColor = "#25152d30"; ctx.shadowBlur = 9; ctx.shadowOffsetY = 4;
    framePath(ctx, photo.frame, -w / 2, -h / 2, w, h); ctx.fillStyle = "#fffdf8"; ctx.fill();
    ctx.shadowColor = "transparent"; ctx.shadowBlur = 0; ctx.shadowOffsetY = 0;
  }
  ctx.save();
  if (photo.frame !== 2) { framePath(ctx, photo.frame, -w / 2 + inset, -h / 2 + inset, iw, ih); ctx.clip(); }
  const imageW = image.naturalWidth, imageH = image.naturalHeight;
  const fit = (photo.frame === 2 ? Math.min(iw / imageW, ih / imageH) : Math.max(iw / imageW, ih / imageH)) * photo.zoom;
  const dw = imageW * fit, dh = imageH * fit;
  const dx = -w / 2 + inset - (dw - iw) * photo.cropX / 100, dy = -h / 2 + inset - (dh - ih) * photo.cropY / 100;
  // Cutout photos preserve alpha, including transparent PNGs and the local background-removal result.
  if (photo.frame === 2) { ctx.shadowColor = "#fff"; ctx.shadowBlur = 8; }
  ctx.drawImage(image, dx, dy, dw, dh); ctx.restore();
  if (photo.frame === 0) { ctx.fillStyle = "#705268"; ctx.font = "italic 13px Georgia, serif"; ctx.textAlign = "center"; ctx.fillText(photo.caption || "a moment to keep", 0, h / 2 - 16, w - 20); }
  if (photo.frame === 6) {
    ctx.strokeStyle = "#ba9eac"; ctx.lineWidth = 2; ctx.setLineDash([1, 7]); ctx.strokeRect(-w / 2 + 5, -h / 2 + 5, w - 10, h - 10); ctx.setLineDash([]);
  }
  if (selected) { ctx.strokeStyle = "#754766"; ctx.lineWidth = 2; ctx.setLineDash([5, 5]); ctx.strokeRect(-w / 2 - 5, -h / 2 - 5, w + 10, h + 10); }
  ctx.restore();
  // Outside the photo's own transform: the grips keep a constant size however
  // far the photo has been scaled, the way a handle should.
  if (selected) {
    const tilt = photoTiltHandle(photo), size = photoScaleHandle(photo);
    drawGrip(ctx, tilt.x, tilt.y, "tilt", "#754766");
    drawGrip(ctx, size.x, size.y, "size", "#754766");
  }
}

export type RenderAssets = Record<string, HTMLImageElement>;

function drawGrip(ctx: CanvasRenderingContext2D, x: number, y: number, kind: "tilt" | "size", ink: string) {
  ctx.save();
  ctx.setLineDash([]);
  ctx.fillStyle = ink;
  ctx.beginPath(); ctx.arc(x, y, 13, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = "#fffdf8"; ctx.lineWidth = 2.2; ctx.lineCap = "round";
  if (kind === "tilt") {
    ctx.beginPath(); ctx.arc(x, y, 6.4, Math.PI * .35, Math.PI * 1.65); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(x + 1.2, y - 8.4); ctx.lineTo(x + 6.4, y - 5.6); ctx.lineTo(x + 1.2, y - 2.4); ctx.closePath();
    ctx.fillStyle = "#fffdf8"; ctx.fill();
  } else {
    // A diagonal double arrow: the universal "drag me bigger".
    ctx.beginPath(); ctx.moveTo(x - 5, y + 5); ctx.lineTo(x + 5, y - 5); ctx.stroke();
    ctx.fillStyle = "#fffdf8";
    for (const [dx, dy] of [[1, -1], [-1, 1]] as const) {
      ctx.beginPath();
      ctx.moveTo(x + dx * 7.5, y + dy * 7.5);
      ctx.lineTo(x + dx * 7.5 - dx * 6.5, y + dy * 7.5);
      ctx.lineTo(x + dx * 7.5, y + dy * 7.5 - dy * 6.5);
      ctx.closePath(); ctx.fill();
    }
  }
  ctx.restore();
}
export function renderBouquet(canvas: HTMLCanvasElement, bouquet: Bouquet, art: HTMLImageElement, selected?: number, assets: RenderAssets = {}, selectedPhoto?: number) {
  canvas.width = WIDTH;
  canvas.height = HEIGHT;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Your browser could not create the bouquet image.");
  const paper = papers[bouquet.paper];
  ctx.fillStyle = paper.background;
  ctx.fillRect(0, 0, WIDTH, HEIGHT);
  // Stationery sits under everything, including the title, so a border frames
  // the whole card the way a printed sheet would.
  drawPrint(ctx, bouquet.print ?? 0, bouquet.printOpacity ?? DEFAULT_PRINT_OPACITY, paper.ink);
  ctx.textAlign = "center";
  ctx.fillStyle = paper.ink;
  ctx.font = '16px sans-serif';
  ctx.fillText("A LITTLE SOMETHING, JUST FOR YOU", WIDTH / 2, 42);
  ctx.font = 'italic 32px Georgia, serif';
  ctx.fillText(bouquet.to.trim() ? `For ${bouquet.to.trim()}` : "You deserve flowers.", WIDTH / 2, 86, 620);
  ctx.save();
  ctx.beginPath(); ctx.rect(12, 100, WIDTH - 24, 627); ctx.clip();
  const wrapper = assets[WRAPPER_URL];
  const wrapIndex = bouquet.paper === 0 ? 0 : bouquet.paper === 1 ? 2 : bouquet.paper === 3 ? 4 : 6;
  // Both halves of the paper and the taper below share one transform, or the
  // front would slide off the back the moment the wrapper is turned.
  const wrapTransform = () => {
    ctx.translate(WRAP_PIVOT.x, WRAP_PIVOT.y);
    ctx.rotate((bouquet.wrapAngle ?? 0) * Math.PI / 180);
    ctx.scale(bouquet.wrapScale ?? 1, bouquet.wrapScale ?? 1);
    ctx.translate(-WRAP_PIVOT.x, -WRAP_PIVOT.y);
  };
  const drawWrapper = (front: boolean) => {
    if (!wrapper || paper.sprite < 0 || !hasContents(bouquet)) return;
    const crop = spriteRect(wrapIndex + (front ? 1 : 0), wrapper.naturalWidth, wrapper.naturalHeight);
    ctx.save(); wrapTransform();
    ctx.drawImage(wrapper, crop.x, crop.y, crop.w, crop.h, 104, 130, 512, 600);
    ctx.restore();
  };
  // Everything from here to the matching restore is the bouquet itself, and
  // it all has to scale together — wrapper, taper, flowers, photos, grips —
  // or the paper and what is in it drift apart.
  const fit = fitScale(bouquet);
  ctx.save();
  if (fit < 1) {
    ctx.translate(WRAP_PIVOT.x, WRAP_PIVOT.y);
    ctx.scale(fit, fit);
    ctx.translate(-WRAP_PIVOT.x, -WRAP_PIVOT.y);
  }
  drawWrapper(false);
  ctx.save();
  if (paper.sprite >= 0 && wrapper) {
    // The opening stays broad; below it the foliage tapers into the tied paper.
    // This prevents leaves and stem ends from sticking through the wrapper's sides.
    //
    // The path is laid down under the wrapper's transform so it follows the
    // paper, then the transform is undone before clipping — the current path
    // is not part of the state save/restore touches, so it survives with its
    // points already resolved, and the flowers that follow draw untransformed.
    // 🔴 The *sides* of the taper must follow the wrapper — that is the whole
    // point of drawing it under the same transform. Its **opening must not**.
    // A fixed top edge gets dragged down with the paper: at wrapScale .81 it
    // fell from y=100 to y=212 and started eating blooms that shrink-to-fit
    // had already made room for, which is invisible until someone resizes
    // their wrapper. So the mouth is placed wherever it must sit *before* the
    // transform in order to land off the card *after* it — the card's own
    // rect clip is what bounds the top, and it does not move.
    const k = bouquet.wrapScale ?? 1;
    const pre = (target: number, axis: "x" | "y") => WRAP_PIVOT[axis] + (target - WRAP_PIVOT[axis]) / k;
    const mouthY = pre(-400, "y"), mouthL = pre(-400, "x"), mouthR = pre(WIDTH + 400, "x");
    ctx.save(); wrapTransform();
    ctx.beginPath(); ctx.moveTo(mouthL, mouthY); ctx.lineTo(mouthR, mouthY); ctx.lineTo(656, 390);
    ctx.lineTo(500, 530); ctx.lineTo(402, 658); ctx.lineTo(318, 658); ctx.lineTo(220, 530); ctx.lineTo(64, 390); ctx.closePath();
    ctx.restore();
    ctx.clip();
  }
  // One pass, flowers and photos interleaved by depth. Because this whole loop
  // sits between drawWrapper(false) and drawWrapper(true), no amount of
  // reordering can put anything in front of the paper or behind it.
  for (const item of layeredItems(bouquet)) {
    if (item.kind === "photo") {
      const image = assets[item.photo.src];
      if (image) drawPhoto(ctx, item.photo, image, selectedPhoto === item.photo.id);
      continue;
    }
    const stem = item.stem;
    const sprite = flowerSprite(stem.flower), sheet = sprite.url === ART_URL ? art : assets[sprite.url];
    if (!sheet) continue;
    const crop = spriteRect(sprite.index, sheet.naturalWidth, sheet.naturalHeight, sprite.rows);
    const { w, h, angle } = stemGeometry(stem);
    ctx.save(); ctx.translate(stem.x, stem.y); ctx.rotate(angle);
    ctx.drawImage(sheet, crop.x, crop.y, crop.w, crop.h, -w / 2, -h * .94, w, h);
    ctx.restore();
  }
  ctx.restore();
  drawWrapper(true);
  if (!wrapper && paper.sprite >= 0 && bouquet.stems.length) {
    const crop = spriteRect(paper.sprite, art.naturalWidth, art.naturalHeight);
    ctx.drawImage(art, crop.x, crop.y, crop.w, crop.h, 207, 398, 306, 340);
  }
  const active = bouquet.stems.find(s => s.id === selected);
  if (active) {
    const bloom = bloomPoint(active), tilt = stemHandle(active), size = stemScaleHandle(active);
    ctx.strokeStyle = paper.ink; ctx.lineWidth = 2; ctx.setLineDash([5, 6]);
    ctx.beginPath(); ctx.arc(bloom.x, bloom.y, bloom.r, 0, Math.PI * 2); ctx.stroke();
    // Tethered to the ring so the grips read as part of the selection rather
    // than stray dots on the paper.
    ctx.setLineDash([]);
    ctx.beginPath(); ctx.moveTo(tilt.x, tilt.y); ctx.lineTo(size.x, size.y); ctx.stroke();
    drawGrip(ctx, tilt.x, tilt.y, "tilt", paper.ink);
    drawGrip(ctx, size.x, size.y, "size", paper.ink);
  }
  ctx.restore();   // end shrink-to-fit
  ctx.restore();
  ctx.fillStyle = "#ffffffcf";
  ctx.beginPath(); ctx.roundRect(42, 743, WIDTH - 84, 166, 12); ctx.fill();
  ctx.fillStyle = paper.ink;
  let size = 23;
  let lines: string[] = [];
  do { ctx.font = `italic ${size}px Georgia, serif`; lines = wrappedLines(ctx, bouquet.message, WIDTH - 144); if (lines.length * (size + 6) <= 100) break; size--; } while (size > 10);
  const lineHeight = size + 6;
  lines.forEach((line, i) => ctx.fillText(line, WIDTH / 2, 767 + (100 - lines.length * lineHeight) / 2 + i * lineHeight + size));
  ctx.font = "16px sans-serif";
  ctx.fillText(bouquet.from.trim() ? `With love, ${bouquet.from.trim()}` : "With love", WIDTH / 2, 889, 590);
  ctx.font = "13px sans-serif";
  ctx.fillText("MADE WITH LOVE · DAYFLOWER", WIDTH / 2, 938);
}

/* ── Stationery ───────────────────────────────────────────────────────────
   Printed under everything, at the sender's chosen opacity, in the paper's
   own ink so it can never clash with the wrapping. Motifs are drawn at the
   origin and placed by the caller, which is what lets the pattern tiler jitter
   and rotate them without each one knowing where it sits. */

function motifHeart(ctx: CanvasRenderingContext2D, s: number) {
  ctx.beginPath();
  ctx.moveTo(0, s * .78);
  ctx.bezierCurveTo(-s * 1.15, -s * .1, -s * .48, -s * .98, 0, -s * .34);
  ctx.bezierCurveTo(s * .48, -s * .98, s * 1.15, -s * .1, 0, s * .78);
  ctx.fill();
}
function motifStar(ctx: CanvasRenderingContext2D, s: number) {
  ctx.beginPath();
  for (let i = 0; i < 10; i++) {
    const r = i % 2 ? s * .42 : s, a = -Math.PI / 2 + i * Math.PI / 5;
    if (i) ctx.lineTo(Math.cos(a) * r, Math.sin(a) * r); else ctx.moveTo(Math.cos(a) * r, Math.sin(a) * r);
  }
  ctx.closePath(); ctx.fill();
}
function motifBow(ctx: CanvasRenderingContext2D, s: number) {
  ctx.beginPath(); ctx.ellipse(-s * .58, 0, s * .52, s * .38, -.38, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.ellipse(s * .58, 0, s * .52, s * .38, .38, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.ellipse(-s * .34, s * .62, s * .16, s * .44, -.5, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.ellipse(s * .34, s * .62, s * .16, s * .44, .5, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.arc(0, 0, s * .21, 0, Math.PI * 2); ctx.fill();
}
function motifSprig(ctx: CanvasRenderingContext2D, s: number) {
  ctx.lineWidth = Math.max(1, s * .14); ctx.lineCap = "round";
  ctx.beginPath(); ctx.moveTo(0, s * 1.1); ctx.lineTo(0, -s * 1.1); ctx.stroke();
  for (let i = -2; i <= 1; i++) {
    const y = i * s * .52;
    ctx.beginPath(); ctx.ellipse(-s * .44, y, s * .42, s * .17, -.55, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath(); ctx.ellipse(s * .44, y + s * .26, s * .42, s * .17, .55, 0, Math.PI * 2); ctx.fill();
  }
}

/** A deterministic wobble, so the tiling looks hand-stamped but never changes. */
function jitter(n: number) { return (Math.sin(n * 12.9898) * 43758.5453) % 1; }

function drawPattern(ctx: CanvasRenderingContext2D, name: string) {
  if (name === "Gingham") {
    // Overlapping bands at partial alpha make the darker squares for free.
    const step = 48;
    ctx.globalAlpha *= .5;
    for (let x = 0; x < WIDTH; x += step * 2) ctx.fillRect(x, 0, step, HEIGHT);
    for (let y = 0; y < HEIGHT; y += step * 2) ctx.fillRect(0, y, WIDTH, step);
    return;
  }
  const motif = name === "Hearts" ? motifHeart : name === "Little stars" ? motifStar : name === "Bows" ? motifBow : motifSprig;
  const stepX = 96, stepY = 92, size = name === "Bows" ? 11 : 13;
  let n = 0;
  for (let row = 0; row * stepY < HEIGHT + stepY; row++) {
    for (let col = 0; col * stepX < WIDTH + stepX; col++) {
      const x = col * stepX + (row % 2 ? stepX / 2 : 0) + jitter(++n) * 9;
      const y = row * stepY + jitter(n + 99) * 9;
      ctx.save(); ctx.translate(x, y); ctx.rotate(jitter(n + 7) * .5); motif(ctx, size); ctx.restore();
    }
  }
}

function drawBorder(ctx: CanvasRenderingContext2D, name: string) {
  const m = 32;
  if (name === "Scalloped") {
    ctx.lineWidth = 2;
    const r = 16;
    for (const [len, horizontal] of [[WIDTH, true], [HEIGHT, false]] as const) {
      for (let i = m + r; i < len - m; i += r * 2) {
        for (const edge of horizontal ? [m, HEIGHT - m] : [m, WIDTH - m]) {
          ctx.beginPath();
          if (horizontal) ctx.arc(i, edge, r, Math.PI, 0, edge !== m);
          else ctx.arc(edge, i, r, Math.PI * .5, Math.PI * 1.5, edge === m);
          ctx.stroke();
        }
      }
    }
    ctx.strokeRect(m + 14, m + 14, WIDTH - (m + 14) * 2, HEIGHT - (m + 14) * 2);
    return;
  }
  if (name === "Vines") {
    // Sprigs march along each edge, turned to face the middle of the page.
    const place = (x: number, y: number, rotation: number, s: number) => {
      ctx.save(); ctx.translate(x, y); ctx.rotate(rotation); motifSprig(ctx, s); ctx.restore();
    };
    for (let x = m + 26; x < WIDTH - m; x += 58) { place(x, m, Math.PI / 2, 10); place(x, HEIGHT - m, Math.PI / 2, 10); }
    for (let y = m + 26; y < HEIGHT - m; y += 58) { place(m, y, 0, 10); place(WIDTH - m, y, 0, 10); }
    return;
  }
  // Petals: clusters tucked into the four corners, thinning as they trail away.
  for (const [cx, cy, sx, sy] of [[m, m, 1, 1], [WIDTH - m, m, -1, 1], [m, HEIGHT - m, 1, -1], [WIDTH - m, HEIGHT - m, -1, -1]] as const) {
    for (let i = 0; i < 9; i++) {
      const t = i / 8, along = 26 + t * 150, drift = 14 + jitter(i + 3) * 16;
      const flip = i % 2 ? 1 : -1;
      ctx.save();
      ctx.translate(cx + sx * (flip > 0 ? along : drift), cy + sy * (flip > 0 ? drift : along));
      ctx.rotate(jitter(i) * Math.PI);
      ctx.globalAlpha *= 1 - t * .55;
      ctx.beginPath(); ctx.ellipse(0, 0, 11 - t * 4, 6 - t * 2, 0, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    }
  }
}

/** Lays the stationery under the bouquet. A no-op for "Plain" or zero opacity. */
export function drawPrint(ctx: CanvasRenderingContext2D, index: number, opacity: number, ink: string) {
  const print = prints[index];
  if (!print || print.kind === "none" || opacity <= 0) return;
  ctx.save();
  ctx.globalAlpha = Math.max(0, Math.min(1, opacity / 100));
  ctx.fillStyle = ink; ctx.strokeStyle = ink;
  if (print.kind === "pattern") drawPattern(ctx, print.name); else drawBorder(ctx, print.name);
  ctx.restore();
}

/* ── Vessels ──────────────────────────────────────────────────────────────
   What the recipient sees before anything opens. Drawn in code so the send
   flow does not wait on artwork; a sprite sheet can replace the bodies of
   these six branches without touching anything that stores a vessel index. */

function seal(ctx: CanvasRenderingContext2D, x: number, y: number, r: number) {
  const wax = ctx.createLinearGradient(x - r, y - r, x + r, y + r);
  wax.addColorStop(0, "#f0709f"); wax.addColorStop(1, "#906fe8");
  ctx.fillStyle = wax;
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = "#fffdf8";
  ctx.save(); ctx.translate(x, y - r * .06); motifHeart(ctx, r * .46); ctx.restore();
}

function ribbon(ctx: CanvasRenderingContext2D, x: number, y: number, s: number) {
  const silk = ctx.createLinearGradient(x - s, y, x + s, y);
  silk.addColorStop(0, "#f0709f"); silk.addColorStop(1, "#d5568f");
  ctx.fillStyle = silk;
  ctx.save(); ctx.translate(x, y); motifBow(ctx, s); ctx.restore();
}

/**
 * Draws the closed vessel. `art` and `assets` are only needed by "Single stem",
 * which borrows the bouquet's own first flower rather than inventing one.
 */
export function renderVessel(canvas: HTMLCanvasElement, bouquet: Bouquet, art: HTMLImageElement | null, assets: RenderAssets = {}) {
  canvas.width = VESSEL_W;
  canvas.height = VESSEL_H;
  const ctx = canvas.getContext("2d");
  if (!ctx) return;
  const paper = papers[bouquet.paper], ink = paper.ink, cream = "#fffdf8";
  const cx = VESSEL_W / 2, cy = VESSEL_H / 2;
  ctx.clearRect(0, 0, VESSEL_W, VESSEL_H);
  ctx.textAlign = "center";
  const shadow = () => { ctx.shadowColor = "#25152220"; ctx.shadowBlur = 26; ctx.shadowOffsetY = 10; };
  const noShadow = () => { ctx.shadowColor = "transparent"; ctx.shadowBlur = 0; ctx.shadowOffsetY = 0; };
  const to = bouquet.to.trim();

  switch (bouquet.vessel ?? 0) {
    case 1: { // Postcard
      const w = 372, h = 250, x = cx - w / 2, y = cy - h / 2;
      shadow(); ctx.fillStyle = cream; ctx.fillRect(x, y, w, h); noShadow();
      ctx.strokeStyle = ink; ctx.globalAlpha = .35; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(cx + 14, y + 18); ctx.lineTo(cx + 14, y + h - 18); ctx.stroke();
      for (let i = 0; i < 4; i++) { const ly = y + 118 + i * 26; ctx.beginPath(); ctx.moveTo(cx + 34, ly); ctx.lineTo(x + w - 24, ly); ctx.stroke(); }
      ctx.globalAlpha = 1;
      ctx.setLineDash([3, 4]); ctx.strokeRect(x + w - 92, y + 20, 68, 80); ctx.setLineDash([]);
      ctx.fillStyle = ink;
      ctx.save(); ctx.translate(x + w - 58, y + 60); ctx.globalAlpha = .5; motifSprig(ctx, 13); ctx.restore();
      ctx.globalAlpha = .3; ctx.lineWidth = 2;
      for (let i = 0; i < 3; i++) { ctx.beginPath(); ctx.arc(x + w - 132, y + 54, 20 + i * 7, 0, Math.PI * 2); ctx.stroke(); }
      ctx.globalAlpha = 1;
      ctx.fillStyle = ink; ctx.font = "italic 21px Georgia, serif"; ctx.textAlign = "left";
      ctx.fillText(to ? "For " + to : "For you", x + 30, y + 56, 180);
      ctx.textAlign = "center";
      break;
    }
    case 2: { // Love letter
      const w = 258, h = 320, x = cx - w / 2, y = cy - h / 2;
      shadow(); ctx.fillStyle = cream; ctx.fillRect(x, y, w, h); noShadow();
      ctx.globalAlpha = .07; ctx.fillStyle = ink;
      for (const fy of [y + h / 3, y + h * 2 / 3]) ctx.fillRect(x, fy - 7, w, 7);
      ctx.strokeStyle = ink; ctx.globalAlpha = .34; ctx.lineWidth = 1.5;
      for (const fy of [y + h / 3, y + h * 2 / 3]) { ctx.beginPath(); ctx.moveTo(x, fy); ctx.lineTo(x + w, fy); ctx.stroke(); }
      ctx.lineWidth = 1;
      for (let i = 0; i < 9; i++) {
        const ly = y + 40 + i * 24, indent = i === 0 ? 46 : 22;
        ctx.beginPath(); ctx.moveTo(x + indent, ly); ctx.lineTo(x + w - 22 - (i % 3) * 30, ly); ctx.stroke();
      }
      ctx.globalAlpha = 1;
      seal(ctx, cx, y + h - 46, 26);
      break;
    }
    case 3: { // Carrier pigeon
      ctx.save(); ctx.translate(cx + 8, cy - 16);
      const outline = () => { ctx.strokeStyle = ink; ctx.globalAlpha = .32; ctx.lineWidth = 2; ctx.stroke(); ctx.globalAlpha = 1; };
      // Tail first, so the body edge overlaps and joins it to the bird.
      ctx.fillStyle = cream;
      ctx.beginPath();
      ctx.moveTo(52, -8); ctx.lineTo(150, -42); ctx.lineTo(144, -18); ctx.lineTo(152, 4); ctx.lineTo(58, 20);
      ctx.closePath(); ctx.fill(); outline();
      ctx.strokeStyle = ink; ctx.globalAlpha = .2; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(74, -2); ctx.lineTo(142, -26); ctx.moveTo(78, 8); ctx.lineTo(146, -6); ctx.stroke();
      ctx.globalAlpha = 1;
      shadow();
      ctx.fillStyle = cream;
      ctx.beginPath(); ctx.ellipse(0, 0, 96, 60, -.1, 0, Math.PI * 2); ctx.fill();
      noShadow(); ctx.beginPath(); ctx.ellipse(0, 0, 96, 60, -.1, 0, Math.PI * 2); outline();
      ctx.fillStyle = cream;
      ctx.beginPath(); ctx.ellipse(-82, -42, 38, 33, -.3, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.ellipse(-82, -42, 38, 33, -.3, 0, Math.PI * 2); outline();
      // Wing: a real shape with its own edge, not a pale ellipse that sank in.
      ctx.beginPath();
      ctx.moveTo(-26, -20);
      ctx.bezierCurveTo(34, -46, 84, -22, 74, 14);
      ctx.bezierCurveTo(34, 34, -8, 20, -26, -20);
      ctx.closePath();
      ctx.fillStyle = ink; ctx.globalAlpha = .13; ctx.fill(); ctx.globalAlpha = 1; outline();
      ctx.beginPath(); ctx.moveTo(-116, -42); ctx.lineTo(-152, -30); ctx.lineTo(-114, -18); ctx.closePath();
      ctx.fillStyle = "#e8922a"; ctx.fill();
      ctx.fillStyle = ink; ctx.beginPath(); ctx.arc(-92, -50, 5, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = "#fffdf8"; ctx.beginPath(); ctx.arc(-93.6, -51.6, 1.8, 0, Math.PI * 2); ctx.fill();
      // The message it carries, slung under the body and tied with a ribbon.
      ctx.strokeStyle = ink; ctx.globalAlpha = .5; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(-34, 44); ctx.lineTo(-30, 70); ctx.moveTo(16, 44); ctx.lineTo(14, 70); ctx.stroke();
      ctx.globalAlpha = 1;
      ctx.save(); ctx.translate(-8, 88); ctx.rotate(.06);
      shadow(); ctx.fillStyle = cream; ctx.fillRect(-56, -17, 112, 34); noShadow();
      ctx.beginPath(); ctx.rect(-56, -17, 112, 34); outline();
      ctx.strokeStyle = ink; ctx.globalAlpha = .34; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(-40, -6); ctx.lineTo(30, -6); ctx.moveTo(-40, 5); ctx.lineTo(12, 5); ctx.stroke();
      ctx.globalAlpha = 1; ribbon(ctx, 0, 0, 13);
      ctx.restore();
      ctx.restore();
      break;
    }
    case 4: { // Single stem — one flower, and nothing tied to it.
      const sprite = flowerSprite(singleStem(bouquet));
      const sheet = sprite.url === ART_URL ? art : assets[sprite.url];
      if (sheet) {
        const crop = spriteRect(sprite.index, sheet.naturalWidth, sheet.naturalHeight, sprite.rows);
        const h = 330, w = h * .75;
        ctx.drawImage(sheet, crop.x, crop.y, crop.w, crop.h, cx - w / 2, cy - h * .5, w, h);
      }
      break;
    }
    case 5: { // Gift box
      const w = 244, h = 158, x = cx - w / 2, y = cy - h / 2 + 44, lidH = 40, lidY = y - lidH;
      const silk = ctx.createLinearGradient(cx - 26, 0, cx + 26, 0);
      silk.addColorStop(0, "#f0709f"); silk.addColorStop(1, "#d5568f");
      shadow(); ctx.fillStyle = cream; ctx.fillRect(x, y, w, h); noShadow();
      ctx.fillStyle = ink; ctx.globalAlpha = .06; ctx.fillRect(x, y, w, h); ctx.globalAlpha = 1;
      // Ribbon down the front of the box only — it disappears under the lid.
      ctx.fillStyle = silk; ctx.fillRect(cx - 22, y, 44, h);
      shadow(); ctx.fillStyle = cream; ctx.fillRect(x - 14, lidY, w + 28, lidH); noShadow();
      ctx.fillStyle = ink; ctx.globalAlpha = .16; ctx.fillRect(x - 14, y - 3, w + 28, 3); ctx.globalAlpha = 1;
      ctx.fillStyle = silk; ctx.fillRect(cx - 22, lidY, 44, lidH);
      // Sits above the lid rather than across it, so the loops stay legible
      // when the whole vessel is scaled down to a preview card.
      ribbon(ctx, cx, lidY - 10, 30);
      break;
    }
    default: { // Paper envelope
      const w = 344, h = 232, x = cx - w / 2, y = cy - h / 2 + 10;
      shadow(); ctx.fillStyle = cream; ctx.fillRect(x, y, w, h); noShadow();
      ctx.fillStyle = ink; ctx.globalAlpha = .06;
      ctx.beginPath(); ctx.moveTo(x, y + h); ctx.lineTo(x + w / 2, y + h * .46); ctx.lineTo(x + w, y + h); ctx.closePath(); ctx.fill();
      ctx.globalAlpha = 1;
      ctx.fillStyle = cream; shadow();
      ctx.beginPath(); ctx.moveTo(x - 2, y); ctx.lineTo(x + w + 2, y); ctx.lineTo(x + w / 2, y + h * .62); ctx.closePath(); ctx.fill();
      noShadow();
      ctx.strokeStyle = ink; ctx.globalAlpha = .25; ctx.lineWidth = 1; ctx.stroke(); ctx.globalAlpha = 1;
      seal(ctx, cx, y + h * .6, 27);
      ctx.fillStyle = ink; ctx.font = "italic 20px Georgia, serif";
      ctx.fillText(to ? "For " + to : "For you", cx, y + h - 26, w - 60);
    }
  }
}

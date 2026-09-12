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

export type Stem = { id: number; flower: number; x: number; y: number; angle: number; scale: number };
export const photoFrames = ["Polaroid", "Sticker", "Cutout", "Heart", "Circle", "Arch", "Postage stamp"] as const;
export type Photo = { id: number; src: string; frame: number; x: number; y: number; angle: number; scale: number; zoom: number; cropX: number; cropY: number; caption: string; layer: "back" | "front" };
export type Bouquet = { v: 1; stems: Stem[]; paper: number; to: string; from: string; message: string; photos?: Photo[] };
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
    stems.push({ id: stems.length + 1, flower: s.flower, x: s.x, y: s.y, angle: s.angle, scale: s.scale });
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
      photos.push({ id: photos.length + 1, src: p.src, frame: p.frame, x: p.x, y: p.y, angle: p.angle, scale: p.scale, zoom: p.zoom, cropX: p.cropX, cropY: p.cropY, caption: p.caption, layer: p.layer });
    }
  }
  return { v: 1, stems, paper: b.paper, to: b.to, from: b.from, message: b.message, ...(photos.length ? { photos } : {}) };
}

// The gift travels in the URL fragment. No account, database row, or note upload is needed.
// This is an encoded gift, not encryption: anyone with the complete link can open it.
export function encodeBouquet(bouquet: Bouquet): string {
  const clean = validateBouquet(bouquet);
  if (!clean || !hasContents(clean)) throw new Error("Add at least one flower or photo before sharing.");
  if (photoCount(clean)) throw new Error("Photo bouquets must be saved before sharing.");
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
}

export type RenderAssets = Record<string, HTMLImageElement>;
export function renderBouquet(canvas: HTMLCanvasElement, bouquet: Bouquet, art: HTMLImageElement, selected?: number, assets: RenderAssets = {}, selectedPhoto?: number) {
  canvas.width = WIDTH;
  canvas.height = HEIGHT;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Your browser could not create the bouquet image.");
  const paper = papers[bouquet.paper];
  ctx.fillStyle = paper.background;
  ctx.fillRect(0, 0, WIDTH, HEIGHT);
  ctx.textAlign = "center";
  ctx.fillStyle = paper.ink;
  ctx.font = '16px sans-serif';
  ctx.fillText("A LITTLE SOMETHING, JUST FOR YOU", WIDTH / 2, 49);
  ctx.font = 'italic 32px Georgia, serif';
  ctx.fillText(bouquet.to.trim() ? `For ${bouquet.to.trim()}` : "You deserve flowers.", WIDTH / 2, 94, 620);
  ctx.save();
  ctx.beginPath(); ctx.rect(12, 112, WIDTH - 24, 615); ctx.clip();
  const wrapper = assets[WRAPPER_URL];
  const wrapIndex = bouquet.paper === 0 ? 0 : bouquet.paper === 1 ? 2 : bouquet.paper === 3 ? 4 : 6;
  const drawWrapper = (front: boolean) => {
    if (!wrapper || paper.sprite < 0 || !hasContents(bouquet)) return;
    const crop = spriteRect(wrapIndex + (front ? 1 : 0), wrapper.naturalWidth, wrapper.naturalHeight);
    ctx.drawImage(wrapper, crop.x, crop.y, crop.w, crop.h, 104, 130, 512, 600);
  };
  drawWrapper(false);
  ctx.save();
  if (paper.sprite >= 0 && wrapper) {
    // The opening stays broad; below it the foliage tapers into the tied paper.
    // This prevents leaves and stem ends from sticking through the wrapper's sides.
    ctx.beginPath(); ctx.moveTo(28, 112); ctx.lineTo(692, 112); ctx.lineTo(656, 390);
    ctx.lineTo(500, 530); ctx.lineTo(402, 658); ctx.lineTo(318, 658); ctx.lineTo(220, 530); ctx.lineTo(64, 390); ctx.closePath(); ctx.clip();
  }
  const drawPhotos = (layer: "back" | "front") => {
    for (const photo of bouquet.photos ?? []) if (photo.layer === layer && assets[photo.src]) drawPhoto(ctx, photo, assets[photo.src], selectedPhoto === photo.id);
  };
  drawPhotos("back");
  for (const stem of bouquet.stems) {
    const sprite = flowerSprite(stem.flower), sheet = sprite.url === ART_URL ? art : assets[sprite.url];
    if (!sheet) continue;
    const crop = spriteRect(sprite.index, sheet.naturalWidth, sheet.naturalHeight, sprite.rows);
    const { w, h, angle } = stemGeometry(stem);
    ctx.save(); ctx.translate(stem.x, stem.y); ctx.rotate(angle);
    ctx.drawImage(sheet, crop.x, crop.y, crop.w, crop.h, -w / 2, -h * .94, w, h);
    ctx.restore();
  }
  drawPhotos("front");
  ctx.restore();
  drawWrapper(true);
  if (!wrapper && paper.sprite >= 0 && bouquet.stems.length) {
    const crop = spriteRect(paper.sprite, art.naturalWidth, art.naturalHeight);
    ctx.drawImage(art, crop.x, crop.y, crop.w, crop.h, 207, 398, 306, 340);
  }
  const active = bouquet.stems.find(s => s.id === selected);
  if (active) {
    const bloom = bloomPoint(active), grip = stemHandle(active);
    ctx.strokeStyle = paper.ink; ctx.lineWidth = 2; ctx.setLineDash([5, 6]);
    ctx.beginPath(); ctx.arc(bloom.x, bloom.y, bloom.r, 0, Math.PI * 2); ctx.stroke();
    // The grip: a solid disc with a turning arrow, tethered to the ring so it
    // reads as part of the selection rather than a stray dot on the paper.
    ctx.setLineDash([]);
    ctx.beginPath(); ctx.moveTo(bloom.x, bloom.y); ctx.lineTo(grip.x, grip.y); ctx.stroke();
    ctx.fillStyle = paper.ink;
    ctx.beginPath(); ctx.arc(grip.x, grip.y, 13, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = "#fffdf8"; ctx.lineWidth = 2.2;
    ctx.beginPath(); ctx.arc(grip.x, grip.y, 6.4, Math.PI * .35, Math.PI * 1.65); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(grip.x + 1.2, grip.y - 8.4); ctx.lineTo(grip.x + 6.4, grip.y - 5.6); ctx.lineTo(grip.x + 1.2, grip.y - 2.4); ctx.closePath();
    ctx.fillStyle = "#fffdf8"; ctx.fill();
  }
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

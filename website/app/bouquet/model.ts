export const flowers = [
  { name: "Tulip", detail: "A little love", color: "#e89cb4" },
  { name: "Rose", detail: "Always you", color: "#a54765" },
  { name: "Daisy", detail: "Just because", color: "#dfbe63" },
  { name: "Sunflower", detail: "You are sunshine", color: "#dfa63d" },
  { name: "Lavender", detail: "A moment of calm", color: "#9f88c5" },
  { name: "Peony", detail: "Something lovely", color: "#d994b1" },
] as const;

export const papers = [
  { name: "Rose & ivory", background: "#f7edf0", ink: "#703e54", sprite: 6 },
  { name: "Lilac love", background: "#eee9f7", ink: "#65507c", sprite: 7 },
  { name: "Just the stems", background: "#edf2ec", ink: "#4b6554", sprite: -1 },
] as const;

export type Stem = { id: number; flower: number; x: number; y: number; angle: number; scale: number };
export type Bouquet = { v: 1; stems: Stem[]; paper: number; to: string; from: string; message: string };
export const MAX_STEMS = 12;
export const ART_URL = "/bouquet/botanical-sprites.webp";
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
  return { v: 1, stems, paper: b.paper, to: b.to, from: b.from, message: b.message };
}

// The gift travels in the URL fragment. No account, database row, or note upload is needed.
// This is an encoded gift, not encryption: anyone with the complete link can open it.
export function encodeBouquet(bouquet: Bouquet): string {
  const clean = validateBouquet(bouquet);
  if (!clean || !clean.stems.length) throw new Error("Add at least one flower before sharing.");
  const bytes = new TextEncoder().encode(JSON.stringify(clean));
  return btoa(Array.from(bytes, b => String.fromCharCode(b)).join("")).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}
export function decodeBouquet(encoded: string): Bouquet | null {
  if (!encoded || encoded.length > 9000 || !/^[\w-]+$/.test(encoded)) return null;
  try {
    const base64 = encoded.replaceAll("-", "+").replaceAll("_", "/");
    const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
    const result = validateBouquet(JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)));
    return result?.stems.length ? result : null;
  } catch { return null; }
}

export function spriteRect(index: number, imageWidth: number, imageHeight: number) {
  return { x: index % 4 * imageWidth / 4, y: Math.floor(index / 4) * imageHeight / 2, w: imageWidth / 4, h: imageHeight / 2 };
}
export function stemGeometry(stem: Stem) {
  const h = 470 * stem.scale;
  return { w: h * .75, h, angle: stem.angle * Math.PI / 180 };
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

export function renderBouquet(canvas: HTMLCanvasElement, bouquet: Bouquet, art: HTMLImageElement, selected?: number) {
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
  for (const stem of bouquet.stems) {
    const crop = spriteRect(stem.flower, art.naturalWidth, art.naturalHeight);
    const { w, h, angle } = stemGeometry(stem);
    ctx.save(); ctx.translate(stem.x, stem.y); ctx.rotate(angle);
    ctx.drawImage(art, crop.x, crop.y, crop.w, crop.h, -w / 2, -h * .94, w, h);
    ctx.restore();
  }
  if (paper.sprite >= 0 && bouquet.stems.length) {
    const crop = spriteRect(paper.sprite, art.naturalWidth, art.naturalHeight);
    ctx.drawImage(art, crop.x, crop.y, crop.w, crop.h, 207, 398, 306, 340);
  }
  const active = bouquet.stems.find(s => s.id === selected);
  if (active) {
    const { h, angle } = stemGeometry(active);
    ctx.strokeStyle = paper.ink; ctx.lineWidth = 2; ctx.setLineDash([5, 6]);
    ctx.beginPath(); ctx.arc(active.x + Math.sin(angle) * h * .70, active.y - Math.cos(angle) * h * .70, h * .19, 0, Math.PI * 2); ctx.stroke();
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

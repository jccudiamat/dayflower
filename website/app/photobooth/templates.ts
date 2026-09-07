export type Shot = { image: HTMLImageElement; zoom: number; x: number; y: number };
export const themes = [
  { name: "Rose", paper: "#f9e9ed", ink: "#542f40", accent: "#ad365d" },
  { name: "Cream", paper: "#f5f0e4", ink: "#38392f", accent: "#72764d" },
  { name: "After dark", paper: "#252331", ink: "#fcf5e9", accent: "#ddbb75" },
  { name: "Lilac", paper: "#ede8f5", ink: "#423751", accent: "#8065a5" },
];
export const templates = [
  { id: "scrapbook", name: "Little things", category: "Scrapbook", count: 4, height: 1920, caption: "the little things", note: "Tape, scribbles & a pocketful of memories", tag: "Story · 9:16" },
  { id: "recap", name: "Life lately", category: "Photo dumps", count: 9, height: 1920, caption: "life lately", note: "Nine moments worth keeping", tag: "Story · 9:16" },
  { id: "editorial", name: "Sunday journal", category: "Photo dumps", count: 5, height: 1350, caption: "a slow kind of Sunday", note: "Your camera roll, in print", tag: "Feed · 4:5" },
  { id: "polaroid", name: "Wish you were here", category: "Scrapbook", count: 3, height: 1920, caption: "wish you were here", note: "A stack of sun-soaked instant prints", tag: "Story · 9:16" },
  { id: "film", name: "On film", category: "Booth strips", count: 4, height: 1920, caption: "a night to remember", note: "Four frames. One cinematic memory.", tag: "Story · 9:16" },
  { id: "postcard", name: "A postcard for you", category: "Scrapbook", count: 2, height: 1350, caption: "somewhere with you", note: "Send a little piece of your day", tag: "Feed · 4:5" },
  { id: "couple", name: "You & me", category: "Booth strips", count: 6, height: 1920, caption: "better together", note: "Two people, three moments each", tag: "Story · 9:16" },
  { id: "solo", name: "The original", category: "Booth strips", count: 3, height: 1920, caption: "just me, today", note: "The photo-booth classic", tag: "Story · 9:16" },
] as const;
export type Template = typeof templates[number];
type Frame = { x: number; y: number; w: number; h: number; angle?: number; paper?: boolean; tape?: boolean };
export function framesFor(id: string): Frame[] {
  switch (id) {
    case "scrapbook": return [{ x: 90, y: 290, w: 450, h: 500, angle: -7, paper: true, tape: true }, { x: 590, y: 410, w: 370, h: 410, angle: 8, paper: true }, { x: 90, y: 1020, w: 390, h: 460, angle: 5, paper: true }, { x: 570, y: 1090, w: 410, h: 470, angle: -6, paper: true, tape: true }];
    case "recap": return Array.from({ length: 9 }, (_, i) => ({ x: 48 + i % 3 * 334, y: 300 + Math.floor(i / 3) * 430, w: 316, h: 368, paper: true }));
    case "editorial": return [{ x: 50, y: 260, w: 620, h: 630 }, { x: 695, y: 260, w: 335, h: 300 }, { x: 695, y: 585, w: 335, h: 305 }, { x: 50, y: 915, w: 475, h: 270 }, { x: 550, y: 915, w: 480, h: 270 }];
    case "polaroid": return [{ x: 130, y: 290, w: 730, h: 490, angle: -9, paper: true }, { x: 240, y: 770, w: 680, h: 480, angle: 8, paper: true }, { x: 140, y: 1230, w: 700, h: 430, angle: -5, paper: true, tape: true }];
    case "film": return Array.from({ length: 4 }, (_, i) => ({ x: 140, y: 200 + i * 363, w: 800, h: 335 }));
    case "postcard": return [{ x: 65, y: 210, w: 600, h: 700, angle: -3, paper: true, tape: true }, { x: 700, y: 440, w: 285, h: 360, angle: 5, paper: true }];
    case "couple": return Array.from({ length: 6 }, (_, i) => ({ x: 65 + i % 2 * 485, y: 270 + Math.floor(i / 2) * 440, w: 465, h: 400 }));
    default: return Array.from({ length: 3 }, (_, i) => ({ x: 110, y: 240 + i * 460, w: 860, h: 420 }));
  }
}

// One renderer powers the gallery, live preview, and exported PNG.
export function renderTemplate(canvas: HTMLCanvasElement, template: Template, shots: (Shot | null)[], theme: number, caption: string, mono: boolean, thumbnail = false) {
  const ctx = canvas.getContext("2d");
  if (!ctx) return;
  canvas.width = thumbnail ? 270 : 1080;
  canvas.height = template.height * (thumbnail ? .25 : 1);
  ctx.scale(thumbnail ? .25 : 1, thumbnail ? .25 : 1);
  const { paper, ink, accent } = themes[theme];
  const film = template.id === "film";
  ctx.fillStyle = film ? "#1c1b19" : paper;
  ctx.fillRect(0, 0, 1080, template.height);
  const text = (value: string, x: number, y: number, size: number, color = ink, font = "Georgia", align: CanvasTextAlign = "center", max = 960) => {
    ctx.fillStyle = color; ctx.font = `${size}px ${font}`; ctx.textAlign = align;
    ctx.fillText(value, x, y, max);
  }
  const line = (x: number, y: number, w: number, color = accent) => {
    ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + w, y); ctx.stroke();
  }
  if (["scrapbook", "postcard"].includes(template.id)) {
    ctx.strokeStyle = `${accent}20`; ctx.lineWidth = 1;
    for (let y = 0; y < template.height; y += 42) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(1080, y); ctx.stroke(); }
    text("✧", 940, 230, 110, accent);
  }
  if (template.id === "editorial") {
    text("THE SUNDAY JOURNAL", 540, 118, 76);
    line(50, 155, 980); text("PERSONAL EDITION     /     SMALL MOMENTS, BIG FEELINGS", 540, 202, 22, ink, "monospace");
  } else if (template.id === "postcard") {
    text("POSTCARD", 65, 130, 66, ink, "Georgia", "left");
    ctx.strokeStyle = accent; ctx.lineWidth = 3; ctx.strokeRect(850, 65, 145, 150);
    text("WITH", 922, 118, 22, accent, "monospace"); text("LOVE", 922, 158, 27, accent);
    for (let y = 260; y < 370; y += 30) line(745, y, 240);
  } else {
    text(template.id === "couple" ? "YOU & ME" : film ? "DAYFLOWER  /  ANALOG DIARY" : "THE DAYS WE KEEP", 540, 100, 25, film ? "#dfc38e" : accent, "monospace");
    if (!film) text(caption || template.caption, 540, 204, template.id === "recap" ? 94 :  70);
  }
  framesFor(template.id).forEach((f, i) => {
    ctx.save(); ctx.translate(f.x + f.w / 2, f.y + f.h / 2); ctx.rotate((f.angle || 0) * Math.PI / 180);
    const x = -f.w / 2, y = -f.h / 2;
    if (f.paper) {
      ctx.shadowColor = "#20151935"; ctx.shadowBlur = 18; ctx.shadowOffsetY = 7;
      ctx.fillStyle = "#fffdf7"; ctx.fillRect(x - 14, y - 14, f.w + 28, f.h + 64);
      ctx.shadowColor = "transparent";
    }
    ctx.save(); ctx.beginPath(); ctx.rect(x, y, f.w, f.h); ctx.clip();
    const shot = shots[i];
    if (shot) {
      const im = shot.image, scale = Math.max(f.w / im.width, f.h / im.height) * shot.zoom;
      const dw = im.width * scale, dh = im.height * scale;
      ctx.filter = mono ? "grayscale(1)" : "none";
      ctx.drawImage(im, x - (dw - f.w) * shot.x / 100, y - (dh - f.h) * shot.y / 100, dw, dh);
    } else {
      ctx.fillStyle = theme === 2 || film ? "#45434d" : "#ded8d3"; ctx.fillRect(x, y, f.w, f.h);
      text(`+ ${template.id === "couple" ? `${i % 2 ? "B" : "A"}${Math.floor(i / 2) + 1}` : `Photo ${i + 1}`}`, 0, 12, 30, theme === 2 || film ? "#eee8e1" : "#655b60", "sans-serif", "center", f.w - 20);
    }
    ctx.restore();
    if (f.paper) text(["a little joy", "stay awhile", "keep this feeling", "my favorite"][i % 4], 0, f.h / 2 + 34, 21, "#655748", "Georgia");
    if (f.tape) { ctx.fillStyle = "#ccb783b0"; ctx.rotate(-.035); ctx.fillRect(-75, y - 34, 150, 48); }
    ctx.restore();
  });
  if (film) {
    for (let y = 180; y < 1650; y += 62) {
      ctx.fillStyle = "#f5f0e4"; ctx.fillRect(53, y, 36, 30); ctx.fillRect(991, y, 36, 30);
    }
    text(caption || template.caption, 540, 1750, 61, "#f5f0e4");
    text("35 MM     •     FOUR MOMENTS / FOREVER", 540, 1810, 23, "#dfc38e", "monospace");
  } else if (template.id === "editorial") {
    text(caption || template.caption, 540, 1260, 45);
  } else if (template.id === "postcard") {
    text(caption || template.caption, 540, 1110, 66);
    text("a little piece of my world, sent to yours", 540, 1180, 30, accent);
  } else {
    text(template.id === "scrapbook" ? "♡   collected, never forgotten   ♡" : "these are the good old days", 540, 1780, 36, accent, "Georgia");
    if (template.id === "scrapbook") { text("oh, happy days!", 660, 990, 44, accent); text("♡", 210, 1690,  80, accent); }
  }
  text("DAYFLOWER  ·  mydayflower.com", 540, template.height - 35, 18, film ? "#d4c6ad" : ink, "monospace");
}

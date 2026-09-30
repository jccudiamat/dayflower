import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';

const compiled = ts.transpileModule(readFileSync(new URL('../app/bouquet/model.ts', import.meta.url), 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
const model = { exports: {} };
new Function('module', 'exports', compiled)(model, model.exports);
const { makeBouquet, arrange, encodeBouquet, decodeBouquet, validateBouquet, renderBouquet, spriteRect, MAX_STEMS, MAX_NOTE_LENGTH, MAX_PRIVATE_LINK_LENGTH, papers, wrappingLayers, wrapperAsset, noteLayout } = model.exports;

test('shared bouquet preserves flowers, placement, wrapping, and multilingual note', () => {
  const bouquet = makeBouquet(1);
  bouquet.to = '愛 🌷'; bouquet.from = 'حبيبي'; bouquet.message = 'Across any distance 💕\nいつもありがとう';
  bouquet.stems[0].x = 412; bouquet.stems[0].angle = -18; bouquet.stems[0].scale = 1.13;
  const encoded = encodeBouquet(bouquet);
  assert.match(encoded, /^[\w-]+$/);
  assert.deepEqual(decodeBouquet(encoded), bouquet);
  const received = decodeBouquet(encoded);
  bouquet.message = 'A later edit';
  assert.notEqual(received.message, bouquet.message);
});

test('invalid or truncated links fail closed', () => {
  for (const encoded of ['', 'undefined', '<script>', 'x'.repeat(MAX_PRIVATE_LINK_LENGTH + 1), encodeBouquet(makeBouquet()).slice(0, -10), btoa('{"v":99}')]) assert.equal(decodeBouquet(encoded), null);
  const b = makeBouquet();
  for (const value of [null, {}, { ...b, v: 2 }, { ...b, paper: 13 }, { ...b, paper: .5 }, { ...b, message: 'x'.repeat(MAX_NOTE_LENGTH + 1) }, { ...b, stems: Array(MAX_STEMS + 1).fill(b.stems[0]) }]) assert.equal(validateBouquet(value), null);
  for (const stem of [{ ...b.stems[0], flower: 99 }, { ...b.stems[0], flower: 1.2 }, { ...b.stems[0], x: Infinity }, { ...b.stems[0], angle: 46 }, { ...b.stems[0], scale: .1 }]) assert.equal(validateBouquet({ ...b, stems: [stem] }), null);
  assert.throws(() => encodeBouquet({ ...b, stems: [] }), /at least one flower/);
});

test('local drafts accept an empty bouquet and discard untrusted properties', () => {
  const b = { ...makeBouquet(), stems: [], unsafe: '<script>' };
  assert.deepEqual(validateBouquet(b), { v: 1, stems: [], paper: b.paper, to: b.to, from: b.from, message: b.message });
  const repeatedIds = makeBouquet();
  repeatedIds.stems.forEach(s => s.id = -1);
  const clean = validateBouquet(repeatedIds);
  assert.equal(new Set(clean.stems.map(s => s.id)).size, clean.stems.length);
});

test('all presets and arrangements remain valid through the stem limit', () => {
  for (let count = 0; count <= MAX_STEMS; count++) {
    const b = { ...makeBouquet(), stems: arrange(Array.from({ length: count }, (_, i) => i % 6)) };
    assert.ok(validateBouquet(b));
  }
  for (let i = 0; i < 3; i++) assert.ok(validateBouquet(makeBouquet(i)));
  for (let i = 0; i < 8; i++) {
    const r = spriteRect(i, 1536, 1024);
    assert.ok(r.x >= 0 && r.x + r.w <= 1536 && r.y >= 0 && r.y + r.h <= 1024);
  }
});

function recordingCanvas() {
  const calls = [];
  const ctx = new Proxy({ font: '', createLinearGradient() { return { addColorStop() {} }; }, measureText(text) { return { width: Array.from(text).length * (parseFloat(this.font.match(/([\d.]+)px/)?.[1] || '23')) * .65 }; } }, {
    get(obj, key) { return key in obj ? obj[key] : (...args) => calls.push([key, ...args]); }
  });
  return { canvas: { getContext: () => ctx }, calls };
}

test('export draws every flower and wrapping, omits editing marks, and fits long notes', () => {
  for (let paper = 0; paper < 3; paper++) for (const message of ['x'.repeat(2000), '🌷'.repeat(1000), 'hello\n'.repeat(333), '', 'You make my day.']) {
    const b = { ...makeBouquet(), paper, message };
    const { canvas, calls } = recordingCanvas();
    renderBouquet(canvas, b, { naturalWidth: 1536, naturalHeight: 1024 });
    assert.equal(canvas.width, 1120); assert.ok(canvas.height >= 1120);
    assert.equal(calls.filter(c => c[0] === 'drawImage').length, b.stems.length + (paper < 2 ? 1 : 0));
    assert.equal(calls.filter(c => c[0] === 'arc').length, 0);
    for (const call of calls) for (const arg of call.slice(1)) if (typeof arg === 'number') assert.ok(Number.isFinite(arg));
    for (const [, text, x, y] of calls.filter(c => c[0] === 'fillText')) { assert.ok(x >= 0 && x <= 1120); assert.ok(y >= 0 && y < canvas.height, `Text outside image: ${text}`); }
  }
  const { canvas, calls } = recordingCanvas();
  renderBouquet(canvas, makeBouquet(), { naturalWidth: 1536, naturalHeight: 1024 }, 1);
  assert.ok(calls.some(c => c[0] === 'arc'), 'The editor includes visible selection handles');
});

test('new stationery options survive shared links and old gifts keep their defaults', () => {
  const { papers, backgrounds, borders } = model.exports;
  for (let paper = 0; paper < papers.length; paper++) for (let background = 1; background < backgrounds.length; background++) {
    const b = { ...makeBouquet(), paper, background, border: borders.length - 1, vessel: 3, print: 5, printOpacity: 20 };
    assert.deepEqual(decodeBouquet(encodeBouquet(b)), b);
  }
  const original = makeBouquet();
  assert.deepEqual(decodeBouquet(encodeBouquet(original)), original);
  assert.deepEqual(validateBouquet({ ...original, background: 999, border: -1 }), original);
});

test('each wrapper brackets all flowers and photos between back and front layers', () => {
  const { papers, WRAPPER_URL, SPECIAL_WRAPPER_URL, EXTRA_ART_URLS } = model.exports;
  const art = { naturalWidth: 1536, naturalHeight: 1024 };
  const wrapped = { naturalWidth: 1536, naturalHeight: 1024 };
  const special = { naturalWidth: 1536, naturalHeight: 1024 };
  const assets = { [WRAPPER_URL]: wrapped, [SPECIAL_WRAPPER_URL]: special };
  EXTRA_ART_URLS.forEach(url => assets[url] = { naturalWidth: 1254, naturalHeight: 1254 });
  for (let paper = 0; paper < papers.length; paper++) {
    const { canvas, calls } = recordingCanvas();
    const b = { ...makeBouquet(), paper, stems: arrange([0, 12, 36, 53]) };
    renderBouquet(canvas, b, art, undefined, assets);
    const images = calls.filter(c => c[0] === 'drawImage');
    assert.equal(images.length, b.stems.length + (paper === 2 ? 0 : 2 * wrappingLayers(paper).length));
    if (paper !== 2) {
      assert.equal(images[0][1], assets[wrapperAsset(paper)]);
      assert.equal(images.at(-1)[1], images[0][1]);
      assert.notEqual(images[0][2], images.at(-1)[2], 'Back and front use distinct sprite cells');
    }
  }
});

test('illustrated reveals use the selected artwork without exposing the note', () => {
  const { renderVessel, REVEAL_ART } = model.exports;
  const assets = Object.fromEntries(Object.values(REVEAL_ART).map(url => [url, { naturalWidth: 512, naturalHeight: 512 }]));
  for (const vessel of [0, 2, 3, 5]) {
    const { canvas, calls } = recordingCanvas();
    renderVessel(canvas, { ...makeBouquet(), vessel, to: 'Alex', message: 'The surprise inside' }, null, assets);
    assert.equal(calls.find(c => c[0] === 'drawImage')[1], assets[REVEAL_ART[vessel]]);
    assert.ok(!calls.some(c => c[0] === 'fillText' && c[1].includes('The surprise inside')));
  }
});


test('extreme rotated flowers, photos and wrappers fit all four canvas edges', () => {
  const { fitScale, stemGeometry, photoGeometry, WRAP_PIVOT: pivot, ARRANGEMENT_OFFSET: offset } = model.exports;
  for (const angle of [-45, 45]) for (const x of [110, 610]) for (const wrapAngle of [-20, 20]) {
    const b = { ...makeBouquet(), wrapAngle, wrapScale: 1.3 };
    b.stems = b.stems.map(stem => ({ ...stem, x: x === 110 ? 220 : 500, y: 490, scale: 1.15, angle }));
    b.photos = [{ x, y: 190, scale: 1.5, angle, frame: 0 }];
    const boxes = b.stems.map(stem => { const g = stemGeometry(stem); return [stem.x, stem.y, -g.w / 2, -g.h * .94, g.w, g.h, g.angle]; });
    const g = photoGeometry(b.photos[0]); boxes.push([x, 190, -g.w / 2, -g.h / 2, g.w, g.h, g.angle]);
    boxes.push([360, 690, (104 - 360) * 1.3, (130 - 690) * 1.3, 512 * 1.3, 600 * 1.3, wrapAngle * Math.PI / 180]);
    const fit = fitScale(b);
    assert.ok(fit > 0 && fit <= 1);
    for (const [cx, cy, left, top, w, h, radians] of boxes) for (const dx of [left, left + w]) for (const dy of [top, top + h]) {
      const px = cx + dx * Math.cos(radians) - dy * Math.sin(radians);
      const py = cy + dx * Math.sin(radians) + dy * Math.cos(radians);
      const renderedX = offset.x + pivot.x + (px - pivot.x) * fit;
      const renderedY = offset.y + pivot.y + (py - pivot.y) * fit;
      assert.ok(renderedX >= 24 - 1e-6 && renderedX <= 1096 + 1e-6);
      assert.ok(renderedY >= 112 - 1e-6 && renderedY <= 887 + 1e-6);
    }
  }
});


test('note stationery and lettering round-trip and reject untrusted choices', () => {
  const { notePapers, letterings, stationerySets } = model.exports;
  for (let notePaper = 0; notePaper < notePapers.length; notePaper++) for (let lettering = 0; lettering < letterings.length; lettering++) {
    const b = { ...makeBouquet(), ...(notePaper ? { notePaper } : {}), ...(lettering ? { lettering } : {}) };
    assert.deepEqual(decodeBouquet(encodeBouquet(b)), b);
  }
  for (const key of ['notePaper', 'lettering']) for (const value of [-1, 99, .5, '<script>', Infinity]) assert.equal(validateBouquet({ ...makeBouquet(), [key]: value }, true), null);
  for (const { name, ...style } of stationerySets) {
    const b = { ...makeBouquet(), ...style };
    assert.ok(validateBouquet(b, true), name);
    const { canvas } = recordingCanvas(); renderBouquet(canvas, b, { naturalWidth: 1536, naturalHeight: 1024 });
    assert.ok(canvas.height >= canvas.width);
  }
});

test('full multilingual notes survive sharing and expand without losing text', () => {
  const b = { ...makeBouquet(), paper: 0, wrapScale: 1.65, stems: arrange(Array(MAX_STEMS).fill(0)), message: '愛'.repeat(MAX_NOTE_LENGTH) };
  const encoded = encodeBouquet(b);
  assert.ok(encoded.length <= MAX_PRIVATE_LINK_LENGTH);
  assert.deepEqual(decodeBouquet(encoded), b);
  assert.ok(validateBouquet(b, true));
  const { canvas, calls } = recordingCanvas();
  const layout = noteLayout(canvas.getContext('2d'), b);
  assert.equal(layout.lines.join(''), b.message);
  assert.ok(layout.canvasHeight > 1120);
  assert.match(layout.font, /32px/);
  renderBouquet(canvas, b, { naturalWidth: 1536, naturalHeight: 1024 });
  assert.equal(canvas.height, layout.canvasHeight);
  assert.ok(!calls.some(c => c[0] === 'fillText' && /a little something/i.test(c[1])));
  assert.deepEqual(noteLayout(canvas.getContext('2d'), { ...b, message: 'First paragraph\n\nSecond paragraph' }).lines, ['First paragraph', '', 'Second paragraph']);
  const pathological = noteLayout(canvas.getContext('2d'), { ...b, message: 'a\n'.repeat(1000) });
  assert.equal(pathological.lines.join('').replace(/\s/g, ''), 'a'.repeat(1000));
  assert.ok(pathological.canvasHeight < 5500);
});

test('tall layouts and vases preserve their geometry through saved links', () => {
  const { bloomPoint, fitScale, arrangementExtraHeight, STEM_BOUNDS } = model.exports;
  for (let layout = 0; layout < 4; layout++) for (let vase = 0; vase < 4; vase++) for (let count = 1; count <= 24; count++) {
    const b = { ...makeBouquet(), arrangement: layout, vase, stems: arrange(Array(count).fill(0), layout, vase) };
    const clean = validateBouquet(b, true);
    assert.ok(clean, `layout ${layout}, vase ${vase}, count ${count}`);
    assert.deepEqual(decodeBouquet(encodeBouquet(b)), clean);
    assert.ok(fitScale(b) > 0 && fitScale(b) <= 1);
    for (const stem of b.stems) assert.ok(stem.y >= STEM_BOUNDS.minY && stem.y <= STEM_BOUNDS.maxY);
    if (count >= 3 && layout === 2) {
      const heights = b.stems.slice(0, 3).map(s => bloomPoint(s).y);
      assert.ok(heights[1] - heights[0] > 150 && heights[2] - heights[1] > 150, 'Three tiers are vertically separated blooms');
    }
    const { canvas, calls } = recordingCanvas();
    renderBouquet(canvas, b, { naturalWidth: 1536, naturalHeight: 1024 });
    assert.ok(canvas.height >= 1120 + arrangementExtraHeight(b));
    assert.equal(calls.filter(c => c[0] === 'drawImage').length, count + (vase ? 0 : 1), 'Vases replace the paper wrapper');
  }
  for (const key of ['vase', 'arrangement']) for (const bad of [-1, 4, .5, '1', Infinity]) assert.equal(validateBouquet({ ...makeBouquet(), [key]: bad }, true), null);
});

test('retired wraps map to single papers so existing gifts still open', () => {
  assert.equal(papers.length, 9);
  for (const [old, current] of [[9, 0], [10, 5], [11, 1], [12, 0]]) {
    assert.equal(validateBouquet({ ...makeBouquet(), paper: old }).paper, current);
    assert.equal(wrappingLayers(current).length, 1);
  }
});

test('gift email never reveals the private note in HTML or plain text', () => {
  const source = ts.transpileModule(readFileSync(new URL('../emails/bouquet-gift.ts', import.meta.url), 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
  const mail = { exports: {} }; new Function('module', 'exports', source)(mail, mail.exports);
  const gift = { to: 'Alex', from: 'Sam', note: 'PRIVATE NOTE <script>alert(1)</script>', url: 'https://mydayflower.com/g/test', imageUrl: 'https://mydayflower.com/g/test/opengraph-image' };
  for (const result of [mail.exports.htmlFor(gift), mail.exports.textFor(gift)]) {
    assert.ok(!result.includes('PRIVATE NOTE')); assert.ok(!result.includes('<script>'));
    assert.ok(result.includes(gift.url));
  }
  assert.ok(mail.exports.htmlFor(gift).includes(gift.imageUrl));
});


test('special wrapping includes paper tips beyond the nominal cell without stretching', () => {
  const { drawWrapperLayer } = model.exports;
  for (const paper of [5, 6, 7, 8]) {
    const { canvas, calls } = recordingCanvas();
    drawWrapperLayer(canvas.getContext('2d'), paper, false, { naturalWidth: 1536, naturalHeight: 1024 });
    const [, , sx, , sw, sh, , , dw, dh] = calls.find(call => call[0] === 'drawImage');
    assert.ok(sw >= 403, 'The right paper tip extends beyond the 384px cell');
    assert.ok(sx + sw <= 1536, 'The expanded crop stays inside the sheet');
    assert.ok(Math.abs(dw / sw - 512 / 384) < 1e-9, 'Paper keeps its original horizontal scale');
    assert.equal(dh / sh, 600 / 512);
  }
});

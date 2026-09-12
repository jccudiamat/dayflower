import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';

const compiled = ts.transpileModule(readFileSync(new URL('../app/bouquet/model.ts', import.meta.url), 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
const model = { exports: {} };
new Function('module', 'exports', compiled)(model, model.exports);
const { makeBouquet, arrange, encodeBouquet, decodeBouquet, validateBouquet, renderBouquet, spriteRect, MAX_STEMS } = model.exports;

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
  for (const encoded of ['', 'undefined', '<script>', 'x'.repeat(9001), encodeBouquet(makeBouquet()).slice(0, -10), btoa('{"v":99}')]) assert.equal(decodeBouquet(encoded), null);
  const b = makeBouquet();
  for (const value of [null, {}, { ...b, v: 2 }, { ...b, paper: 9 }, { ...b, paper: .5 }, { ...b, message: 'x'.repeat(281) }, { ...b, stems: Array(MAX_STEMS + 1).fill(b.stems[0]) }]) assert.equal(validateBouquet(value), null);
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
  const ctx = new Proxy({ font: '', measureText(text) { return { width: Array.from(text).length * (parseFloat(this.font.match(/([\d.]+)px/)?.[1] || '23')) * .65 }; } }, {
    get(obj, key) { return key in obj ? obj[key] : (...args) => calls.push([key, ...args]); }
  });
  return { canvas: { getContext: () => ctx }, calls };
}

test('export draws every flower and wrapping, omits editing marks, and fits long notes', () => {
  for (let paper = 0; paper < 3; paper++) for (const message of ['x'.repeat(280), '🌷'.repeat(140), 'hello\n'.repeat(46), '', 'You make my day.']) {
    const b = { ...makeBouquet(), paper, message };
    const { canvas, calls } = recordingCanvas();
    renderBouquet(canvas, b, { naturalWidth: 1536, naturalHeight: 1024 });
    assert.equal(canvas.width, 720); assert.equal(canvas.height, 960);
    assert.equal(calls.filter(c => c[0] === 'drawImage').length, b.stems.length + (paper < 2 ? 1 : 0));
    assert.equal(calls.filter(c => c[0] === 'arc').length, 0);
    for (const call of calls) for (const arg of call.slice(1)) if (typeof arg === 'number') assert.ok(Number.isFinite(arg));
    for (const [, text, x, y] of calls.filter(c => c[0] === 'fillText')) { assert.ok(x >= 0 && x <= 720); assert.ok(y >= 0 && y <= 960, `Text outside image: ${text}`); }
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
    assert.equal(images.length, b.stems.length + (paper === 2 ? 0 : 2));
    if (paper !== 2) {
      assert.equal(images[0][1], paper < 5 ? wrapped : special);
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

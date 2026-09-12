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
  for (const value of [null, {}, { ...b, v: 2 }, { ...b, paper: 9 }, { ...b, paper: .5 }, { ...b, message: 'x'.repeat(281) }, { ...b, stems: Array(13).fill(b.stems[0]) }]) assert.equal(validateBouquet(value), null);
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
  assert.equal(calls.filter(c => c[0] === 'arc').length, 1);
});

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';
const compiled = ts.transpileModule(readFileSync(new URL('../app/photobooth/templates.ts', import.meta.url), 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
const renderer = { exports: {} };
new Function('module', 'exports', compiled)(renderer, renderer.exports);
const { templates, themes, framesFor, renderTemplate } = renderer.exports;

for (const template of templates) {
  test(`${template.name}: all frames and rotated paper fit the export`, () => {
    const frames = framesFor(template.id);
    assert.equal(frames.length, template.count);
    for (const f of frames) {
      const angle = (f.angle || 0) * Math.PI / 180;
      for (const dx of [-f.w / 2 - (f.paper ? 14 : 0), f.w / 2 + (f.paper ? 14 : 0)]) {
        for (const dy of [-f.h / 2 - (f.paper ? 34 : 0), f.h / 2 + (f.paper ? 50 : 0)]) {
          const x = f.x + f.w / 2 + dx * Math.cos(angle) - dy * Math.sin(angle);
          const y = f.y + f.h / 2 + dx * Math.sin(angle) + dy * Math.cos(angle);
          assert.ok(x >= 0 && x <= 1080 && y >= 0 && y < template.height - 60, `Frame outside export: ${x}, ${y}`);
        }
      }
    }
  });
  test(`${template.name}: preview and export draw every photo at every crop extreme`, () => {
    for (const theme of themes.keys()) for (const thumbnail of [true, false]) for (const zoom of [1, 3]) {
      const calls = [];
      const ctx = new Proxy({}, { get: (obj, key) => key in obj ? obj[key] : (...args) => calls.push([key, ...args]) });
      const canvas = { getContext: () => ctx };
      const shots = Array.from({ length: 9 }, (_, i) => ({ image: { width: i % 2 ? 1800 : 600, height: i % 2 ? 600 : 1800 }, zoom, x: i % 2 ? 100 : 0, y: i % 2 ? 0 : 100 }));
      renderTemplate(canvas, template, shots, theme, 'My own caption', true, thumbnail);
      assert.equal(canvas.width, thumbnail ? 270 : 1080);
      assert.equal(canvas.height, template.height * (thumbnail ? .25 : 1));
      assert.equal(calls.filter(c => c[0] === 'drawImage').length, template.count);
      assert.equal(calls.filter(c => c[0] === 'clip').length, template.count);
      assert.ok(calls.some(c => c[0] === 'fillText' && c[1] === 'My own caption'));
      assert.equal(ctx.filter, 'grayscale(1)');
      for (const call of calls) for (const arg of call.slice(1)) if (typeof arg === 'number') assert.ok(Number.isFinite(arg));
      renderTemplate(canvas, template, [], theme, '', false, thumbnail);
    }
  });
}

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';
import sharp from 'sharp';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const native = createRequire(import.meta.url);
function load(file, mocks = {}, cache = new Map()) {
  const absolute = path.resolve(root, file);
  if (cache.has(absolute)) return cache.get(absolute).exports;
  const loaded = { exports: {} }; cache.set(absolute, loaded);
  const compiled = ts.transpileModule(fs.readFileSync(absolute, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, esModuleInterop: true } }).outputText;
  const require = spec => Object.hasOwn(mocks, spec) ? mocks[spec] : spec.startsWith('.') ? load(path.resolve(path.dirname(absolute), spec + '.ts'), mocks, cache) : native(spec);
  new Function('require', 'module', 'exports', compiled)(require, loaded, loaded.exports);
  return loaded.exports;
}
const input = load('app/lib/input.ts');
const req = load('app/lib/request.ts');
const model = load('app/bouquet/model.ts');
const images = load('app/lib/image-file.ts');
const makeRequest = body => new Request('https://mydayflower.com/api/gift', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: typeof body === 'string' ? body : JSON.stringify(body) });

test('email and text rules reject header/control injection while preserving ordinary multilingual prose', () => {
  for (const value of [null, {}, [], 'a@b', 'a..b@example.com', '.a@example.com', 'a@-example.com', 'a@example..com', 'a@example.com\r\nBcc:x@y.com', 'Name <a@example.com>', 'x'.repeat(65) + '@example.com']) assert.equal(input.emailAddress(value), null);
  assert.equal(input.emailAddress(' Love+flowers@Example.COM '), 'love+flowers@example.com');
  assert.equal(input.textInput('愛 💕\nمرحبا', 40, true), '愛 💕\nمرحبا');
  assert.equal(input.textInput('Alex\r\nBcc:bad', 40), 'AlexBcc:bad');
  assert.equal(input.textInput('x'.repeat(1000), 40).length, 40);
});

test('strict bouquet validation rejects forged options, non-finite numbers, oversized fields and unsafe image URLs', () => {
  for (const change of [{ to: 'a\r\nb' }, { from: 'a\u0000b' }, { message: 'x'.repeat(281) }, { border: '1' }, { wrapScale: Infinity }, { background: 900 }, { admin: true }]) assert.equal(model.validateBouquet({ ...model.makeBouquet(), ...change }, true), null);
  const photo = { frame: 0, x: 200, y: 300, angle: 0, scale: 1, zoom: 1, cropX: 50, cropY: 50, caption: '', layer: 'front' };
  for (const src of ['javascript:alert(1)', 'https://example.com/a.png', 'data:image/svg+xml;base64,PHN2Zz4=', 'data:text/html;base64,AAAA']) assert.equal(model.validateBouquet({ ...model.makeBouquet(), photos: [{ ...photo, src }] }, true), null);
  assert.ok(model.validateBouquet({ ...model.makeBouquet(), message: '<script>alert(1)</script> 愛' }, true)); // Rendered as text, never HTML.
  assert.ok(model.validateBouquet(model.makeBouquet()));
});

test('request gate rejects cross-site forms and compressed/non-JSON requests', () => {
  for (const headers of [{ 'Content-Type': 'text/plain' }, { 'Content-Type': 'application/json', Origin: 'https://evil.example' }, { 'Content-Type': 'application/json', 'Sec-Fetch-Site': 'cross-site' }, { 'Content-Type': 'application/json', 'Content-Encoding': 'gzip' }]) assert.throws(() => req.checkRequest(new Request('https://mydayflower.com/api/gift', { method: 'POST', headers })), req.InputError);
  assert.doesNotThrow(() => req.checkRequest(makeRequest({})));
});

test('streaming parser rejects null, arrays, invalid UTF-8, excessive nesting and oversized byte streams', async () => {
  for (const body of ['null', '[]', 'false', '"text"', '{broken', '{"a":' + '['.repeat(20) + '0' + ']'.repeat(20) + '}']) await assert.rejects(req.readJson(makeRequest(body), 1024), req.InputError);
  await assert.rejects(req.readJson(makeRequest({ note: '愛'.repeat(20) }), 32), error => error.status === 413);
  const encoded = new Request('https://mydayflower.com', { method: 'POST', body: new Uint8Array([123, 34, 120, 34, 58, 34, 255, 34, 125]) });
  await assert.rejects(req.readJson(encoded, 100), req.InputError);
  const stream = new ReadableStream({ start(controller) { controller.enqueue(new Uint8Array(30)); controller.enqueue(new Uint8Array(30)); controller.close(); } });
  await assert.rejects(req.readJson(new Request('https://mydayflower.com', { method: 'POST', body: stream, duplex: 'half' }), 50), error => error.status === 413);
  assert.deepEqual(await req.readJson(makeRequest({ email: 'a@example.com' }), 100), { email: 'a@example.com' });
});

test('slow request bodies time out and cancel instead of retaining a worker', async () => {
  let cancelled = false;
  const stream = new ReadableStream({ cancel() { cancelled = true; } });
  await assert.rejects(req.readJson(new Request('https://mydayflower.com', { method: 'POST', body: stream, duplex: 'half' }), 100, 15), error => error.status === 408);
  assert.equal(cancelled, true);
});

test('file headers reject forged MIME and oversized decoded dimensions before browser decoding', async () => {
  const png = await sharp({ create: { width: 8, height: 8, channels: 3, background: '#fff' } }).png().toBuffer();
  assert.equal(images.rasterInfo(png).width, 8);
  const bomb = Buffer.from(png); bomb.writeUInt32BE(100000, 16);
  assert.throws(() => images.rasterInfo(bomb), /24 megapixels/);
  await assert.rejects(images.checkImageFile(new File(['<svg/>'], 'photo.png', { type: 'image/png' }), 1000));
  await assert.rejects(images.checkImageFile(new File([png], 'photo.jpg', { type: 'image/jpeg' }), 1000), /file type/);
  for (const format of ['jpeg', 'webp']) {
    const image = await sharp(png).toFormat(format).toBuffer();
    assert.equal(images.rasterInfo(image).format, format);
  }
});

test('server re-encodes photos and rejects invalid encoded payloads', async () => {
  const { normalizeGiftPhotos } = load('app/lib/gift-photos.ts');
  const png = await sharp({ create: { width: 8, height: 8, channels: 4, background: '#abcd' } }).png().toBuffer();
  const bouquet = { ...model.makeBouquet(), photos: [{ src: 'data:image/png;base64,' + png.toString('base64'), caption: 'A memory' }] };
  const result = await normalizeGiftPhotos(bouquet);
  assert.match(result.photos[0].src, /^data:image\/webp;base64,/);
  assert.equal(result.photos[0].caption, 'A memory');
  await assert.rejects(normalizeGiftPhotos({ ...bouquet, photos: [{ src: 'data:image/png;base64,AAAA' }] }), /photo could not be read/);
});

test('all public POST routes reject malformed objects without sending mail or saving data', async () => {
  let writes = 0;
  const rate = { rateLimit: async () => {} };
  const gift = { saveGift: async () => { writes++; }, loadGift: async () => { writes++; }, MAX_GIFT_BYTES: 1800000 };
  const cases = [
    ['app/api/gift/route.ts', { '../../lib/rate-limit': rate, '../../lib/gift': gift }],
    ['app/api/waitlist/route.ts', { '../../lib/rate-limit': rate }],
    ['app/api/gift/email/route.ts', { '../../../lib/rate-limit': rate, '../../../lib/gift': gift }],
  ];
  for (const [file, mocks] of cases) for (const value of ['null', '[]', '{}', '{"email":{}}', '{"id":"../bad","email":"a@example.com"}']) {
    const response = await load(file, mocks).POST(makeRequest(value));
    assert.equal(response.status, 400, file + ' ' + value);
  }
  assert.equal(writes, 0);
});

test('limiter outage fails closed and spoofed forwarding is ignored off Vercel', async () => {
  const old = { key: process.env.SUPABASE_SERVICE_ROLE_KEY, url: process.env.SUPABASE_URL, vercel: process.env.VERCEL, fetch: global.fetch };
  try {
    process.env.SUPABASE_SERVICE_ROLE_KEY = 'test-only-secret'; process.env.SUPABASE_URL = 'https://database.example'; delete process.env.VERCEL;
    const limiter = load('app/lib/rate-limit.ts');
    const a = new Request('https://mydayflower.com', { headers: { 'X-Forwarded-For': '1.1.1.1' } });
    const b = new Request('https://mydayflower.com', { headers: { 'X-Forwarded-For': '2.2.2.2' } });
    assert.equal(limiter.senderKey(a), limiter.senderKey(b));
    global.fetch = async () => new Response('unavailable', { status: 503 });
    await assert.rejects(limiter.rateLimit(a, 'gift-create'), /unavailable/);
    global.fetch = async () => Response.json(false);
    await assert.rejects(limiter.rateLimit(a, 'gift-create'), error => error.status === 429);
    global.fetch = async () => Response.json(true);
    await assert.doesNotReject(limiter.rateLimit(a, 'gift-create'));
  } finally {
    global.fetch = old.fetch;
    for (const [name, value] of [['SUPABASE_SERVICE_ROLE_KEY', old.key], ['SUPABASE_URL', old.url], ['VERCEL', old.vercel]]) { if (value === undefined) delete process.env[name]; else process.env[name] = value; }
  }
});


test('email CAPTCHA fails closed on missing, forged, replayed, wrong-host and wrong-action tokens', async () => {
  const old = { secret: process.env.TURNSTILE_SECRET_KEY, node: process.env.NODE_ENV, fetch: global.fetch };
  const { verifyDelivery } = load('app/lib/turnstile.ts');
  try {
    process.env.NODE_ENV = 'production'; process.env.TURNSTILE_SECRET_KEY = 'test-secret';
    let requests = 0;
    global.fetch = async () => { requests++; throw new Error('unexpected network'); };
    for (const token of [undefined, null, {}, '', 'x'.repeat(2049), 'two words']) await assert.rejects(verifyDelivery(token), e => e.status === 403);
    assert.equal(requests, 0);
    delete process.env.TURNSTILE_SECRET_KEY;
    await assert.rejects(verifyDelivery('token'), e => e.status === 503);
    process.env.TURNSTILE_SECRET_KEY = 'test-secret';
    for (const result of [null, {}, { success: false, 'error-codes': ['timeout-or-duplicate'] }, { success: true, hostname: 'attacker.example', action: 'gift-email' }, { success: true, hostname: 'localhost', action: 'gift-email' }, { success: true, hostname: 'mydayflower.com', action: 'login' }]) {
      global.fetch = async () => Response.json(result);
      await assert.rejects(verifyDelivery('token'), e => e.status === 403);
    }
    global.fetch = async () => new Response('unavailable', { status: 503 });
    await assert.rejects(verifyDelivery('token'), e => e.status === 503);
    global.fetch = async () => { throw new Error('timeout'); };
    await assert.rejects(verifyDelivery('token'), e => e.status === 503);
    global.fetch = async (url, options) => {
      assert.equal(url, 'https://challenges.cloudflare.com/turnstile/v0/siteverify');
      assert.deepEqual(JSON.parse(options.body), { secret: 'test-secret', response: 'token' });
      return Response.json({ success: true, hostname: 'mydayflower.com', action: 'gift-email' });
    };
    await assert.doesNotReject(verifyDelivery('token'));
  } finally {
    global.fetch = old.fetch;
    for (const [key, value] of [['TURNSTILE_SECRET_KEY', old.secret], ['NODE_ENV', old.node]]) { if (value === undefined) delete process.env[key]; else process.env[key] = value; }
  }
});

test('email endpoint verifies before accessing the gift or sending mail', async () => {
  const old = { fetch: global.fetch, secret: process.env.TURNSTILE_SECRET_KEY, resend: process.env.RESEND_API_KEY, from: process.env.BOUQUET_EMAIL_FROM };
  try {
    process.env.TURNSTILE_SECRET_KEY = 'test-secret'; process.env.RESEND_API_KEY = 'test-resend'; process.env.BOUQUET_EMAIL_FROM = 'test@example.com';
    let gifts = 0, mails = 0, claims = 0, valid = false;
    const route = load('app/api/gift/email/route.ts', {
      '../../../lib/rate-limit': { rateLimit: async () => { claims++; } },
      '../../../lib/gift': { loadGift: async () => { gifts++; return model.makeBouquet(); } },
    });
    global.fetch = async url => {
      if (url.includes('siteverify')) return Response.json({ success: valid, hostname: 'mydayflower.com', action: 'gift-email' });
      assert.equal(url, 'https://api.resend.com/emails'); mails++; return Response.json({ id: 'test-mail' });
    };
    const body = { id: 'abcdefghijkl', email: 'test@example.com' };
    assert.equal((await route.POST(makeRequest(body))).status, 403);
    assert.equal((await route.POST(makeRequest({ ...body, token: 'replayed' }))).status, 403);
    assert.equal(gifts, 0); assert.equal(mails, 0);
    valid = true;
    assert.equal((await route.POST(makeRequest({ ...body, token: 'valid' }))).status, 200);
    assert.equal(gifts, 1); assert.equal(mails, 1); assert.equal(claims, 3);
  } finally {
    global.fetch = old.fetch;
    for (const [key, value] of [['TURNSTILE_SECRET_KEY', old.secret], ['RESEND_API_KEY', old.resend], ['BOUQUET_EMAIL_FROM', old.from]]) { if (value === undefined) delete process.env[key]; else process.env[key] = value; }
  }
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { sendSignupNotice } from './send-signup-notice.ts';

const settings = { resendKey: 'test-key', from: 'Dayflower <hello@example.com>' };

test('missing mail configuration does not attempt a signup alert', async () => {
  assert.equal(await sendSignupNotice('visitor@example.com', {}, () => { throw Error('Unexpected request'); }), false);
});

test('signup alert goes to the operator with the new address', async () => {
  let request;
  const accepted = await sendSignupNotice('visitor@example.com', settings, async (url, init) => {
    request = { url, init };
    return new Response(JSON.stringify({ id: 'sent-123' }), { status: 200 });
  });
  assert.equal(accepted, true);
  assert.equal(request.url, 'https://api.resend.com/emails');
  const body = JSON.parse(request.init.body);
  assert.deepEqual(body.to, ['app.dayflower@gmail.com']);
  assert.match(body.text, /visitor@example\.com/);
});

test('mail-provider rejection does not claim the operator was notified', async () => {
  assert.equal(await sendSignupNotice('visitor@example.com', settings, async () => new Response('{}', { status: 429 })), false);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { sendConfirmation } from './send-confirmation.ts';
import { html, text, subject } from './waitlist-confirmation.ts';
const settings = { supabaseUrl: 'https://database.example', serviceKey: 'server-test-key', resendKey: 'email-test-key', from: 'Dayflower <hello@example.com>' };
const template = { html, text, subject };
const response = (data, status=200) => new Response(JSON.stringify(data), {status});

test('missing configuration never attempts delivery', async () => {
  assert.equal(await sendConfirmation('test@example.com', template, {}, () => { throw Error('Unexpected network'); }), 'unavailable');
});
test('accepted signup is not emailed again', async () => {
  let calls=0;
  assert.equal(await sendConfirmation('test@example.com', template, settings, async () => { calls++; return response([{signup_id:'abc',delivery_state:'accepted'}]); }), 'accepted');
  assert.equal(calls,1);
});
test('in-flight claim prevents concurrent send', async () => {
  let calls=0;
  assert.equal(await sendConfirmation('test@example.com', template, settings, async () => { calls++; return response([{signup_id:'abc',delivery_state:'pending'}]); }), 'pending');
  assert.equal(calls,1);
});
test('new claim sends HTML and text with stable idempotency and saves receipt', async () => {
  const calls=[];
  const status=await sendConfirmation('test@example.com', template, settings, async (url,init) => {
    calls.push({url,init});
    if(calls.length===1) return response([{signup_id:'abc',delivery_state:'claimed'}]);
    if(calls.length===2) return response({id:'receipt-123'});
    return response({});
  });
  assert.equal(status,'accepted'); assert.equal(calls.length,3);
  assert.equal(calls[1].init.headers['Idempotency-Key'],'waitlist-confirmation-v1/abc');
  const body=JSON.parse(calls[1].init.body);
  assert.deepEqual(body.to,['test@example.com']); assert.ok(body.html.includes('You’re on the list')); assert.ok(body.text.includes('Your waitlist signup is saved'));
  assert.equal(JSON.parse(calls[2].init.body).confirmation_provider_id,'receipt-123');
});
test('provider rejection preserves signup and reports pending, without receipt update', async () => {
  let calls=0;
  assert.equal(await sendConfirmation('test@example.com',template,settings,async () => ++calls===1 ? response([{signup_id:'abc',delivery_state:'claimed'}]) : response({error:'rate limited'},429)), 'pending');
  assert.equal(calls,2);
});
test('network timeout does not claim delivery', async () => {
  assert.equal(await sendConfirmation('test@example.com',template,settings,async () => { throw Error('timeout'); }), 'pending');
});

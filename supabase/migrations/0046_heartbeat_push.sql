-- Heartbeats reach a phone whose app is closed.
--
-- 🔴 **This reverses the decision in 0031**, which left `heartbeats` out of
-- the push trigger on the grounds that they were the highest-volume table in
-- the app and a push per tap would be both the loudest thing in it and the
-- largest driver of edge function invocations.
--
-- The volume held up; the conclusion did not. Measured 2026-09-14: 405 taps
-- all time since 2026-07-08, 215 in the last 30 days, 71 in the last 7, for
-- the one real pair. Against the 2M monthly invocations Pro includes that is
-- **0.01%** -- and a hundred pairs sending at the same rate would be 1%. The
-- table is the busiest in the app and still nowhere near the number that
-- worried 0031.
--
-- The other half of that objection -- that a heart would become the loudest
-- thing in the app -- was real, and is answered on the phone rather than
-- here: PulseAlerts accumulates taps into one notification and will not make
-- a sound more than once every thirty seconds. See its header.
--
-- ⚠️ **No debounce here, deliberately, and 0031 suggested one.** A trigger
-- that dropped taps would make the count on the phone wrong: the app reports
-- "sent you 5 heartbeats" by counting what arrived, so a server that
-- silently swallowed four of them would report one. Collapsing belongs where
-- the counting happens.
--
-- Without this a heart sent to a killed app did nothing at all, ever -- no
-- buzz, no notification -- and the sender had no way to know.

create or replace function public.notify_heartbeat_push()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'push_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'push_secret';

  -- Not configured is a normal state, not an error. The tap that fired this
  -- must never fail because push is half set up -- same rule as notify_push.
  if v_url is null or v_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret
    ),
    body := jsonb_build_object(
      'message_id', new.id,
      'pair_id', new.pair_id,
      'sender_id', new.sender_id,
      'kind', 'heartbeat',
      'call_mode', null,
      -- ⚠️ Load-bearing. A backgrounded-but-alive app receives the same tap
      -- twice: once over realtime and once as a push. The phone keeps a mark
      -- of the newest tap it has already announced, and this is what the two
      -- paths compare against so one heart is never counted as two.
      'sent_at_ms', (extract(epoch from new.sent_at) * 1000)::bigint
    ),
    timeout_milliseconds := 4000
  );

  return new;
end $$;

drop trigger if exists heartbeats_push on public.heartbeats;
create trigger heartbeats_push
  after insert on public.heartbeats
  for each row
  execute function public.notify_heartbeat_push();

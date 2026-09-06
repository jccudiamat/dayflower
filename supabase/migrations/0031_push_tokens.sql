-- Dayflower — the phone can finally be woken.
--
-- ⚠️ Renumbered 0028 → 0031. Two sessions ran in parallel and both took 0028
-- (the other was 0028_day_photo_limit). Both were applied and neither
-- conflicts, but a duplicate number makes "what ran, in what order" a guess.
-- This file is additive and re-runnable, so moving it costs nothing.
-- Run in the Supabase SQL editor, or: dart run tool/run_sql.dart <this file>
--
-- Safe to re-run. Additive only.
--
-- ## What this closes
--
-- Everything social in this app has been invisible with the app shut. Not
-- just calls: `PartnerAlerts.messages()` and `.activity()` are driven from
-- `app.dart` off the app's *own* realtime subscription, so they need the
-- process alive and the socket connected. Backgrounded a moment ago: works.
-- Swiped away, or deep into Doze: nothing, until the app is next opened.
-- Reminder alarms were the sole exception, and only because they are
-- scheduled locally by the OS rather than triggered by anything arriving.
--
-- So this is not a calling feature. It is the missing half of messages,
-- flowers, day photos and calls alike, and one path switches them all on.

create extension if not exists pg_net with schema extensions;

-- ── Where to send ─────────────────────────────────────────────────────────
--
-- One row per device, not per user: the same person may be on a phone and a
-- tablet, and a stale token from a wiped device must be droppable without
-- taking the account's other devices with it.
create table if not exists public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'android'
    check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_idx
  on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- Yours only, in both directions. ⚠️ A device token is not a secret in the
-- usual sense, but it *is* a capability: anyone holding it can be sent
-- notifications addressed to that phone. Readable-by-partner would be a
-- pointless widening — the sender is the edge function, running as service
-- role, which bypasses all of this anyway.
drop policy if exists "device_tokens_own" on public.device_tokens;
create policy "device_tokens_own" on public.device_tokens
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update, delete on public.device_tokens to authenticated;

-- ⚠️ Grants, again — RLS decides which rows, the grant decides whether the
-- role may touch the table at all. See PROGRESS.md § Supabase.

-- ── How the send is triggered ─────────────────────────────────────────────
--
-- A Postgres trigger calling the edge function through `pg_net`, rather than
-- a dashboard-configured Database Webhook. Both work; this one is in a
-- migration, which means it is reviewable, re-runnable and visible to
-- whoever reads this folder next. A webhook configured by hand in a UI is a
-- piece of production behaviour that exists nowhere in the repo.
--
-- 🔴 **The URL and secret are NOT in this file.** Create them once, in the
-- SQL editor, so they stay out of git and out of any transcript:
--
--   select vault.create_secret(
--     'https://<project-ref>.supabase.co/functions/v1/push', 'push_url');
--   select vault.create_secret('<a long random string>', 'push_secret');
--
-- The same random string goes into the function's own env as PUSH_SECRET.
-- It is what stops anyone who finds the function URL from spraying
-- notifications at your users.
create or replace function public.notify_push()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_url text;
  v_secret text;
  v_kind text;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'push_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'push_secret';

  -- Not configured yet is a normal state, not an error. The insert that
  -- fired this must never fail because push is half set up — a message that
  -- did not notify is a lesser failure than a message that did not send.
  if v_url is null or v_secret is null then
    return new;
  end if;

  v_kind := case
    when new.call_mode is not null then 'call'
    when new.image_path is not null then 'photo'
    when new.flower_type is not null then 'flower'
    else 'message'
  end;

  -- ⚠️ Only *new* calls ring. A call row is updated when it ends, and this
  -- is an INSERT trigger, so that is already true — but it is the kind of
  -- thing a later UPDATE trigger would break silently, so it is said here.
  perform extensions.net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret
    ),
    body := jsonb_build_object(
      'message_id', new.id,
      'pair_id', new.pair_id,
      'sender_id', new.sender_id,
      'kind', v_kind,
      'call_mode', new.call_mode
    ),
    timeout_milliseconds := 4000
  );

  return new;
end $$;

drop trigger if exists flower_messages_push on public.flower_messages;
create trigger flower_messages_push
  after insert on public.flower_messages
  for each row
  -- Home-screen-only day photos never reach the conversation, so they have
  -- nothing to announce.
  when (new.to_chat = true)
  execute function public.notify_push();

-- ⚠️ **Heartbeats deliberately do NOT fire this.**
--
-- They are the highest-volume table in the app — 316 rows against 124
-- messages for the one real pair, measured 2026-09-06 — so a push per tap
-- would be both the loudest thing in the app and the largest driver of edge
-- function invocations (Pro includes 2M/month). A heart is an ambient
-- gesture; it is meant to be found, not to interrupt. If it ever should
-- notify, debounce it to at most one per pair per hour.

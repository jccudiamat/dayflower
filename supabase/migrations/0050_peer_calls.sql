-- Calls go phone to phone, and the chat learns to say "typing…".
--
-- Run as one script. Safe to re-run.
--
-- 🔴 **Why this replaces the media server.** Every room in this app has
-- exactly two people in it, always, by construction (`roomFor` derives one
-- room per pair). An SFU exists to mix and forward many participants; with
-- two it is a very expensive wire. Modelled at 5,000 pairs the SFU was
-- ~$5,000/month and about 90% of the whole running cost. Two phones talking
-- directly cost nothing at all, and the quarter of calls that cannot reach
-- each other need a TURN relay, which is one small VPS.
--
-- What the database does here is the part that cannot be done on the phone:
-- deciding **who may talk to whom**, and handing out relay credentials that
-- expire.
--
-- ⚠️ Nothing here carries media. Offers, answers and ICE candidates go over
-- Realtime broadcast, which is ephemeral: no rows, no storage, nothing kept
-- after the call. That is deliberate — a table of ICE candidates would be
-- millions of rows a month describing connections that no longer exist.

-- ════════════════════════════════════════════════════════════════════
-- 1. Who may join a pair's private channel
-- ════════════════════════════════════════════════════════════════════
--
-- Topics are `<what>:<pair_id>`: `call:<uuid>` for the offer/answer/ICE
-- exchange, `typing:<uuid>` for the chat's typing indicator. Both are
-- private channels, so Realtime checks `realtime.messages` under RLS before
-- it will let a client receive or send on one.
--
-- 🔴 **"Nobody will guess a uuid" is not a privacy model** — the same rule
-- migration 0020 records for the avatars bucket. Without these policies a
-- private channel is refused outright (good), and a *public* one would let
-- anyone who learned a pair id listen to a couple's call setup.

create or replace function public.is_my_pair_topic(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_pair uuid;
begin
  if v_uid is null or p_topic is null then
    return false;
  end if;

  -- ⚠️ `substring` returns NULL for a non-match, and `null::uuid` is NULL
  -- rather than an error, so the null test below is what actually rejects a
  -- malformed topic. The handler only catches a well-shaped topic whose
  -- tail is not a uuid. Same trap as `livekit_token` in 0026.
  begin
    v_pair := substring(p_topic from '^(?:call|typing):(.+)$')::uuid;
  exception when others then
    return false;
  end;

  if v_pair is null then
    return false;
  end if;

  return exists (
    select 1 from public.pairs p
     where p.id = v_pair
       and v_uid in (p.user_a, p.user_b)
  );
end $$;

grant execute on function public.is_my_pair_topic(text) to authenticated;

-- ⚠️ No `alter table realtime.messages enable row level security` here: it
-- is already on, and the table belongs to Supabase's own role, so trying
-- fails with "must be owner of table messages". Policies on it we may add.

-- Receiving, and sending. Both halves are needed: without the insert policy
-- a phone can hear an offer and never answer it.
drop policy if exists "pair_topics_read" on realtime.messages;
create policy "pair_topics_read" on realtime.messages
  for select to authenticated
  using (public.is_my_pair_topic(realtime.topic()));

drop policy if exists "pair_topics_write" on realtime.messages;
create policy "pair_topics_write" on realtime.messages
  for insert to authenticated
  with check (public.is_my_pair_topic(realtime.topic()));

-- ════════════════════════════════════════════════════════════════════
-- 2. Where to reach each other
-- ════════════════════════════════════════════════════════════════════
--
-- ⚠️ **Not here.** STUN and the TURN relay are handed out by the `turn`
-- edge function, not by this database, and that is not a style choice:
-- Cloudflare mints relay credentials over HTTP, and Postgres only has
-- `pg_net`, which is queued and asynchronous, so it cannot answer a phone
-- that is waiting for an answer.
--
-- A self-hosted coturn *could* be signed here with `pgcrypto` the way
-- `livekit_token` is signed in 0026. It deliberately is not: two
-- implementations of "where do we relay" is how the two drift apart.
--
-- See supabase/functions/turn/index.ts.

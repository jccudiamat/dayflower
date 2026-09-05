-- Dayflower — a call is a message.
-- Run in the Supabase SQL editor, or: dart run tool/run_sql.dart <this file>
--
-- Safe to re-run. Additive only.
--
-- The chat header has had a phone and a camera icon since the thread was
-- built; both have always answered with a "coming soon" snackbar. This is
-- what makes them do something.
--
-- ## Why a call lives in `flower_messages` and not in a `calls` table
--
-- Because the *invitation* is the feature, not the media. Notifications in
-- this app are local-only — a backgrounded phone cannot be rung (see
-- PROGRESS.md § Notifications). So the reliable path to "let's talk" is the
-- one that already works: a row in the thread, delivered by the realtime
-- stream the chat is already subscribed to, counted by the unread badge,
-- and raised as a local notification if the app happens to be alive.
--
-- Putting calls in their own table would mean a second stream, a second
-- unread rule, and a second notification path — for something that is, in
-- the end, one line in a conversation that says "I'm here, come talk".
-- When push arrives it rings on top of this; it does not replace it.

-- Null on every row that is not a call. 'voice' or 'video'.
--
-- Free text with a CHECK rather than a Postgres enum, matching `avatar` and
-- `mood`: an enum needs its own migration to gain a value, and the Dart
-- side already treats an unrecognised string as "not a call I understand"
-- rather than crashing the decode.
alter table public.flower_messages
  add column if not exists call_mode text;

alter table public.flower_messages
  drop constraint if exists flower_messages_call_mode;
alter table public.flower_messages
  add constraint flower_messages_call_mode check (
    call_mode is null or call_mode in ('voice', 'video')
  );

-- The room both phones join. Derived from the pair, not random: see
-- `CallRepository.roomFor` — a deterministic name is what lets the partner
-- walk into the same call from an old bubble without a handshake.
--
-- Stored anyway rather than recomputed, because the derivation is allowed
-- to change (a new provider, a new prefix) and a call started under the old
-- scheme must stay joinable from its own row.
alter table public.flower_messages
  add column if not exists call_room text;

-- Null while the call is live. `sent_at` is when it started, so the
-- duration is a subtraction and is never stored.
alter table public.flower_messages
  add column if not exists call_ended_at timestamptz;

-- ⚠️ **The content check had to be relaxed.** A call row carries no flower,
-- no photo and no text — under the 0013 constraint every insert would fail
-- with 23514 and the call button would look broken for a reason nothing in
-- the Dart could explain. Replaces the 0013 constraint.
alter table public.flower_messages
  drop constraint if exists flower_messages_has_content;
alter table public.flower_messages
  add constraint flower_messages_has_content check (
    flower_type is not null
    or image_path is not null
    or call_mode is not null
    or (note is not null and length(btrim(note)) > 0)
  );

-- "Is there a live call in this thread right now" — asked on every open of
-- the chat, and by the header to decide whether the icons mean "start" or
-- "join". Partial, because live calls are a vanishing fraction of the rows.
create index if not exists flower_live_call_idx
  on public.flower_messages (pair_id, sent_at desc)
  where call_mode is not null and call_ended_at is null;

-- ── Hanging up ────────────────────────────────────────────────────────────
--
-- 🔴 **The caller cannot end their own call under the existing policies.**
-- 0001's update policy is recipient-only — deliberately, because updates are
-- how a message is marked seen and marking your own message seen is
-- meaningless. But hanging up is an update to a row you sent, by you.
--
-- Widening that policy would let either member write *any* column on a call
-- row, which buys a hang-up at the price of the read-receipt guarantee.
-- This is a definer function instead: it writes one column, on one kind of
-- row, and only for a pair you belong to.
create or replace function public.end_call(p_message_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ended timestamptz;
begin
  update public.flower_messages m
     set call_ended_at = now()
   where m.id = p_message_id
     and m.call_mode is not null
     -- Idempotent: a second hang-up (both sides tapping End, or a retry
     -- after a dropped response) keeps the first timestamp rather than
     -- stretching the call to whenever the last packet arrived.
     and m.call_ended_at is null
     -- Membership, checked here because the definer bypasses RLS.
     and exists (
       select 1 from public.pairs p
        where p.id = m.pair_id
          and auth.uid() in (p.user_a, p.user_b)
     )
  returning m.call_ended_at into v_ended;

  -- Already ended, or not ours to end. Both read back as "the call is over",
  -- which is the truthful answer to a hang-up either way.
  if v_ended is null then
    select m.call_ended_at into v_ended
      from public.flower_messages m
     where m.id = p_message_id;
  end if;

  return v_ended;
end $$;

revoke all on function public.end_call(uuid) from public;
grant execute on function public.end_call(uuid) to authenticated;

-- ⚠️ Grants, again. Every table-touching object in this project has needed
-- an explicit grant to `authenticated` — RLS decides *which rows*, the grant
-- decides whether the role may touch the table at all, and Supabase's
-- defaults have not covered new objects here. See PROGRESS.md § Supabase.

-- Realtime already covers this: `flower_messages` has been in the
-- publication since 0009, which is exactly why a call can be modelled as a
-- message and arrive on the other phone for free.

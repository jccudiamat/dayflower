-- 0054: a call is for two, so when it ends it is over for both, and a call
-- nobody answered reads as missed whoever closed it.
--
-- Reported on build 123:
--   * A call ended by one side could still be joined afterwards.
--   * A call the caller cancelled while it rang showed the seconds spent
--     ringing, as if it had been a (very short) conversation, instead of as
--     a missed call.
--
-- Two changes, both re-creating a function whole (create or replace keeps
-- the grants).

-- ── miss_call: either side may close an unanswered call ───────────────────
--
-- Was the caller's alone, for the ring-out timer. Now the app also calls it
-- whenever a call ends before anyone picked up: the caller cancelling, the
-- receiver declining (from the ring screen or the notification, with the app
-- closed). Only the app knows the call was never answered, so it chooses
-- between this and end_call; this still never overwrites a real ending.
create or replace function public.miss_call(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.flower_messages m
     set call_ended_at = m.sent_at
   where m.id = p_message_id
     and m.call_mode is not null
     -- Idempotent, and it never overwrites a real ending. If the call was
     -- answered in the second before this, that answer wins.
     and m.call_ended_at is null
     -- Membership, checked here because the definer bypasses RLS. Either of
     -- the two may close it: the caller cancelling, or the receiver saying
     -- no.
     and exists (
       select 1 from public.pairs p
        where p.id = m.pair_id
          and auth.uid() in (p.user_a, p.user_b)
     );
end $$;

comment on function public.miss_call(uuid) is
  'Closes a call that was never answered, with an end equal to its start so '
  'the thread reads it as missed rather than as a duration. Either member.';

-- ── livekit_token: only while a call is up ────────────────────────────────
--
-- Identical to 0026 but for one check: a token is signed only while the
-- pair has a live call row (not ended, and inside the same two-hour window
-- FlowerMessage.isLiveCall uses). The room is named after the pair, so
-- without this a stale screen, a late notification, or a Join bubble could
-- walk back into a room after the call in it had ended. The app checks too;
-- this is the check that holds whatever the app does.
create or replace function public.livekit_token(p_room text)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_pair uuid;
  v_key text;
  v_secret text;
  v_name text;
  v_now bigint := extract(epoch from now())::bigint;
begin
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  -- The room must name a pair, and it must be one of ours. Parsed rather
  -- than trusted: the room arrives from the client. See 0026 for why the
  -- null test, not the handler, is what rejects a malformed room.
  begin
    v_pair := substring(p_room from '^dayflower-v1-(.+)$')::uuid;
  exception when others then
    v_pair := null;
  end;

  if v_pair is null then
    raise exception 'unrecognised room';
  end if;

  if not exists (
    select 1 from public.pairs p
     where p.id = v_pair
       and v_uid in (p.user_a, p.user_b)
  ) then
    raise exception 'not your room';
  end if;

  -- 🔴 A call to be in. The app reads this message and says the call has
  -- ended (LiveKitCallTransport), so keep the wording.
  if not exists (
    select 1 from public.flower_messages m
     where m.pair_id = v_pair
       and m.call_mode is not null
       and m.call_ended_at is null
       and m.sent_at > now() - interval '2 hours'
  ) then
    raise exception 'call has ended';
  end if;

  select decrypted_secret into v_key
    from vault.decrypted_secrets where name = 'livekit_api_key';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'livekit_api_secret';

  if v_key is null or v_secret is null then
    -- Distinct from every other failure here: this one means the operator
    -- has not finished setting calling up. The app turns it into "calling
    -- isn't switched on yet".
    raise exception 'calling not configured';
  end if;

  select coalesce(pet_name, display_name, 'Someone') into v_name
    from public.users where id = v_uid;

  return extensions.sign(
    json_build_object(
      'iss', v_key,
      'sub', v_uid::text,
      'name', v_name,
      'nbf', v_now - 10,          -- clock skew between phone and server
      'exp', v_now + 60 * 60 * 6, -- long enough to outlast any real call
      'video', json_build_object(
        'room', p_room,
        'roomJoin', true,
        'canPublish', true,
        'canSubscribe', true,
        'canPublishData', true
      )
    ),
    v_secret
  );
end $$;

revoke all on function public.livekit_token(text) from public;
grant execute on function public.livekit_token(text) to authenticated;
revoke all on function public.miss_call(uuid) from public;
grant execute on function public.miss_call(uuid) to authenticated;

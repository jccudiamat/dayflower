-- A call nobody picked up.
--
-- 0025's `end_call` stamps `call_ended_at = now()`, which is right for a call
-- that happened and wrong for one that did not: sixty seconds of ringing
-- would be reported in the thread as a sixty-second conversation. The row has
-- no other way to tell the two apart — there is no `answered_at` — so this
-- writes the one timestamp that cannot be mistaken for a duration.
--
-- WHY `sent_at` AND NOT A NEW COLUMN: a call whose end is exactly its
-- beginning lasted no time at all, which is the literal truth about a call
-- that was never answered. Every answered call has real seconds in it — the
-- transport has to negotiate media before the timer even starts — so zero is
-- a value the answered path cannot produce. A column would say it more
-- loudly and would also mean a migration on a table two features already
-- read; this says it exactly.
--
-- Client side reads it as `callDuration == Duration.zero`. See
-- FlowerMessage.wasMissed.

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
     -- answered in the second before the timeout fired, that answer wins.
     and m.call_ended_at is null
     -- Only the person who placed it can miss it. The receiver declining is
     -- a different act and already goes through end_call.
     and m.sender_id = auth.uid()
     -- Membership, checked here because the definer bypasses RLS.
     and exists (
       select 1 from public.pairs p
        where p.id = m.pair_id
          and auth.uid() in (p.user_a, p.user_b)
     );
end $$;

revoke all on function public.miss_call(uuid) from public;
grant execute on function public.miss_call(uuid) to authenticated;

comment on function public.miss_call(uuid) is
  'Closes a call that was never answered, with an end equal to its start so '
  'the thread reads it as "no answer" rather than as a duration.';

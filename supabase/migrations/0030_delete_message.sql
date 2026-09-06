-- Taking back something you sent.
--
-- Hard delete, not a tombstone. A "this message was deleted" placeholder is
-- the right answer in a group, where the absence would otherwise confuse a
-- conversation other people are still reading. Here there are two of you: a
-- deleted message leaves a gap only one other person will ever see, and they
-- were there. A permanent grey stub saying something used to be here is a
-- worse artefact than the gap.
--
-- WARNING: replies survive it. `flower_messages.reply_to` is
-- `on delete set null` (0023, and deliberately never cascade) — taking your
-- photo back must not delete their reply to it, because they said something
-- and it is theirs. The quote in the bubble degrades to "message
-- unavailable" instead.
--
-- WHY A FUNCTION, AGAIN: 0004 grants update only to the *recipient* and
-- grants delete to nobody. A delete policy for senders would be the right
-- shape here, but every other write in this feature already goes through a
-- definer function, and a policy plus this function would be two places to
-- read when asking "who can remove a message".
--
-- Returns the storage path so the caller can clean up the object. The row is
-- the record; the file is just bytes, and orphaned bytes in a private bucket
-- cost money and tell no story.

create or replace function public.delete_message(p_message_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_path text;
begin
  delete from public.flower_messages m
   where m.id = p_message_id
     -- Only your own. A definer function bypasses RLS, so this predicate IS
     -- the access control — there is nothing behind it.
     and m.sender_id = auth.uid()
     -- Membership, checked here for the same reason.
     and exists (
       select 1 from public.pairs p
        where p.id = m.pair_id
          and auth.uid() in (p.user_a, p.user_b)
     )
  returning m.image_path into v_path;

  return v_path;
end $$;

revoke all on function public.delete_message(uuid) from public;
grant execute on function public.delete_message(uuid) to authenticated;

comment on function public.delete_message(uuid) is
  'Removes one of your own messages for both of you, and returns its storage '
  'path so the object can be cleaned up. Replies to it survive with a null '
  'reply_to.';

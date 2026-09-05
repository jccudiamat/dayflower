-- My Days: retiring one without touching anything else about it.
--
-- A day photo is a `flower_messages` row with an image and `to_widget`.
-- Keeping at most seven live means the eighth has to push the oldest out —
-- but "out" is only ever *off the widget*. The message stays in the thread
-- forever, which is the whole point of the feature and the reason this is
-- not a delete.
--
-- WHY A FUNCTION AND NOT A POLICY: 0004's only update policy is
-- `flowers_update_recipient` — the *recipient* may mark a message seen, and
-- the sender may not update their own rows at all. That is a good rule: a
-- sent message is not a draft. Widening it so a sender could update their
-- own row would let them rewrite the note, the flower, the timestamp —
-- everything — because RLS grants a row, not a column, and the only way
-- back would be another lock trigger like `pairs_lock_identity`.
--
-- One definer function that flips one boolean is narrower than either.
-- Same shape as `end_call` in 0025.

create or replace function public.retire_day_photo(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.flower_messages
     set to_widget = false
   where id = p_message_id
     -- Only your own, and only a photo. A definer function bypasses RLS, so
     -- this predicate IS the access control — there is nothing behind it.
     and sender_id = auth.uid()
     and image_path is not null;
end;
$$;

revoke all on function public.retire_day_photo(uuid) from public;
grant execute on function public.retire_day_photo(uuid) to authenticated;

comment on function public.retire_day_photo(uuid) is
  'Takes one of your own day photos off the home-screen widget. The message '
  'itself stays in the conversation.';

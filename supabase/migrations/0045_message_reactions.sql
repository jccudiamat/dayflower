-- React to a message in the conversation.
--
-- One reaction per person per message, which is the whole design. There are
-- two people here, so a message carries at most two marks -- his and hers --
-- and a row is naturally addressed by (message_id, user_id). Tapping the
-- same emoji again removes it; tapping a different one moves it. The same
-- toggle the mood chip uses, for the same reason: anything you can say about
-- yourself you must be able to take back.
--
-- ⚠️ **Its own table, not a column on `flower_messages`.** 0004 lets only the
-- *recipient* update a message, deliberately -- a sent message is not a
-- draft. Widening that so either side could write a reactions column would
-- hand them the note, the flower and the timestamp too, because RLS grants a
-- row and not a column. The same reasoning as `retire_day_photo` in 0028.
--
-- ⚠️ **In the realtime publication, unlike `presence`.** A reaction is rare,
-- tiny, and only ever happens while somebody is looking at the thread -- the
-- opposite of a once-a-minute ping. Polling it would mean asking constantly
-- for something that almost never changes.

create table if not exists public.message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.flower_messages (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  -- Denormalised from the message on purpose: `.stream()` can filter on one
  -- indexed column, and the thread needs "every reaction in this pair" in a
  -- single subscription. Reaching through to flower_messages would mean a
  -- subscription per message.
  pair_id uuid not null references public.pairs (id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  reacted_at timestamptz not null default now(),
  -- One per person per message. This is what makes the upsert a *move*
  -- rather than a second mark piling up beside the first.
  unique (message_id, user_id)
);

create index if not exists message_reactions_pair_idx
  on public.message_reactions (pair_id);

alter table public.message_reactions enable row level security;

-- Both halves of the couple can see every reaction on their own thread.
create policy "reactions_select_pair_members" on public.message_reactions
  for select using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Writing is self-only, and only into your own pair. Both conditions
-- matter: the first stops you reacting as your partner, the second stops a
-- pair_id from somebody else's conversation being posted at all.
create policy "reactions_insert_self" on public.message_reactions
  for insert with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- ⚠️ Update as well as insert, or the upsert that *moves* a reaction from
-- one emoji to another silently does nothing -- the same failure the
-- presence table hit in 0043.
create policy "reactions_update_self" on public.message_reactions
  for update using (auth.uid() = user_id);

create policy "reactions_delete_self" on public.message_reactions
  for delete using (auth.uid() = user_id);

-- Live on the other phone. Wrapped because re-running a migration that adds
-- a table already in the publication is an error, not a no-op.
do $$
begin
  alter publication supabase_realtime add table public.message_reactions;
exception
  when duplicate_object then null;
end $$;

-- 🔴 **Removing a reaction is a DELETE, and DELETE needs the whole old row.**
--
-- Caught on the first try of the toggle: the row really was deleted, and the
-- emoji stayed on screen anyway. Realtime evaluates the SELECT policy
-- against the *old* tuple before it forwards a change, and with the default
-- replica identity that tuple is only the primary key -- so `pair_id` was
-- null, "am I in this pair" could not be true, and the event was dropped as
-- one this client is not allowed to see. The phone was told nothing, so it
-- kept showing a reaction that no longer existed until the thread was
-- rebuilt from scratch.
--
-- FULL makes the old tuple carry every column, which is what the policy
-- needs to pass. Affordable precisely because this table is tiny: four
-- small columns, and a row is written only when somebody presses a message.
alter table public.message_reactions replica identity full;

-- Dayflower — Settings: allow a partner to disconnect the pair.
-- Run in the Supabase SQL editor as one script. Safe to re-run.

-- Deleting a pair CASCADES to flower_messages, heartbeats and reunions
-- (all reference pairs.id with on delete cascade). Disconnecting therefore
-- erases the couple's shared history — the UI must say so plainly.
drop policy if exists "pairs_delete_involved" on public.pairs;

create policy "pairs_delete_involved" on public.pairs
  for delete using (
    auth.uid() = user_a or auth.uid() = user_b
  );

-- Dayflower MVP — Feature 4: Reunion Countdown
-- Run in the Supabase SQL editor as one script. Safe to re-run
-- (drop-and-recreate; dev data only).

drop table if exists public.reunions cascade;

create table public.reunions (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null unique references public.pairs (id) on delete cascade,
  title text not null default 'Reunion',
  destination text,
  happens_at timestamptz not null,
  note text,
  updated_at timestamptz not null default now()
);

alter table public.reunions enable row level security;

-- Both partners share full control of their single reunion row.
create policy "reunions_all_pair_members" on public.reunions
  for all using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  ) with check (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Realtime so edits by one partner appear on the other's screen.
alter publication supabase_realtime add table public.reunions;

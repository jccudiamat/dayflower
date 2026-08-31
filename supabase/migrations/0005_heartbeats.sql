-- Dayflower MVP — Feature 3: Heartbeat
-- Run in the Supabase SQL editor. Safe to re-run: drops any stale
-- heartbeats table first (dev data only — taps are disposable).

drop table if exists public.heartbeats cascade;

create table public.heartbeats (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  sender_id uuid not null references public.users (id) on delete cascade,
  sent_at timestamptz not null default now()
);

create index heartbeats_pair_sent_idx
  on public.heartbeats (pair_id, sent_at desc);

alter table public.heartbeats enable row level security;

create policy "heartbeats_select_pair_members" on public.heartbeats
  for select using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "heartbeats_insert_own" on public.heartbeats
  for insert with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Realtime so taps land on the partner's screen instantly.
alter publication supabase_realtime add table public.heartbeats;

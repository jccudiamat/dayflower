-- Dayflower MVP — Feature 2: Daily Tulip Exchange
-- Run in the Supabase SQL editor.

create table if not exists public.flower_messages (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  sender_id uuid not null references public.users (id) on delete cascade,
  flower_type text not null,
  note text,
  sent_at timestamptz not null default now(),
  seen_at timestamptz
);

-- One flower per sender per UTC day.
create unique index if not exists flower_one_per_day_idx
  on public.flower_messages (sender_id, ((sent_at at time zone 'utc')::date));

create index if not exists flower_pair_sent_idx
  on public.flower_messages (pair_id, sent_at desc);

alter table public.flower_messages enable row level security;

-- Members of the pair can read all of the pair's flowers.
create policy "flowers_select_pair_members" on public.flower_messages
  for select using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Only send as yourself, into your own pair.
create policy "flowers_insert_own" on public.flower_messages
  for insert with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Only the recipient can update (mark seen).
create policy "flowers_update_recipient" on public.flower_messages
  for update using (
    sender_id <> auth.uid()
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Realtime for instant delivery.
alter publication supabase_realtime add table public.flower_messages;

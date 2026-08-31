-- Dayflower — Goals & Chapters (Activities → Chapters)
-- Run in the Supabase SQL editor.
--
-- A year is twelve chapters. Each chapter is one month and has three
-- parts, which is why this is three tables rather than one:
--
--  1. `monthly_goals`   — written at the START of the month.
--  2. `chapter_moments` — the things that actually happened, added as they
--                         happen, so the review isn't written from memory.
--  3. `monthly_chapters`— the review, written at the END of the month.
--
-- Every row is keyed by (year, month) rather than a date range. A chapter
-- is a calendar month by definition, so storing bounds would only create
-- the opportunity for them to be wrong.
--
-- `owner_id` follows the finance tables: null = ours, a user id = mine.
--
-- Dev tables, so drop-and-recreate.

drop table if exists public.chapter_moments cascade;
drop table if exists public.monthly_goals cascade;
drop table if exists public.monthly_chapters cascade;

create table public.monthly_goals (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  -- null = a goal for the two of you
  owner_id uuid references public.users (id) on delete cascade,
  year int not null check (year between 2000 and 2999),
  month int not null check (month between 1 and 12),
  title text not null check (length(trim(title)) > 0),
  note text,
  emoji text not null default '🎯',
  done_at timestamptz,
  created_by uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index monthly_goals_pair_month_idx
  on public.monthly_goals (pair_id, year, month);

create table public.chapter_moments (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  year int not null check (year between 2000 and 2999),
  month int not null check (month between 1 and 12),
  title text not null check (length(trim(title)) > 0),
  note text,
  emoji text not null default '✨',
  happened_on date,
  created_by uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index chapter_moments_pair_month_idx
  on public.chapter_moments (pair_id, year, month);

create table public.monthly_chapters (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  year int not null check (year between 2000 and 2999),
  month int not null check (month between 1 and 12),
  -- What you'd call this month looking back: "the one where we finally met".
  title text,
  review text,
  rating int check (rating between 1 and 5),
  -- Set when the couple decides the chapter is written. A closed chapter
  -- still edits — closing is a milestone, not a lock.
  closed_at timestamptz,
  updated_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- One chapter per month per couple. This is also what makes the review
  -- editor a plain upsert instead of a read-then-branch.
  unique (pair_id, year, month)
);

alter table public.monthly_goals enable row level security;
alter table public.chapter_moments enable row level security;
alter table public.monthly_chapters enable row level security;

-- ── Goals — shared rows are both partners', solo rows are their owner's
-- (same rule as the finance tables). Both partners can always read.

create policy "monthly_goals_select_pair" on public.monthly_goals
  for select using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "monthly_goals_insert_own" on public.monthly_goals
  for insert with check (
    created_by = auth.uid()
    and (owner_id is null or owner_id = auth.uid())
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Ticking off is an update, and a shared goal is either partner's to tick.
create policy "monthly_goals_update_own" on public.monthly_goals
  for update using (
    (owner_id is null or owner_id = auth.uid())
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "monthly_goals_delete_own" on public.monthly_goals
  for delete using (
    (owner_id is null or owner_id = auth.uid())
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- ── Moments and the review are always the couple's, never one person's,
-- so pair membership is the whole rule.

create policy "chapter_moments_select_pair" on public.chapter_moments
  for select using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "chapter_moments_insert_pair" on public.chapter_moments
  for insert with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "chapter_moments_update_pair" on public.chapter_moments
  for update using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "chapter_moments_delete_pair" on public.chapter_moments
  for delete using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "monthly_chapters_select_pair" on public.monthly_chapters
  for select using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "monthly_chapters_insert_pair" on public.monthly_chapters
  for insert with check (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- The review is written together, so either partner can edit it. An upsert
-- that collides on the unique key runs as an UPDATE, which is why this
-- policy is what actually lets the second save through.
create policy "monthly_chapters_update_pair" on public.monthly_chapters
  for update using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "monthly_chapters_delete_pair" on public.monthly_chapters
  for delete using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

grant select, insert, update, delete on public.monthly_goals to authenticated;
grant select, insert, update, delete on public.chapter_moments to authenticated;
grant select, insert, update, delete on public.monthly_chapters to authenticated;

-- Both partners write into the same chapter — without realtime you would
-- only see their goals after a relaunch.
alter publication supabase_realtime add table public.monthly_goals;
alter publication supabase_realtime add table public.chapter_moments;
alter publication supabase_realtime add table public.monthly_chapters;

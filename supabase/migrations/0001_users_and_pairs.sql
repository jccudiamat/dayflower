-- Dayflower MVP — Feature 1: Auth + Pairing
-- Run this in the Supabase SQL editor (Project → SQL Editor → New query).

-- ── tables (both created first — the users policy below references pairs) ──

-- One profile row per auth.users row, created during onboarding.
create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  pet_name text,
  timezone text not null default 'UTC',
  created_at timestamptz not null default now()
);

-- Created by the first partner (user_b null + invite_code set).
-- Linked when the second partner submits the invite code (user_b filled in).
create table if not exists public.pairs (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.users (id) on delete cascade,
  user_b uuid references public.users (id) on delete cascade,
  invite_code text unique not null,
  created_at timestamptz not null default now(),
  constraint different_users check (user_a is distinct from user_b)
);

create unique index if not exists pairs_user_a_idx on public.pairs (user_a);

-- ── users policies ───────────────────────────────────────
alter table public.users enable row level security;

create policy "users_select_self_or_partner" on public.users
  for select using (
    auth.uid() = id
    or exists (
      select 1 from public.pairs p
      where (p.user_a = auth.uid() and p.user_b = users.id)
         or (p.user_b = auth.uid() and p.user_a = users.id)
    )
  );

create policy "users_insert_self" on public.users
  for insert with check (auth.uid() = id);

create policy "users_update_self" on public.users
  for update using (auth.uid() = id);

-- ── pairs policies ───────────────────────────────────────
alter table public.pairs enable row level security;

create policy "pairs_select_involved_or_open" on public.pairs
  for select using (
    auth.uid() = user_a or auth.uid() = user_b or user_b is null
  );

create policy "pairs_insert_own" on public.pairs
  for insert with check (auth.uid() = user_a and user_b is null);

create policy "pairs_accept_invite" on public.pairs
  for update using (user_b is null and auth.uid() <> user_a)
  with check (auth.uid() = user_b);

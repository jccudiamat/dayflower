-- Dayflower — waitlist table for the landing site (website/).
-- Run in the Supabase SQL editor as one script.
--
-- NOTE: this migration deliberately breaks the project's drop-and-recreate
-- convention. Every other table holds dev data we can regenerate; this one
-- holds real signups from real visitors. Re-running must never delete them,
-- so everything below is idempotent-but-preserving.

create table if not exists public.waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  source text not null default 'landing',
  created_at timestamptz not null default now()
);

-- Case-insensitive dedupe. The API lowercases before inserting, but index on
-- lower() so a duplicate is caught no matter who is writing.
create unique index if not exists waitlist_email_key
  on public.waitlist (lower(email));

alter table public.waitlist enable row level security;

-- Anonymous visitors may add themselves and nothing else. There is no select,
-- update, or delete policy, so with RLS on, the emails are unreadable through
-- the API entirely — read them in the dashboard or with the service role.
drop policy if exists waitlist_insert_anon on public.waitlist;
create policy waitlist_insert_anon on public.waitlist
  for insert to anon, authenticated
  with check (true);

-- This project has no default grants for anon (see 0002 — its ALTER DEFAULT
-- PRIVILEGES covers `authenticated` only), so grant explicitly.
--
-- The revoke matters: 0002's default privileges silently hand `authenticated`
-- select/insert/update/delete on every new table. RLS already blocks reads
-- with no policy present, but stripping the grants means a future permissive
-- policy can't accidentally expose the list.
revoke all on public.waitlist from anon, authenticated;
grant insert on public.waitlist to anon, authenticated;
grant usage on schema public to anon;

-- Dayflower — Reminders (Activities → Reminders)
-- Run in the Supabase SQL editor.
--
-- A reminder is set BY someone FOR someone: `created_by` is the author,
-- `for_user` is whose phone should ring. Setting one for yourself is just
-- the case where they are equal — the two columns are what make
-- "remind my partner to take their meds" possible at all.
--
-- ⚠️ IDEMPOTENT-BUT-PRESERVING, like 0007 and 0009 — NOT drop-and-recreate.
--
-- This file used to open with `drop table if exists public.reminders
-- cascade`. That was correct while the table was empty and actively wrong
-- once it wasn't: by 2026-08-31 it held the couple's real reminders and
-- re-running it would have deleted them. Reminders are now user data, so
-- this migration alters in place and is safe to run any number of times,
-- against a fresh project or an existing one.
--
-- Do NOT "tidy" this back into drop-and-recreate.

create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  created_by uuid not null references public.users (id) on delete cascade,
  for_user uuid not null references public.users (id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  note text,
  emoji text not null default '⏰',
  remind_at timestamptz not null,
  -- Repeats are resolved on the device that schedules the notification;
  -- the row only records the rule.
  repeat_rule text not null default 'none'
    check (repeat_rule in ('none', 'daily', 'weekly', 'monthly')),
  done_at timestamptz,
  created_at timestamptz not null default now()
);

-- Added 2026-08-31, when reminders became alarm clocks. Separate from the
-- create above because the table already existed by then — without this the
-- app's insert fails with PGRST204 ("could not find the 'alarm' column"),
-- which is what a "database error" when adding a reminder actually was.
--
--   true  = ring like an alarm clock: alarm-stream sound, full screen over
--           the lock screen, keeps ringing until snoozed or dismissed.
--   false = an ordinary quiet notification.
--
-- Defaults to true because "remind me" mostly means "make sure I notice",
-- and a reminder you slept through did nothing. The quiet mode exists so
-- "buy milk" doesn't have to be a fire drill. Existing rows inherit the
-- default, so reminders created before this ring from now on.
alter table public.reminders
  add column if not exists alarm boolean not null default true;

-- The list is always "this pair's reminders, soonest first".
create index if not exists reminders_pair_due_idx
  on public.reminders (pair_id, remind_at);

alter table public.reminders enable row level security;

-- Policies are dropped and recreated rather than created blindly: `create
-- policy` has no `if not exists`, so a re-run would abort the whole script
-- on the first one.

-- Both partners see every reminder in the pair — a reminder you set for
-- them has to be visible to you too, or you can't edit or cancel it.
drop policy if exists "reminders_select_pair_members" on public.reminders;
create policy "reminders_select_pair_members" on public.reminders
  for select using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Author it as yourself, inside your own pair, aimed at one of the two of
-- you. The `for_user` check is what stops a reminder being addressed at a
-- stranger's id.
drop policy if exists "reminders_insert_own" on public.reminders;
create policy "reminders_insert_own" on public.reminders
  for insert with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
        and (p.user_a = for_user or p.user_b = for_user)
    )
  );

-- Either partner can edit or tick one off: the recipient marks it done or
-- snoozes it, the author fixes the time they typed wrong.
drop policy if exists "reminders_update_pair_members" on public.reminders;
create policy "reminders_update_pair_members" on public.reminders
  for update using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

drop policy if exists "reminders_delete_pair_members" on public.reminders;
create policy "reminders_delete_pair_members" on public.reminders
  for delete using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- 0002 sets default privileges for tables created here, but spell it out —
-- a missing grant surfaces as 42501 and looks exactly like an RLS failure.
grant select, insert, update, delete on public.reminders to authenticated;

-- Without this the partner's app never learns about a new reminder until it
-- is next cold-started, which defeats the point.
--
-- Guarded: `alter publication ... add table` throws if the table is already
-- a member, which would abort a re-run of this script.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'reminders'
  ) then
    alter publication supabase_realtime add table public.reminders;
  end if;
end $$;

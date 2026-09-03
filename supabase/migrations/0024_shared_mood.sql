-- Dayflower — your mood reaches your partner.
-- Run in the Supabase SQL editor, or: dart run tool/run_sql.dart <this file>
--
-- Safe to re-run. Additive only.
--
-- 🔴 **The mood card has been device-local since 2026-08-01.** It persisted
-- to SharedPreferences so the card survived a restart, and that was all —
-- nothing ever reached the other phone. PROGRESS.md said so plainly and the
-- card said nothing, which is the worse half: a couples app asking "how are
-- you feeling?" and then keeping the answer is not a feature with a missing
-- piece, it is a question that goes nowhere.
--
-- The chat header now shows your partner's mood where it used to count the
-- flowers between you, so this is what makes that possible.

-- Two columns on `users` rather than a `moods` table.
--
-- A mood is a single current value per person, not a history — there is no
-- "what were they feeling last Tuesday" anywhere in the app, and a table
-- would be modelling a log nobody reads. If a history is ever wanted, that
-- is a new table and this column stays as the fast path for "right now".
alter table public.users
  add column if not exists mood text;

-- ⚠️ **When, not just what.** A mood with no timestamp is one somebody set
-- on Tuesday still being reported as how they feel on Friday. The app shows
-- nothing once it is stale rather than showing something old as if it were
-- current — see `UserProfile.freshMood`.
alter table public.users
  add column if not exists mood_at timestamptz;

-- Free text, no CHECK constraint, matching how `avatar` is stored. The Dart
-- enum is the source of truth for what is *valid*; an unrecognised value
-- reads as no mood rather than crashing a decode, so a newer build can add
-- a seventh mood without a migration having to land first.

-- RLS is unchanged and already exactly right: 0001's
-- "users_select_self_or_partner" is what lets you read your partner's row
-- at all, and "users_update_self" is what stops you writing to it. Reading
-- their mood needs no new policy; writing theirs remains impossible.
--
-- ⚠️ Realtime, though, is needed and was NOT there. `users` has never been
-- in the publication — nothing about a profile changed often enough to
-- matter, and every screen re-reads it on navigation. A mood is different:
-- the whole point is that it appears on their phone while they are looking
-- at it. Without this the chat header would show a mood set an hour ago and
-- never move until the app was reopened.
do $$
begin
  alter publication supabase_realtime add table public.users;
exception when duplicate_object then
  null;  -- already published; re-running this file is meant to be safe
end $$;

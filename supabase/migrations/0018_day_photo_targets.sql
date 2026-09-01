-- Dayflower — where a day photo is allowed to appear
-- Run in the Supabase SQL editor, or: dart run tool/run_sql.dart <this file>
--
-- Safe to re-run. Additive only.
--
-- `to_widget` already said "this may sit on their home screen". There was no
-- way to say the opposite of "and also in the thread", because every day
-- photo IS a message row and the thread renders every row it can see. So
-- the camera could offer two destinations, not three:
--
--   to_widget = true   → home screen *and* thread
--   to_widget = false  → thread only
--
-- `to_chat` supplies the missing half, so the camera's three choices are
-- three actual states rather than two with a relabelled duplicate:
--
--   Widget  → to_widget true,  to_chat false   (home screen, not the thread)
--   Chat    → to_widget false, to_chat true    (thread, not the home screen)
--   Both    → to_widget true,  to_chat true
--
-- Defaults to true so every row written before this — and every flower and
-- text message, which are always thread content — keeps showing up exactly
-- where it does today.

alter table public.flower_messages
  add column if not exists to_chat boolean not null default true;

-- The thread reads "everything for this pair, newest first" and then filters
-- in Dart, so no index is needed for correctness. This one keeps the common
-- read cheap once a pair has a few thousand messages.
create index if not exists flower_messages_pair_chat_idx
  on public.flower_messages (pair_id, to_chat, sent_at desc);

-- A widget-only photo that is in nobody's thread still has to reach the
-- other phone, so the realtime publication is unchanged — it already carries
-- this table (0003), and adding a column does not remove it.

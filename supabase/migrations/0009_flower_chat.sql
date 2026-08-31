-- Dayflower — Flowers tab becomes a conversation.
-- Run in the Supabase SQL editor as one script.
--
-- NOTE: like 0007, this one deliberately breaks the project's
-- drop-and-recreate convention. `flower_messages` holds the couple's actual
-- exchange history — the thing the whole app exists to accumulate — so this
-- migrates in place and is safe to re-run.
--
-- Three changes, all needed for the chat:
--   1. The one-flower-per-UTC-day rule is gone. A chat you can only post to
--      once a day is not a chat.
--   2. `flower_type` becomes nullable, so a row can be a plain text message.
--   3. `to_widget` records whether the sender chose to push this flower to
--      the recipient's home-screen widget.

-- 1. Unlimited sends. -----------------------------------------------------
drop index if exists public.flower_one_per_day_idx;

-- 2. Text messages: a row is a flower OR text (or a flower WITH a caption).
alter table public.flower_messages
  alter column flower_type drop not null;

-- 3. Which flowers reach the recipient's home screen.
alter table public.flower_messages
  add column if not exists to_widget boolean not null default false;

-- Backfill: every flower sent before the chat existed was, by definition,
-- that day's flower and did appear on the widget. Leaving them false would
-- retroactively empty the widget for the whole existing history.
update public.flower_messages
  set to_widget = true
  where flower_type is not null
    and to_widget = false;

-- A message must carry something. Without this an empty insert would render
-- as a blank bubble that can never be deleted.
alter table public.flower_messages
  drop constraint if exists flower_messages_has_content;
alter table public.flower_messages
  add constraint flower_messages_has_content check (
    flower_type is not null
    or (note is not null and length(btrim(note)) > 0)
  );

-- The chat reads newest-first for one pair; `flower_pair_sent_idx`
-- (pair_id, sent_at desc) from 0004 already serves it. Nothing to add.

-- RLS is unchanged and still correct: pair members read, sender inserts as
-- self, recipient-only update (which is what marks messages seen).

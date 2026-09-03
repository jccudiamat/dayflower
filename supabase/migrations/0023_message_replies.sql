-- Dayflower — replying to a day photo or a flower.
-- Run in the Supabase SQL editor, or: dart run tool/run_sql.dart <this file>
--
-- Safe to re-run. Additive only.
--
-- The story viewer and the home-screen widget both grew a reply bar, the way
-- a story has one. A reply is an ordinary message — that is the whole point,
-- because it means the thread, the unread badge, the notification and the
-- realtime stream all carry it with no second code path — but it is a
-- message *about* something, and this column is the only part of that which
-- could not be inferred.
--
-- Without it, "🌷" arriving in the thread three hours after the photo it
-- answers is just a flower, and the two are related only in the head of the
-- person who sent it.

alter table public.flower_messages
  add column if not exists reply_to uuid
    references public.flower_messages (id) on delete set null;

-- ⚠️ `set null`, never cascade. Deleting a day photo must not delete the
-- reply to it: the reply is the other person's, they said something, and
-- taking their words away because you removed your picture would be the
-- wrong owner deciding. The reply survives and simply stops quoting.
--
-- There is no delete path for messages in the app today, which is exactly
-- why this is worth settling now rather than when one is added.

-- The thread renders newest-first for a pair and looks up quoted parents by
-- id, which the primary key already serves. This index is for the other
-- direction — "what replied to this?" — which the viewer uses to show a
-- reply count on a photo.
create index if not exists flower_messages_reply_idx
  on public.flower_messages (reply_to)
  where reply_to is not null;

-- RLS is unchanged and still correct: a reply is a row in the same table,
-- for the same pair, and 0009's policies already say who may read and write
-- one. Nothing here widens access.
--
-- Realtime is unchanged too — `flower_messages` has been in the publication
-- since 0004, and adding a column does not remove it.

-- A note for the other one's Home, in place of its greeting.
--
-- Run as one script. Safe to re-run.
--
-- A few words ("thinking of you ☀️") written on your Home and shown on
-- theirs, where "Good afternoon, Hubby" was. It lasts 24 hours from when it
-- was written (the app stops showing it; UserProfile.freshNote) and only
-- the latest exists: writing another overwrites it, and nothing keeps the
-- old ones. They can react to it with an emoji.
--
-- ⚠️ **On the users row, not a table of its own**, and each person only
-- ever writes their own row. Your note is on yours; your reaction to their
-- note is on yours too, with the time of the note it answers
-- (note_reaction_to), so a new note from them starts with no reaction and
-- nobody needs permission to write to anybody else's row. `users` has been
-- in the realtime publication since 0024 and is already streamed to the
-- partner's phone, so both arrive live with nothing more here.

alter table public.users
  add column if not exists home_note text,
  add column if not exists home_note_at timestamptz,
  add column if not exists note_reaction text,
  add column if not exists note_reaction_to timestamptz;

-- The app holds a note to 35 characters for now. This is only a backstop
-- against something far longer arriving from outside it.
alter table public.users drop constraint if exists users_home_note_length;
alter table public.users add constraint users_home_note_length
  check (home_note is null or char_length(home_note) <= 200);

alter table public.users drop constraint if exists users_note_reaction_length;
alter table public.users add constraint users_note_reaction_length
  check (note_reaction is null or char_length(note_reaction) <= 16);

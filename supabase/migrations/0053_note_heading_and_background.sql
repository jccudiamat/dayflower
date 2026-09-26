-- A note gets a heading, and a background.
--
-- Run as one script. Safe to re-run.
--
-- A note (0052) was one line. It is now a heading, written big in thick
-- marker ("Good Morning!"), over a body in neat handwriting ("Coffee,
-- goals, and a better you!"). The body stays in home_note, so a note
-- written before this reads as a body with no heading. Either may be empty,
-- not both. The app holds the two together to 50 characters.
--
-- And it can carry one of the app's backgrounds: a starry sky, a scrap of
-- paper, a patch of morning light. On the other one's Home it runs edge to
-- edge behind the note and their My Day for as long as the note is up, and
-- the scrap they write their own note on changes to match it. None is the
-- default. Stored as the id of one the app ships (NoteBackground), not an
-- image: an id a build does not know shows as none.
--
-- Both go up and come down with the note.

alter table public.users
  add column if not exists home_note_heading text,
  add column if not exists home_note_bg text;

alter table public.users drop constraint if exists users_home_note_heading_length;
alter table public.users add constraint users_home_note_heading_length
  check (home_note_heading is null or char_length(home_note_heading) <= 200);

alter table public.users drop constraint if exists users_home_note_bg_length;
alter table public.users add constraint users_home_note_bg_length
  check (home_note_bg is null or char_length(home_note_bg) <= 40);

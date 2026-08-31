-- Dayflower — "Share your day": a photo that lands on your partner's home
-- screen widget and fades from it after 24 hours, while staying in the chat
-- forever. The bloom lasts a day; the record doesn't.
--
-- Run in the Supabase SQL editor as one script. Safe to re-run.
--
-- NOTE: like 0007 and 0009 this migrates `flower_messages` IN PLACE rather
-- than drop-and-recreate — it holds the couple's real history.

-- ── 1. A message can now also be a photo. ────────────────────────────────
-- Storage object path, not a URL: signed URLs expire, and the bucket is
-- private, so the app mints a fresh signed URL per read.
alter table public.flower_messages
  add column if not exists image_path text;

-- A row is a flower OR text OR a photo (a photo may carry a caption in
-- `note`, same as a flower does). Replaces the 0009 constraint.
alter table public.flower_messages
  drop constraint if exists flower_messages_has_content;
alter table public.flower_messages
  add constraint flower_messages_has_content check (
    flower_type is not null
    or image_path is not null
    or (note is not null and length(btrim(note)) > 0)
  );

-- The widget query asks "newest widget-bound item for this pair in the last
-- 24h", so it filters on pair + flag and orders by time.
create index if not exists flower_widget_idx
  on public.flower_messages (pair_id, to_widget, sent_at desc);

-- ⚠️ NO expiry column, and no cleanup job. 24h expiry is COMPUTED from
-- `sent_at` at read time (see dayPhotoProvider). Storing an expiry would
-- mean a row that "ends", and the whole point is that the photo stays in
-- the conversation after it leaves the home screen.

-- ── 2. Private bucket for the photos. ────────────────────────────────────
insert into storage.buckets (id, name, public)
  values ('day_photos', 'day_photos', false)
  on conflict (id) do nothing;

-- ── 3. Storage RLS. ──────────────────────────────────────────────────────
-- Objects are keyed <pair_id>/<uuid>.jpg, so the first path segment is the
-- pair. That is what makes membership checkable without a join back to
-- flower_messages — storage policies only see the object row.
drop policy if exists "day_photos_read_pair" on storage.objects;
create policy "day_photos_read_pair" on storage.objects
  for select using (
    bucket_id = 'day_photos'
    and exists (
      select 1 from public.pairs p
      where p.id = ((storage.foldername(name))[1])::uuid
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

drop policy if exists "day_photos_insert_own_pair" on storage.objects;
create policy "day_photos_insert_own_pair" on storage.objects
  for insert with check (
    bucket_id = 'day_photos'
    and owner = auth.uid()
    and exists (
      select 1 from public.pairs p
      where p.id = ((storage.foldername(name))[1])::uuid
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Deleting your own photo. There is no delete path in the app yet; this
-- exists so a future "remove this from my day" cannot be blocked by RLS.
drop policy if exists "day_photos_delete_own" on storage.objects;
create policy "day_photos_delete_own" on storage.objects
  for delete using (
    bucket_id = 'day_photos' and owner = auth.uid()
  );

-- RLS on flower_messages itself is unchanged and still correct: pair members
-- read, sender inserts as self, recipient-only update marks seen.

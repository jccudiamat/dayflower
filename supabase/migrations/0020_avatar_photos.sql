-- Dayflower — a real photo as your avatar.
-- Run in the Supabase SQL editor, or: dart run tool/run_sql.dart <this file>
--
-- Safe to re-run. Additive only.
--
-- 0017 made an avatar a *flower id* — no Storage, no upload failure path,
-- and it fits an app whose whole vocabulary is flowers. That stays exactly
-- as it is. This adds a photo **on top of** it, and the ordering is the
-- point:
--
--   avatar_path set   → the photo
--   otherwise         → the chosen flower
--   otherwise         → the gender default, then the tulip fallback
--
-- ⚠️ **The flower is never removed and never becomes optional.** It is what
-- makes every account have an avatar from the first second, with nothing
-- uploaded and nothing to fail — and it is what a broken image, an expired
-- URL or an offline phone falls back to. A photo is an upgrade to that
-- chain, not a replacement for it. Do not "simplify" by dropping `avatar`
-- once photos work.

-- Storage object path in the private `avatars` bucket, keyed
-- `<user_id>/<uuid>.jpg`. Not a URL: the bucket is private, so the app
-- mints a signed URL when it actually needs to render this — same reasoning
-- as `flower_messages.image_path` in 0013.
alter table public.users
  add column if not exists avatar_path text;

-- RLS on `users` is unchanged and already correct: 0001's
-- "users_select_self_or_partner" covers reading a partner's avatar_path,
-- and the self-update policy covers setting your own. Nothing to add.

-- ── The bucket ──────────────────────────────────────────────────────────
--
-- Private, like day_photos and unlike app-builds. An avatar is a picture of
-- someone's face; a public bucket would make it readable by anyone who
-- learns the URL, and "nobody will guess a uuid" is not a privacy model.
-- The cost is one signing round-trip per session, which is why the app
-- signs with a long TTL and caches rather than signing per render.
insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', false)
  on conflict (id) do nothing;

-- ⚠️ **The `do nothing` above is not enough, and this line is why.** An
-- `avatars` bucket already existed on this project — created by hand,
-- outside any migration — and it was **public**. The insert therefore did
-- nothing, the migration reported success, and the bucket stayed readable
-- by anyone holding a URL while this file's own comment claimed otherwise.
-- Caught by checking `storage.buckets.public` after running, not by
-- reading the script. Enforce the flag rather than only setting it on
-- creation, so a re-run repairs the same drift instead of ignoring it.
update storage.buckets set public = false
  where id = 'avatars' and public is distinct from false;

-- ── Storage RLS ─────────────────────────────────────────────────────────
--
-- Objects are keyed `<user_id>/<uuid>.jpg`, so the first path segment is
-- the owner. Storage policies only ever see the object row, so putting the
-- identity in the path is what makes any of this checkable without a join.
--
-- Read is wider than write on purpose: your partner has to be able to see
-- you, and nobody else does.
drop policy if exists "avatars_read_self_or_partner" on storage.objects;
create policy "avatars_read_self_or_partner" on storage.objects
  for select using (
    bucket_id = 'avatars'
    and (
      ((storage.foldername(name))[1])::uuid = auth.uid()
      or exists (
        select 1 from public.pairs p
        where (p.user_a = auth.uid()
                 and p.user_b = ((storage.foldername(name))[1])::uuid)
           or (p.user_b = auth.uid()
                 and p.user_a = ((storage.foldername(name))[1])::uuid)
      )
    )
  );

-- Only into your own folder, and only as yourself. Both halves matter: the
-- folder check is what stops someone writing an object that then reads as
-- the partner's avatar, and `owner` is what the delete policy keys on.
drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and owner = auth.uid()
    and ((storage.foldername(name))[1])::uuid = auth.uid()
  );

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own" on storage.objects
  for update using (
    bucket_id = 'avatars' and owner = auth.uid()
  );

-- Replacing a photo writes a new object and deletes the old one, so unlike
-- day_photos this delete path has a real caller from day one. Without it
-- every change would leave the previous face in the bucket forever.
drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own" on storage.objects
  for delete using (
    bucket_id = 'avatars' and owner = auth.uid()
  );

-- ⚠️ A note on the uuid casts above, because they look fragile and are the
-- same shape as 0013's: `storage.foldername('file.apk')` returns an empty
-- array, and `(array)[1]` on an empty array is NULL, so an object at a
-- bucket root (app-builds) yields `NULL::uuid` rather than an error. Only a
-- *folder* whose name is not a uuid would raise — and the insert policy
-- casts too, so no such object can be written through the API.

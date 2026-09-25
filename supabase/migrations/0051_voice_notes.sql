-- Voice messages, up to two minutes.
--
-- Run as one script. Safe to re-run. Deploy the `push` function that knows
-- the "voice" kind FIRST, or an older one announces a voice note as
-- "sent you a message".
--
-- ⚠️ **Columns on `flower_messages`, not a table.** A voice note is a
-- message: it sits in the thread in time order, it can be replied to, it can
-- be deleted, and it carries the same seen/reply plumbing as everything
-- else. Migration 0013 made the same call for photos, and the alternative
-- there and here is a second timeline to keep in step with the first.
--
-- ⚠️ **Recorded at 24 kbps mono, which is a size decision made on the
-- phone** (VoiceRecorder.kt). Two minutes is about 360 KB: roughly one and
-- a half of this app's photos. At 5,000 pairs sending ten a day that is
-- about 135 GB a month, which is why there is a length limit at all.

alter table public.flower_messages
  add column if not exists audio_path text;

-- How long it runs, in milliseconds, written by the sender.
--
-- 🔴 Stored rather than read from the file. The bubble has to draw at its
-- real width before a byte of audio has downloaded, exactly as the photo
-- shape rides in the path (photo_shape.dart) so a picture's box is right
-- before it loads. Without it every voice note would appear as a
-- zero-length bar and then jump.
alter table public.flower_messages
  add column if not exists audio_ms integer
  check (audio_ms is null or (audio_ms > 0 and audio_ms <= 130000));

-- A row is a flower OR text OR a photo OR a voice note. Replaces 0013's.
alter table public.flower_messages
  drop constraint if exists flower_messages_has_content;
alter table public.flower_messages
  add constraint flower_messages_has_content check (
    flower_type is not null
    or image_path is not null
    or audio_path is not null
    or call_mode is not null
    or (note is not null and length(btrim(note)) > 0)
  );

-- ⚠️ The old constraint had no `call_mode` arm and calls only passed it
-- because 0025 gives them a note. Spelled out here so a call row does not
-- depend on its copy for validity.

-- ── The bucket ──────────────────────────────────────────────────────────
--
-- Private, like day_photos and avatars. A voice note is somebody's voice.
insert into storage.buckets (id, name, public)
  values ('voice_notes', 'voice_notes', false)
  on conflict (id) do nothing;

-- Enforced rather than only set at creation: see 0020 for the bucket that
-- already existed, public, and survived its `do nothing`.
update storage.buckets set public = false
  where id = 'voice_notes' and public is distinct from false;

-- Keyed `<pair_id>/<name>.m4a`, so the first segment is the pair, exactly
-- as day_photos is. Storage policies only ever see the object row, which is
-- what makes putting the pair in the path the thing that can be checked.
drop policy if exists "voice_notes_read_pair" on storage.objects;
create policy "voice_notes_read_pair" on storage.objects
  for select using (
    bucket_id = 'voice_notes'
    and exists (
      select 1 from public.pairs p
      where p.id = ((storage.foldername(name))[1])::uuid
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

drop policy if exists "voice_notes_insert_own_pair" on storage.objects;
create policy "voice_notes_insert_own_pair" on storage.objects
  for insert with check (
    bucket_id = 'voice_notes'
    and owner = auth.uid()
    and exists (
      select 1 from public.pairs p
      where p.id = ((storage.foldername(name))[1])::uuid
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Taking back your own voice note deletes the object with the row.
drop policy if exists "voice_notes_delete_own" on storage.objects;
create policy "voice_notes_delete_own" on storage.objects
  for delete using (
    bucket_id = 'voice_notes' and owner = auth.uid()
  );

-- ── Deleting takes the file too ─────────────────────────────────────────
--
-- Unchanged from 0025 except for the returned column. ⚠️ Kept as one
-- `delete ... returning`, not a select and then a delete: the predicate on
-- `sender_id` IS the access control here (a definer function bypasses RLS),
-- and splitting it in two would open a window between the check and the
-- delete.
--
-- ⚠️ Returns whichever object the row owned, photo or voice. The app routes
-- it to the right bucket by extension -- `.m4a` is a voice note -- rather
-- than this returning two values and every existing caller changing shape.
create or replace function public.delete_message(p_message_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_path text;
begin
  delete from public.flower_messages m
   where m.id = p_message_id
     -- Only your own. A definer function bypasses RLS, so this predicate IS
     -- the access control -- there is nothing behind it.
     and m.sender_id = auth.uid()
     -- Membership, checked here for the same reason.
     and exists (
       select 1 from public.pairs p
        where p.id = m.pair_id
          and auth.uid() in (p.user_a, p.user_b)
     )
  returning coalesce(m.image_path, m.audio_path) into v_path;

  return v_path;
end $$;

-- ── Push ────────────────────────────────────────────────────────────────
--
-- Unchanged from 0031 but for one arm of the `case`. ⚠️ The `to_chat` guard
-- is on the **trigger**, not in here (`when (new.to_chat = true)`), so this
-- function must not grow its own copy: two guards that can disagree is how
-- a message silently stops notifying.
create or replace function public.notify_push()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_url text;
  v_secret text;
  v_kind text;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'push_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'push_secret';

  -- Not configured yet is a normal state, not an error. The insert that
  -- fired this must never fail because push is half set up -- a message that
  -- did not notify is a lesser failure than a message that did not send.
  if v_url is null or v_secret is null then
    return new;
  end if;

  v_kind := case
    when new.call_mode is not null then 'call'
    when new.image_path is not null then 'photo'
    when new.audio_path is not null then 'voice'
    when new.flower_type is not null then 'flower'
    else 'message'
  end;

  -- Only *new* calls ring. A call row is updated when it ends, and this is
  -- an INSERT trigger, so that is already true -- but it is the kind of
  -- thing a later UPDATE trigger would break silently, so it is said here.
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret
    ),
    body := jsonb_build_object(
      'message_id', new.id,
      'pair_id', new.pair_id,
      'sender_id', new.sender_id,
      'kind', v_kind,
      'call_mode', new.call_mode
    ),
    timeout_milliseconds := 4000
  );

  return new;
end $$;

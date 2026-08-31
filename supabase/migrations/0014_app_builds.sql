-- Dayflower — in-app updater. The bucket that holds sideload APKs and the
-- `latest.json` manifest naming the newest one, so a phone can update itself
-- instead of the APK being rebuilt and re-sideloaded by hand.
--
-- Run in the Supabase SQL editor as one script. Safe to re-run.
--
-- Producer: tool/publish_update.dart (service-role key, from .publish.env).
-- Consumer: lib/features/updates/ (plain HTTP, no session).

-- ── 1. The bucket. ───────────────────────────────────────────────────────
-- PUBLIC, unlike every other bucket in this project, and that is deliberate:
-- the update check runs on a cold start BEFORE login, so it cannot depend on
-- a session, an RLS policy or a signed URL. The trade is that anyone who
-- knows the project URL and guesses the object name can download the APK.
-- For a two-person app whose secrets all live server-side behind RLS that is
-- an acceptable trade — but note the APK bundles `.env`, so treat the anon
-- key in it as public, and never put a service-role key in `.env`.
--
-- To close it later: flip `public` to false, give the app an authenticated
-- `createSignedUrl` call, and accept that updates only surface after login.
insert into storage.buckets (id, name, public)
  values ('app-builds', 'app-builds', true)
  on conflict (id) do update set public = true;

-- ── 2. Read policy. ──────────────────────────────────────────────────────
-- `public = true` already serves objects through /object/public/... without
-- consulting RLS, so this policy is not what makes the download work. It is
-- here so the bucket still behaves sanely for anything that DOES go through
-- RLS (the dashboard, a signed-URL path later, listing).
drop policy if exists "app_builds_read_all" on storage.objects;
create policy "app_builds_read_all" on storage.objects
  for select using (bucket_id = 'app-builds');

-- ── 3. Writes. ───────────────────────────────────────────────────────────
-- Deliberately NO insert/update/delete policy. Publishing goes through the
-- service-role key, which bypasses RLS entirely; without a write policy no
-- anon or authenticated session can replace an APK. That matters more here
-- than anywhere else in the schema: an attacker who could overwrite
-- `latest.json` and the APK it names would be handing our own users a
-- package installer prompt for their binary.

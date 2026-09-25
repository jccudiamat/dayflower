-- Bugs and suggestions, sent from Settings: some words, and up to three
-- screenshots.
--
-- Run as one script. Safe to re-run.
--
-- 🔴 **Write-only from the app.** A report is sent to the people who make
-- Dayflower, not shared with a partner, so nothing here is pair-scoped:
-- you can send one and read back only your own, and nobody else's is
-- visible to you. They are read in the dashboard, where the service role
-- sees every row.

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),

  -- ⚠️ `cascade`: deleting an account takes its reports with it. A report
  -- is the person's own words and screenshots, and the account going is
  -- them asking for their things to go.
  user_id uuid not null references public.users (id) on delete cascade,

  kind text not null check (kind in ('bug', 'suggestion')),
  message text not null check (char_length(trim(message)) between 1 and 4000),

  -- Paths in the private `feedback` bucket, `<user_id>/<name>.<ext>`.
  image_paths text[] not null default '{}'
    check (cardinality(image_paths) <= 3),

  -- Which build, on what. Enough to reproduce a bug without asking.
  app_version text,
  platform text,

  created_at timestamptz not null default now()
);

create index if not exists feedback_created_idx
  on public.feedback (created_at desc);

alter table public.feedback enable row level security;

drop policy if exists "feedback_insert_self" on public.feedback;
create policy "feedback_insert_self" on public.feedback
  for insert with check (auth.uid() = user_id);

drop policy if exists "feedback_select_self" on public.feedback;
create policy "feedback_select_self" on public.feedback
  for select using (auth.uid() = user_id);

-- No update and no delete: a report is sent, not drafted.

-- 0002's default privileges should already cover a new table; said out loud
-- anyway, because a missing grant fails as "permission denied" and looks
-- like a policy bug.
grant select, insert on public.feedback to authenticated;

-- ── The screenshots ─────────────────────────────────────────────────────
--
-- Private, like avatars and day photos. A screenshot of the app is a
-- screenshot of somebody's messages.
insert into storage.buckets (id, name, public)
  values ('feedback', 'feedback', false)
  on conflict (id) do nothing;

-- Enforced, not only set on creation: see 0020 for the bucket that already
-- existed, public, and survived its `do nothing`.
update storage.buckets set public = false
  where id = 'feedback' and public is distinct from false;

-- Keyed `<user_id>/…`, so the first folder is the sender. Yours only, in
-- every direction.
drop policy if exists "feedback_read_own" on storage.objects;
create policy "feedback_read_own" on storage.objects
  for select using (
    bucket_id = 'feedback'
    and ((storage.foldername(name))[1])::uuid = auth.uid()
  );

drop policy if exists "feedback_insert_own" on storage.objects;
create policy "feedback_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'feedback'
    and owner = auth.uid()
    and ((storage.foldername(name))[1])::uuid = auth.uid()
  );

-- Only so a send that fails after its screenshots went up can take them
-- back, rather than leave them in the bucket with no report to explain them.
drop policy if exists "feedback_delete_own" on storage.objects;
create policy "feedback_delete_own" on storage.objects
  for delete using (
    bucket_id = 'feedback' and owner = auth.uid()
  );

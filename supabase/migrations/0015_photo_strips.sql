-- Dayflower — booth strips in the Flowers camera.
--
-- A strip is a templated photo. Solo templates complete in one shot; duo
-- templates hold one half open until the partner adds theirs.
--
-- **Async only, deliberately.** "Together" here means both halves, not both
-- at once. A live session would only work when both people are awake and
-- holding their phones — which is the situation this app exists because they
-- are NOT in. A half-finished strip waiting overnight is the feature.
--
-- Run in the Supabase SQL editor as one script. Safe to re-run.

create table if not exists public.photo_strips (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,

  -- Template id from lib/features/booth/domain/strip_templates.dart.
  template text not null,
  is_duo boolean not null default false,

  -- Slot A is whoever started it; slot B stays null until the partner joins.
  a_user uuid not null references public.users (id) on delete cascade,
  a_path text not null,
  b_user uuid references public.users (id) on delete cascade,
  b_path text,

  -- Set when the composite has been rendered and posted to the thread. The
  -- strip row is kept afterwards so "who shot which half" survives.
  completed_at timestamptz,
  message_id uuid references public.flower_messages (id) on delete set null,

  created_at timestamptz not null default now(),

  -- A duo strip is only finished when both halves exist; a solo one has no
  -- second half to wait for. Stops a half-strip being marked complete.
  constraint strip_duo_pairing check (
    (b_user is null) = (b_path is null)
  ),
  constraint strip_completion check (
    completed_at is null
    or is_duo = false
    or (b_user is not null and b_path is not null)
  ),
  -- You cannot fill both halves of a duo strip yourself.
  constraint strip_two_people check (b_user is null or b_user <> a_user)
);

-- "Is there an open duo strip waiting for me?" — the only hot query.
create index if not exists strip_open_idx
  on public.photo_strips (pair_id, completed_at, created_at desc);

alter table public.photo_strips enable row level security;

-- Pair members see the pair's strips.
drop policy if exists "strips_select_pair" on public.photo_strips;
create policy "strips_select_pair" on public.photo_strips
  for select using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- You start a strip as yourself, in your own pair.
drop policy if exists "strips_insert_own" on public.photo_strips;
create policy "strips_insert_own" on public.photo_strips
  for insert with check (
    a_user = auth.uid()
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Either member may update: the joiner fills slot B, and whoever completes
-- it writes completed_at + message_id. Narrower than it looks — the CHECK
-- constraints above are what stop a bad shape being written.
drop policy if exists "strips_update_pair" on public.photo_strips;
create policy "strips_update_pair" on public.photo_strips
  for update using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Abandoning a strip you started.
drop policy if exists "strips_delete_own" on public.photo_strips;
create policy "strips_delete_own" on public.photo_strips
  for delete using (a_user = auth.uid());

-- Realtime: the whole point is that the other side sees "waiting for you"
-- appear without a refresh. Without this the invite is invisible until
-- the app is restarted.
alter publication supabase_realtime add table public.photo_strips;

-- Strip halves live in the same private bucket as day photos, under the
-- same <pair_id>/... prefix, so 0013's Storage policies already cover them.
-- Nothing to add here.

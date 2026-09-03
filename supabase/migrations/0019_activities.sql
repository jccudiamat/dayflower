-- Dayflower — the shared activity feed
-- Run in the Supabase SQL editor, or: dart run tool/run_sql.dart <this file>
--
-- Safe to re-run. Additive only — it creates two tables and a set of
-- triggers on tables that already exist, and touches none of their data.
--
-- ── What this is, and what it deliberately is not ───────────────────
--
-- This is NOT the notification table. A heart, a photo or a message is a
-- *nudge*: it wants to interrupt you once and then be gone, and it already
-- has somewhere to live (`flower_messages`, `heartbeats`) and something to
-- render it (the thread, the widget, the pulse alert).
--
-- An activity is the opposite: something one of you *did to the shared
-- world* — set a reminder, opened a chapter goal, left half a photo strip
-- waiting. It is worth showing hours later, it points at a place in the
-- app, and it reads the same to both people. That is why it is a table of
-- its own rather than a flag on the message rows.
--
-- ── Why triggers rather than the app writing these ──────────────────
--
-- Every one of these rows describes a write that just happened one table
-- over. Writing them from Dart would mean nine call sites that each have to
-- remember, an activity silently missing whenever one is added, and no
-- entry at all for anything written from the SQL editor or an older build
-- of the app. The trigger cannot forget.
--
-- ⚠️ The corollary, and the thing to keep true: **an activity must never be
-- able to break the feature it describes.** An AFTER trigger that raises
-- rolls back the statement that fired it, so a bug in here would surface as
-- "I can't save a reminder any more". `log_activity` therefore swallows
-- everything (see its exception block), and every trigger below routes
-- through it.

-- ════════════════════════════════════════════════════════════════════
-- 1. The feed
-- ════════════════════════════════════════════════════════════════════

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,

  -- Nullable, and `set null` rather than cascade: an activity outlives the
  -- account that caused it. A deleted user leaves "someone set a reminder",
  -- which is worse copy but better than a hole in the timeline.
  actor_id uuid references public.users (id) on delete set null,

  -- Free text on purpose — no CHECK constraint. Kinds are added here in
  -- lockstep with the trigger that emits them, and a constraint would turn
  -- every new kind into a two-step deploy where landing the trigger first
  -- makes inserts start failing. Dart maps unknown kinds to a generic card
  -- rather than throwing, so an old build reading a new kind degrades.
  kind text not null,

  -- Already-rendered, because the row has to read correctly forever. Naming
  -- the subject at write time means renaming a reminder later doesn't
  -- rewrite what the feed said happened, and the feed never has to join
  -- five tables to draw a line of text.
  title text not null,
  emoji text not null default '✨',

  -- What to open when the card is tapped. No FK: it points into a different
  -- table per kind, and a `set null` on a real FK would quietly turn a
  -- tappable card into a dead one.
  subject_id uuid,

  -- Whatever the destination needs that the id alone doesn't carry — the
  -- year and month for a chapter, who a reminder is for. Never anything the
  -- feed itself renders.
  meta jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now()
);

-- The only query: "this pair's activities, newest first".
create index if not exists activities_pair_recent_idx
  on public.activities (pair_id, created_at desc);

alter table public.activities enable row level security;

-- Read-only to clients. There is no insert, update or delete policy here
-- and that is the design: rows arrive exclusively through the security
-- definer function below, so nothing signed in can fabricate an entry,
-- rewrite what happened, or quietly delete it from the other person's
-- timeline.
drop policy if exists "activities_select_pair" on public.activities;
create policy "activities_select_pair" on public.activities
  for select using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- ════════════════════════════════════════════════════════════════════
-- 2. Who has caught up to where
-- ════════════════════════════════════════════════════════════════════
--
-- A watermark per person rather than a read flag per row. There are exactly
-- two readers and the feed is only ever consumed newest-first, so "I have
-- seen everything up to here" answers the badge in one comparison and needs
-- one row per person for the life of the pair.

create table if not exists public.activity_reads (
  pair_id uuid not null references public.pairs (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  last_seen_at timestamptz not null default now(),
  primary key (pair_id, user_id)
);

alter table public.activity_reads enable row level security;

drop policy if exists "activity_reads_select_own" on public.activity_reads;
create policy "activity_reads_select_own" on public.activity_reads
  for select using (user_id = auth.uid());

drop policy if exists "activity_reads_insert_own" on public.activity_reads;
create policy "activity_reads_insert_own" on public.activity_reads
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

drop policy if exists "activity_reads_update_own" on public.activity_reads;
create policy "activity_reads_update_own" on public.activity_reads
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- 0002 set default privileges so tables created here inherit grants, but
-- that only fires for tables created by the same role afterwards — and this
-- project has been bitten once already by a policy that filtered rows on a
-- table the role could not touch at all (42501). Spelled out rather than
-- assumed. `activities` gets SELECT only: writes are the trigger's alone.
grant select on public.activities to authenticated;
grant select, insert, update on public.activity_reads to authenticated;

-- The feed appearing without a refresh is most of the point — a strip
-- waiting on you is useless news tomorrow.
do $$
begin
  alter publication supabase_realtime add table public.activities;
exception when duplicate_object then
  null;  -- already published; re-running this file is meant to be safe
end $$;

-- ════════════════════════════════════════════════════════════════════
-- 3. The one writer
-- ════════════════════════════════════════════════════════════════════

create or replace function public.log_activity(
  p_pair_id uuid,
  p_actor uuid,
  p_kind text,
  p_title text,
  p_emoji text,
  p_subject uuid,
  p_meta jsonb default '{}'::jsonb,
  p_dedupe interval default interval '30 minutes'
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_pair_id is null or p_title is null or length(trim(p_title)) = 0 then
    return;
  end if;

  -- Repeated saves of the same thing are one event, not twelve. The chapter
  -- review editor is a plain upsert and the reunion is a single row that
  -- gets nudged whenever a date moves, so without this the feed would fill
  -- with "wrote the September review" every time a sentence was typed.
  -- Keyed on the subject, so two different reminders set a minute apart are
  -- still two entries.
  if p_subject is not null and exists (
    select 1 from public.activities a
    where a.pair_id = p_pair_id
      and a.kind = p_kind
      and a.subject_id = p_subject
      and a.created_at > now() - p_dedupe
  ) then
    return;
  end if;

  insert into public.activities
    (pair_id, actor_id, kind, title, emoji, subject_id, meta)
  values (
    p_pair_id,
    -- The reunion and the goal-completed paths have no author column to
    -- read, so the session's own identity is the fallback. Null when a
    -- write comes from the SQL editor or the service role, which is
    -- honest: nobody in the couple did that.
    coalesce(p_actor, auth.uid()),
    p_kind,
    trim(p_title),
    coalesce(nullif(p_emoji, ''), '✨'),
    p_subject,
    coalesce(p_meta, '{}'::jsonb)
  );
exception when others then
  -- Deliberately silent. See the header: the feed describing a write must
  -- never be able to roll that write back.
  null;
end;
$$;

-- ════════════════════════════════════════════════════════════════════
-- 4. What gets logged
-- ════════════════════════════════════════════════════════════════════
--
-- Everything below is `after` — the row is committed-shaped before we
-- describe it — and `for each row`.

-- ── Reminders ───────────────────────────────────────────────────────
create or replace function public.tg_activity_reminder() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.log_activity(
    new.pair_id, new.created_by, 'reminder_set',
    new.title, new.emoji, new.id,
    -- `for_user` is what lets the card say "for you" instead of "for
    -- themselves" — the whole point of reminders having two user columns.
    jsonb_build_object('for_user', new.for_user, 'remind_at', new.remind_at)
  );
  return null;
end $$;

drop trigger if exists activity_reminder_ins on public.reminders;
create trigger activity_reminder_ins after insert on public.reminders
  for each row execute function public.tg_activity_reminder();

-- ── Chapter goals ───────────────────────────────────────────────────
create or replace function public.tg_activity_goal() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_activity(
      new.pair_id, new.created_by, 'goal_set',
      new.title, new.emoji, new.id,
      jsonb_build_object('year', new.year, 'month', new.month,
                         'owner_id', new.owner_id)
    );
  -- Only the moment it flips to done. An edit to a finished goal is not a
  -- second completion.
  elsif old.done_at is null and new.done_at is not null then
    perform public.log_activity(
      new.pair_id, null, 'goal_done',
      new.title, '🎉', new.id,
      jsonb_build_object('year', new.year, 'month', new.month)
    );
  end if;
  return null;
end $$;

drop trigger if exists activity_goal_ins on public.monthly_goals;
create trigger activity_goal_ins after insert on public.monthly_goals
  for each row execute function public.tg_activity_goal();

drop trigger if exists activity_goal_upd on public.monthly_goals;
create trigger activity_goal_upd after update on public.monthly_goals
  for each row execute function public.tg_activity_goal();

-- ── Chapter moments ─────────────────────────────────────────────────
create or replace function public.tg_activity_moment() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.log_activity(
    new.pair_id, new.created_by, 'moment_added',
    new.title, new.emoji, new.id,
    jsonb_build_object('year', new.year, 'month', new.month)
  );
  return null;
end $$;

drop trigger if exists activity_moment_ins on public.chapter_moments;
create trigger activity_moment_ins after insert on public.chapter_moments
  for each row execute function public.tg_activity_moment();

-- ── The chapter itself ──────────────────────────────────────────────
create or replace function public.tg_activity_chapter() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  month_name text := to_char(make_date(new.year, new.month, 1), 'FMMonth');
  wrote boolean;
  closed boolean;
begin
  -- OLD is unassigned during an INSERT and touching it there raises
  -- "record 'old' is not assigned yet" — PL/pgSQL evaluates a boolean
  -- expression as one SQL expression, so a `tg_op = 'INSERT' or old.x`
  -- guard is not guaranteed to short-circuit. Branch on tg_op instead.
  if tg_op = 'INSERT' then
    wrote := coalesce(new.review, '') <> '';
    closed := new.closed_at is not null;
  else
    wrote := coalesce(new.review, '') <> ''
      and coalesce(old.review, '') is distinct from new.review;
    closed := new.closed_at is not null and old.closed_at is null;
  end if;

  -- An empty upsert — the editor creating the row before anything is typed
  -- — is not news. Closing beats writing when both happen in one save.
  if closed then
    perform public.log_activity(
      new.pair_id, new.updated_by, 'chapter_closed',
      coalesce(nullif(new.title, ''), month_name), '📖', new.id,
      jsonb_build_object('year', new.year, 'month', new.month)
    );
  elsif wrote then
    perform public.log_activity(
      new.pair_id, new.updated_by, 'chapter_written',
      coalesce(nullif(new.title, ''), month_name), '✍️', new.id,
      jsonb_build_object('year', new.year, 'month', new.month)
    );
  end if;
  return null;
end $$;

drop trigger if exists activity_chapter_ins on public.monthly_chapters;
create trigger activity_chapter_ins after insert on public.monthly_chapters
  for each row execute function public.tg_activity_chapter();

drop trigger if exists activity_chapter_upd on public.monthly_chapters;
create trigger activity_chapter_upd after update on public.monthly_chapters
  for each row execute function public.tg_activity_chapter();

-- ── The reunion ─────────────────────────────────────────────────────
-- One row per pair, so this fires on the date moving as well as on it being
-- set. Both are the same news to the other person: the countdown changed.
create or replace function public.tg_activity_reunion() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- Nested rather than one condition: OLD does not exist on INSERT, and
  -- PL/pgSQL will not reliably short-circuit past it. Same trap as the
  -- chapter trigger above.
  if tg_op = 'UPDATE' then
    if old.happens_at = new.happens_at
       and coalesce(old.destination, '') = coalesce(new.destination, '')
       and coalesce(old.title, '') = coalesce(new.title, '') then
      return null;  -- a note edit is not a new countdown
    end if;
  end if;
  perform public.log_activity(
    new.pair_id, null, 'reunion_set',
    coalesce(nullif(new.destination, ''), new.title), '✈️', new.id,
    jsonb_build_object('happens_at', new.happens_at)
  );
  return null;
end $$;

drop trigger if exists activity_reunion_ins on public.reunions;
create trigger activity_reunion_ins after insert on public.reunions
  for each row execute function public.tg_activity_reunion();

drop trigger if exists activity_reunion_upd on public.reunions;
create trigger activity_reunion_upd after update on public.reunions
  for each row execute function public.tg_activity_reunion();

-- ── Photo strips ────────────────────────────────────────────────────
-- The one the user asked for by name: "waiting for your turn for the duo
-- pic". Solo strips never wait on anyone, so they never appear here.
create or replace function public.tg_activity_strip() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if new.is_duo and new.completed_at is null then
      perform public.log_activity(
        new.pair_id, new.a_user, 'strip_waiting',
        'Your half of the photo strip', '📸', new.id,
        jsonb_build_object('template', new.template)
      );
    end if;
  elsif old.completed_at is null and new.completed_at is not null then
    perform public.log_activity(
      new.pair_id, new.b_user, 'strip_done',
      'Your photo strip is complete', '🎞️', new.id,
      jsonb_build_object('template', new.template,
                         'message_id', new.message_id)
    );
  end if;
  return null;
end $$;

drop trigger if exists activity_strip_ins on public.photo_strips;
create trigger activity_strip_ins after insert on public.photo_strips
  for each row execute function public.tg_activity_strip();

drop trigger if exists activity_strip_upd on public.photo_strips;
create trigger activity_strip_upd after update on public.photo_strips
  for each row execute function public.tg_activity_strip();

-- ── Money, but only the shared kind ─────────────────────────────────
--
-- ⚠️ **The privacy line in this file.** `finance_accounts.visible_to_partner`
-- exists precisely so a personal wallet stays personal, and 0016's RLS
-- honours it. An activity row is not filtered by that policy — it is a
-- second, plainer copy of the account's name — so logging a private wallet
-- here would leak into the partner's feed exactly what the flag was added
-- to hide. Shared and opted-in only.
create or replace function public.tg_activity_account() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.owner_id is not null and new.visible_to_partner is not true then
    return null;
  end if;
  perform public.log_activity(
    new.pair_id, new.created_by, 'account_added',
    new.name, new.emoji, new.id, '{}'::jsonb
  );
  return null;
end $$;

drop trigger if exists activity_account_ins on public.finance_accounts;
create trigger activity_account_ins after insert on public.finance_accounts
  for each row execute function public.tg_activity_account();

-- Budgets carry no visibility flag of their own, so the conservative read
-- applies: only a budget with no owner is unambiguously the couple's.
create or replace function public.tg_activity_budget() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.owner_id is not null then
    return null;
  end if;
  perform public.log_activity(
    new.pair_id, new.created_by, 'budget_set',
    new.name, new.emoji, new.id,
    jsonb_build_object('limit_amount', new.limit_amount,
                       'currency', new.currency)
  );
  return null;
end $$;

drop trigger if exists activity_budget_ins on public.finance_budgets;
create trigger activity_budget_ins after insert on public.finance_budgets
  for each row execute function public.tg_activity_budget();

-- Spending is NOT logged, on purpose. Every entry is money moving, most of
-- it is routine, and a feed that fills up with "spent 40 on groceries"
-- buries the three things a day that are actually worth a tap.

-- ════════════════════════════════════════════════════════════════════
-- 5. Nothing is backfilled
-- ════════════════════════════════════════════════════════════════════
--
-- The feed starts empty and fills as the two of you use the app. A backfill
-- was considered and rejected: `created_at` on the source rows would make
-- every reminder ever set land in the timeline at once, dated correctly and
-- read as a wall of stale news on the first launch after this ships. An
-- empty "nothing yet" state is the better first impression, and it is
-- accurate.

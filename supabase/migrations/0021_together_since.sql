-- Dayflower — the couple's own page: when you started, and the numbers.
-- Run in the Supabase SQL editor, or: dart run tool/run_sql.dart <this file>
--
-- Safe to re-run. Additive only.

-- ════════════════════════════════════════════════════════════════════
-- 1. When you started
-- ════════════════════════════════════════════════════════════════════
--
-- A `date`, not a timestamptz. "We got together on 10 April 2022" is a
-- calendar fact, not an instant: it has no time of day, and storing one
-- would mean the anniversary lands on a different day for each of you the
-- moment you are in different timezones — which, in this app, is the
-- normal case rather than the edge case.
--
-- Nullable, because a couple exists before anyone gets around to entering
-- it. Null means "not said yet" and the app asks rather than guessing.
-- Everything derived from it — days together, the monthsary, the
-- anniversary — simply does not appear until it is set.
alter table public.pairs
  add column if not exists together_since date;

-- ════════════════════════════════════════════════════════════════════
-- 2. Letting a linked couple write to their own row
-- ════════════════════════════════════════════════════════════════════
--
-- 🔴 **Nothing could update a linked pair before this.** The only update
-- policy was `pairs_accept_invite`, which requires `user_b is null` — it
-- exists to let the second partner join and nothing else. So an UPDATE
-- setting `together_since` matched no rows, and PostgREST reports that as
-- **success with zero rows changed**: the app would have said "saved" and
-- the date would silently never appear. Found by reading 0001, not by
-- running it.
drop policy if exists "pairs_update_details" on public.pairs;
create policy "pairs_update_details" on public.pairs
  for update using (
    user_b is not null and (auth.uid() = user_a or auth.uid() = user_b)
  ) with check (
    user_b is not null and (auth.uid() = user_a or auth.uid() = user_b)
  );

-- ⚠️ That policy is deliberately broad — a policy cannot compare OLD to
-- NEW, so it cannot say "you may change this column but not that one", and
-- 0002 granted UPDATE on every column. Without the trigger below, either
-- partner could rewrite `user_a`, `user_b` or the invite code and quietly
-- repoint the pair at somebody else. The trigger is what makes the policy
-- safe, so the two belong together: do not keep one without the other.
create or replace function public.pairs_lock_identity() returns trigger
language plpgsql as $$
begin
  -- Who the pair is never changes. `user_b` is the one exception, and only
  -- in one direction: null → set, which is joining. Once somebody has
  -- joined, that is who they are.
  new.user_a := old.user_a;
  if old.user_b is not null then
    new.user_b := old.user_b;
  end if;
  new.invite_code := old.invite_code;
  new.created_at := old.created_at;
  return new;
end $$;

drop trigger if exists pairs_identity_locked on public.pairs;
create trigger pairs_identity_locked before update on public.pairs
  for each row execute function public.pairs_lock_identity();

-- ════════════════════════════════════════════════════════════════════
-- 3. The numbers on the Us page
-- ════════════════════════════════════════════════════════════════════
--
-- One round trip for all of them, rather than four counts and a scan from
-- the client. The counts especially: the app's heartbeat stream is capped
-- at the newest 500 taps, so counting them client-side would quietly stop
-- at 500 and the couple's total would sit there looking like a plateau.
--
-- **SECURITY INVOKER** (the default, stated here because it matters): this
-- reads through the caller's own RLS, so it can only ever total up a pair
-- the caller belongs to. The membership check below is belt and braces —
-- and it is what makes the answer *zero* rather than *nothing* for a pair
-- that is not yours.
create or replace function public.couple_stats(
  p_pair uuid,
  -- The viewer's offset from UTC, in minutes. A streak has to be counted in
  -- whole days, and "which day is it" is a different answer in Manila and
  -- Dubai — so the day boundary is the *reader's*, not the server's.
  -- Without this a couple would watch their streak break at 4am.
  p_offset_minutes int default 0
)
returns table (
  hearts bigint,
  flowers bigint,
  photos bigint,
  messages bigint,
  streak int
)
language plpgsql
stable
as $$
declare
  shift interval := make_interval(mins => p_offset_minutes);
  today date;
  run int := 0;
  cursor_day date;
begin
  if not exists (
    select 1 from public.pairs p
    where p.id = p_pair and (p.user_a = auth.uid() or p.user_b = auth.uid())
  ) then
    return;
  end if;

  today := (now() + shift)::date;

  select
    (select count(*) from public.heartbeats h where h.pair_id = p_pair),
    (select count(*) from public.flower_messages m
       where m.pair_id = p_pair and m.flower_type is not null),
    (select count(*) from public.flower_messages m
       where m.pair_id = p_pair and m.image_path is not null),
    (select count(*) from public.flower_messages m where m.pair_id = p_pair)
  into hearts, flowers, photos, messages;

  -- The streak: consecutive days, counting back from today, on which the
  -- two of you exchanged *anything at all* — a flower, a photo, a message
  -- or a heartbeat. Deliberately generous about what counts, because the
  -- number is about showing up rather than about any one feature.
  --
  -- Today not having happened yet does not break it: the walk starts at
  -- today and, if today is empty, tries yesterday once. Otherwise every
  -- streak in the app would read zero until somebody sent something after
  -- midnight.
  with active as (
    select distinct ((sent_at + shift)::date) as d
    from public.flower_messages where pair_id = p_pair
    union
    select distinct ((sent_at + shift)::date)
    from public.heartbeats where pair_id = p_pair
  )
  select coalesce(max(d), null) into cursor_day from active;

  if cursor_day is null then
    streak := 0;
    return next;
    return;
  end if;

  -- Anything older than yesterday means the run has already ended.
  if cursor_day < today - 1 then
    streak := 0;
    return next;
    return;
  end if;

  loop
    exit when not exists (
      select 1 from public.flower_messages
        where pair_id = p_pair and (sent_at + shift)::date = cursor_day
      union all
      select 1 from public.heartbeats
        where pair_id = p_pair and (sent_at + shift)::date = cursor_day
    );
    run := run + 1;
    cursor_day := cursor_day - 1;
    -- A hard stop, so a decade of daily use cannot turn one card into a
    -- 3,650-iteration scan every time Us is opened.
    exit when run >= 3650;
  end loop;

  streak := run;
  return next;
end $$;

-- Callable by signed-in users only. RLS inside the function is what limits
-- *which* pair they can total up; this just keeps it off the anon role.
revoke all on function public.couple_stats(uuid, int) from public;
grant execute on function public.couple_stats(uuid, int) to authenticated;

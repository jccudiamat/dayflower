-- Dayflower — how much calling you have done this month.
-- Run in the Supabase SQL editor, or: dart run tool/run_sql.dart <this file>
--
-- Safe to re-run. Additive only. Reads existing rows; creates no columns.
--
-- ## Why the app counts its own minutes
--
-- The quota being measured belongs to the media provider, and their number
-- lives in their dashboard behind an account-level API key that must never
-- reach a phone. Rather than proxy that, this counts the calls the app
-- already recorded: every call is a row with `sent_at` and `call_ended_at`
-- (migration 0025), so the month's total is one aggregate over data we own.
--
-- It runs a few percent light — it misses the seconds spent negotiating
-- media, and it cannot see a call placed from anywhere but this app. For
-- deciding "can we do video tonight, or should we keep it audio", a few
-- percent does not matter. If billing accuracy is ever needed, that is the
-- provider's dashboard, not this.
--
-- ⚠️ **`security invoker`, deliberately** — the opposite choice from
-- `end_call` and `livekit_token`, which need to bypass RLS to do their job.
-- This one wants RLS: 0001's select policy already limits `flower_messages`
-- to your own pair, so passing someone else's pair id returns zeros rather
-- than their call history. A definer here would have been a data leak with
-- no upside.
create or replace function public.call_usage(
  p_pair uuid,
  p_offset_minutes int default 0
)
returns table (
  voice_seconds bigint,
  video_seconds bigint,
  calls int
)
language sql
stable
as $$
  with bounds as (
    -- The month boundary is the reader's, not UTC's. A couple split across
    -- Dubai and Manila would otherwise watch the meter reset on different
    -- days — the same reason `couple_stats` takes an offset for the streak.
    select date_trunc(
             'month',
             now() + make_interval(mins => p_offset_minutes)
           ) - make_interval(mins => p_offset_minutes) as month_start
  )
  select
    coalesce(sum(extract(epoch from m.call_ended_at - m.sent_at))
             filter (where m.call_mode = 'voice'), 0)::bigint,
    coalesce(sum(extract(epoch from m.call_ended_at - m.sent_at))
             filter (where m.call_mode = 'video'), 0)::bigint,
    count(*)::int
  from public.flower_messages m, bounds b
  where m.pair_id = p_pair
    and m.call_mode is not null
    -- Only finished calls. A live one is counted when it ends, which keeps
    -- the meter from creeping upward while somebody watches it.
    and m.call_ended_at is not null
    and m.sent_at >= b.month_start;
$$;

revoke all on function public.call_usage(uuid, int) from public;
grant execute on function public.call_usage(uuid, int) to authenticated;

-- The aggregate filters on (pair_id, call_mode, sent_at); `flower_live_call_idx`
-- from 0025 is partial on live calls only, so it cannot serve this. The
-- 0004 index (pair_id, sent_at desc) does, and the call rows are a tiny
-- fraction of the thread, so no new index is worth its write cost here.

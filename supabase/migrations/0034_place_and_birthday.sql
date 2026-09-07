-- ─────────────────────────────────────────────────────────────────────
-- 0034 — Where each person actually is, and when they were born.
--
-- TIMEZONE WAS DOING TWO JOBS AND ONLY ONE OF THEM WELL.
--
-- `users.timezone` drives the dual clocks, correctly. It was also driving
-- the "4,000 miles apart" line, via a table of one representative city per
-- IANA zone (lib/core/utils/zone_distance.dart). That is an estimate by
-- construction: everyone in Asia/Manila was placed in Manila, so someone in
-- Tuguegarao City was measured from ~300 miles away from where they are.
--
-- So the place is now its own thing. The zone stays the clock; the city and
-- its coordinates are the distance. They are set together when a city is
-- picked (a city knows its own timezone) but they are separate columns,
-- because someone travelling changes one and not the other.
--
-- BIRTHDAY IS A DATE, NOT A TIMESTAMP. There is no hour, no zone and no
-- "which day is it where you are" — a birthday is the same calendar date
-- everywhere, and storing it as an instant would move it across midnight
-- for exactly the long-distance couples this app is for.
-- ─────────────────────────────────────────────────────────────────────

alter table public.users
  add column if not exists city text,
  add column if not exists city_lat double precision,
  add column if not exists city_lon double precision,
  add column if not exists birthday date;

comment on column public.users.city is
  'Display label for where they are, e.g. "Tuguegarao City, Cagayan, Philippines". Free text: it is shown, never parsed.';
comment on column public.users.city_lat is
  'Latitude of city, for the distance line. Null until a city is picked, which is why the zone estimate is still the fallback.';
comment on column public.users.city_lon is
  'Longitude of city. Always written together with city_lat.';
comment on column public.users.birthday is
  'Optional. Drives the derived birthday entries on Events for both members of a pair.';

-- ⚠️ No new policies. These are columns on `users`, which already has the
-- pair-scoped select policy the partner profile reads through and the
-- self-only update policy. A column added to a table inherits both; adding
-- a policy here would be adding a second, looser rule for the same rows.

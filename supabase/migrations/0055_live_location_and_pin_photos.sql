-- Two things for the travel map.
--
-- ── 1. Where each of you actually is ─────────────────────────────────
--
-- Until now the map placed people by the city they picked (0034). This adds
-- an exact spot, shared only by someone who turns it on, taken only while
-- the app is open on their phone: no background tracking, no permission
-- beyond "while using the app".
--
-- ⚠️ **One row per person, the latest spot, and nothing else.** No history:
-- every update overwrites the row, and turning sharing off deletes it. A
-- trail of where somebody has been is a different and much heavier thing
-- than "where are they now", and nothing asked for it.
--
-- 🔴 **Readable by the two of you and nobody else.** Select is your own row
-- or a row in a pair you are in; writes are your own row, into your own
-- pair. A person in no pair can share with nobody.

create table if not exists public.live_locations (
  user_id uuid primary key references public.users (id) on delete cascade,
  pair_id uuid not null references public.pairs (id) on delete cascade,
  lat double precision not null check (lat between -90 and 90),
  lon double precision not null check (lon between -180 and 180),
  -- Metres, as the phone reports it: a few for GPS outdoors, hundreds when
  -- only "approximate" was allowed.
  accuracy_m real check (accuracy_m >= 0),
  -- The town the phone's geocoder named, for the map's label. Null when it
  -- could not say.
  place text check (place is null or char_length(place) <= 120),
  updated_at timestamptz not null default now()
);

create index if not exists live_locations_pair_idx on public.live_locations (pair_id);

alter table public.live_locations enable row level security;

create policy "live_locations_select_pair" on public.live_locations
  for select using (
    user_id = auth.uid()
    or exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "live_locations_insert_self" on public.live_locations
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "live_locations_update_self" on public.live_locations
  for update using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "live_locations_delete_self" on public.live_locations
  for delete using (user_id = auth.uid());

grant select, insert, update, delete on public.live_locations to authenticated;

-- Live on the other phone, so a pin moves while the map is open.
do $$
begin
  alter publication supabase_realtime add table public.live_locations;
exception
  when duplicate_object then null;
end $$;

-- 🔴 Turning sharing off is a DELETE, and realtime checks the select policy
-- against the old tuple, which by default is only the key: without this the
-- partner's map would keep showing the spot until it was rebuilt. See 0047.
alter table public.live_locations replica identity full;

-- ── 2. A photo, a date and a few words on a pin ─────────────────────────
--
-- A pin could carry a photo already, but only one from the chat
-- (message_id). Now it can have its own: the map draws a pin that has one
-- as the photo itself, and the rest (the place, when, what it was) shows
-- when it is tapped.
--
-- photo_path is in the private day_photos bucket under the pair's folder
-- (`<pair_id>/pin-<uuid>.jpg`), so 0013's policies already cover it: the
-- pair reads, the uploader writes and deletes. No new bucket.

alter table public.map_pins
  add column if not exists photo_path text,
  add column if not exists visited_on date,
  add column if not exists note text
    check (note is null or char_length(note) <= 500);

-- The travel map: where you have been, and where you want to go.
--
-- ⚠️ **Its own table, not columns on `flower_messages`.** The obvious move is
-- to hang `place_lat`/`place_lon` off the photo they belong to, and 0004
-- makes that impossible: only the *recipient* may update a message, so the
-- person who took the photo could never say where it was taken. The same
-- wall the reactions table hit in 0045, for the same reason -- RLS grants a
-- row and not a column.
--
-- It also buys the half of the feature the tile has always promised. "Where
-- you've been, where next" needs pins with no photo behind them, and a
-- column on a message cannot express a place neither of you has been yet.
--
-- 🔴 **The coordinates come from the city picker, not from the phone.** No
-- location permission, no background tracking, nothing read off a photo's
-- EXIF. A pin is somewhere one of them chose to name, and the app already
-- knows how to search cities -- see `core/services/city_search.dart` and the
-- `city_lat`/`city_lon` already on `users`. For a couple who are mostly
-- apart, a map that quietly knew where each of them was standing is a
-- different and much heavier thing than the one being asked for.

create table if not exists public.map_pins (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  created_by uuid not null references public.users (id) on delete cascade,

  -- The photo this pin shows, when it has one. Null for a place you have
  -- not been yet.
  --
  -- ⚠️ `set null`, not `cascade`: deleting a photo from the thread must not
  -- silently remove the place from your map. The pin stays, and loses its
  -- picture -- the same rule `reply_to` follows in 0023.
  message_id uuid references public.flower_messages (id) on delete set null,

  -- What the pin says on the map. "Beach day", not the city name.
  label text not null check (char_length(trim(label)) between 1 and 60),

  -- Where the city picker put it.
  place text not null,
  lat double precision not null check (lat between -90 and 90),
  lon double precision not null check (lon between -180 and 180),

  -- Somewhere you have been together, or somewhere you mean to go.
  visited boolean not null default true,

  created_at timestamptz not null default now()
);

create index if not exists map_pins_pair_idx on public.map_pins (pair_id);

alter table public.map_pins enable row level security;

-- The map belongs to both of you: either can see every pin on it.
create policy "map_pins_select_pair_members" on public.map_pins
  for select using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Writing is self-only and into your own pair. The first stops you dropping
-- a pin as your partner, the second stops a pair_id from somebody else's
-- map being posted at all.
create policy "map_pins_insert_self" on public.map_pins
  for insert with check (
    auth.uid() = created_by
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- ⚠️ Update and delete are **pair-wide, not self-only**, unlike reactions.
-- A shared map is a thing two people build together: fixing a typo on a pin
-- your partner dropped is collaboration, not vandalism. A reaction is a
-- statement by one person about one message, which is why that one is yours
-- alone.
create policy "map_pins_update_pair_members" on public.map_pins
  for update using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "map_pins_delete_pair_members" on public.map_pins
  for delete using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Live on the other phone, like reactions and unlike presence: a pin is
-- rare, small, and worth seeing appear while you are both looking at the map.
do $$
begin
  alter publication supabase_realtime add table public.map_pins;
exception
  when duplicate_object then null;
end $$;

-- 🔴 Removing a pin is a DELETE, and realtime checks the SELECT policy
-- against the *old* tuple before forwarding it. With the default replica
-- identity that tuple is only the primary key, so `pair_id` is null, "am I
-- in this pair" cannot be true, and the event is dropped as one this client
-- may not see -- the pin stays on the other phone until the map is rebuilt.
-- Caught the hard way on message_reactions in 0045.
alter table public.map_pins replica identity full;

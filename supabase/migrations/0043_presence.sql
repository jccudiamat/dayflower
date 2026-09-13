-- "Active now", for the chat header.
--
-- A heartbeat, written by the app roughly once a minute while it is in the
-- foreground, and read by the other phone while the conversation is open.
--
-- ⚠️ **Its own table, not a column on `users`.** `users` is in the realtime
-- publication (migration 0024, so a mood lands on the other phone while they
-- are looking at it). Putting a once-a-minute heartbeat on that row would
-- broadcast the entire profile to the partner every minute, all day, for a
-- value nobody is looking at unless the chat is open. This table is
-- deliberately left OUT of the publication and polled instead: it costs
-- nothing at all while the app is closed, and one small select every half
-- minute while somebody is actually reading the header.
--
-- 🔴 Presence is the most privacy-sensitive thing in the app: it says when
-- somebody is awake and on their phone. So it is readable by exactly one
-- other person — the partner — under the same rule as the profile itself,
-- and it stores a single timestamp. Never a location, never a screen name,
-- never what they are doing in the app.

create table if not exists public.presence (
  user_id uuid primary key references public.users (id) on delete cascade,
  last_active_at timestamptz not null default now()
);

alter table public.presence enable row level security;

-- Same reach as the profile row it describes: yourself, or the person you
-- are paired with. Mirrors "users_select_self_or_partner" in 0001.
create policy "presence_select_self_or_partner" on public.presence
  for select using (
    auth.uid() = user_id
    or exists (
      select 1 from public.pairs p
      where (p.user_a = auth.uid() and p.user_b = presence.user_id)
         or (p.user_b = auth.uid() and p.user_a = presence.user_id)
    )
  );

-- Writing is self-only, both halves. Without the update policy an upsert
-- from a phone that has beaten once already silently does nothing, and the
-- header freezes at whatever minute the app first opened.
create policy "presence_insert_self" on public.presence
  for insert with check (auth.uid() = user_id);

create policy "presence_update_self" on public.presence
  for update using (auth.uid() = user_id);

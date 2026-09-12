-- Bouquet gifts: the rows behind /g/<id>.
--
-- Why a row at all, when the bouquet already fits in a URL fragment: a
-- fragment is never sent to the server, so Messenger, WhatsApp and Gmail
-- fetching the link see only the generic /bouquet page. Every gift got the
-- same preview card. A link preview has to be server-rendered, and the server
-- can only render what it can read.
--
-- The `#gift=` link still works and stores nothing — it is kept as the
-- private option. This table is what the shareable link needs.
--
-- ⚠️ This is an *encoded* gift, not an encrypted one, exactly as before:
-- anyone with the id can open it and read the note. The id is the secret, so
-- it is generated long and random by the API route, never sequential.

create table if not exists public.bouquet_gifts (
  id text primary key,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  -- A gift link is a keepsake, but not forever: unopened rows would otherwise
  -- accumulate with no owner and no way to ask anyone about them.
  expires_at timestamptz not null default now() + interval '400 days',
  -- Set the first time the recipient opens it. Only ever written by the
  -- definer function below, so a reader cannot forge or clear it.
  opened_at timestamptz,
  constraint bouquet_gifts_id_shape check (id ~ '^[A-Za-z0-9_-]{8,24}$'),
  -- Matches the ceiling the API route enforces. Belt and braces: without it a
  -- single request could park megabytes of JSON in the table.
  constraint bouquet_gifts_payload_size check (octet_length(payload::text) <= 2000000)
);

create index if not exists bouquet_gifts_expires_idx on public.bouquet_gifts (expires_at);

alter table public.bouquet_gifts enable row level security;

-- 0002 hands `authenticated` every privilege on new tables by default, and
-- this table is public-facing, so the grants are spelled out rather than
-- inherited. No update and no delete for anyone: a gift is immutable once
-- sent, which is also what makes "the original link keeps its original
-- flowers" true rather than aspirational.
revoke all on public.bouquet_gifts from anon, authenticated;
grant select, insert on public.bouquet_gifts to anon, authenticated;

drop policy if exists "anyone may create a gift" on public.bouquet_gifts;
create policy "anyone may create a gift" on public.bouquet_gifts
  for insert to anon, authenticated with check (true);

-- Reading is by id only. There is no policy that permits a scan, so a client
-- cannot list gifts; `expires_at` keeps an old id from resolving forever.
drop policy if exists "a gift may be read while it lives" on public.bouquet_gifts;
create policy "a gift may be read while it lives" on public.bouquet_gifts
  for select to anon, authenticated using (expires_at > now());

-- Marks a gift opened without widening the table's update policy, the same
-- shape as end_call() in 0025: a definer function writes the one column.
create or replace function public.open_bouquet_gift(gift_id text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.bouquet_gifts
     set opened_at = now()
   where id = gift_id and opened_at is null and expires_at > now();
$$;

revoke all on function public.open_bouquet_gift(text) from public;
grant execute on function public.open_bouquet_gift(text) to anon, authenticated;

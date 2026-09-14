begin;

create table if not exists public.couple_events (
  pair_id uuid not null references public.pairs(id) on delete cascade,
  id bigint not null check (id > 0),
  kind text not null check (kind in ('reunion','anniversary','birthday','monthsary','custom')),
  title text not null check (length(trim(title)) between 1 and 200),
  date date not null,
  emoji text not null default '⭐',
  location text not null default '',
  note text not null default '',
  primary key (pair_id, id)
);
alter table public.couple_events enable row level security;
grant select, insert, update, delete on public.couple_events to authenticated;
drop policy if exists events_pair on public.couple_events;
create policy events_pair on public.couple_events for all to authenticated
using (exists (select 1 from public.pairs p where p.id = pair_id and auth.uid() in (p.user_a,p.user_b)))
with check (exists (select 1 from public.pairs p where p.id = pair_id and auth.uid() in (p.user_a,p.user_b)));

create table if not exists public.gift_favorites (
  user_id uuid not null references public.users(id) on delete cascade,
  product_id text not null check (length(product_id) between 1 and 200),
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);
-- Product ids may originate in the bundled offline catalog. Preserve the
-- bookmark even if a catalog item is temporarily removed from the server.
alter table public.gift_favorites enable row level security;
grant select, insert, update, delete on public.gift_favorites to authenticated;
drop policy if exists favorites_owner on public.gift_favorites;
create policy favorites_owner on public.gift_favorites for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='couple_events') then
    alter publication supabase_realtime add table public.couple_events;
  end if;
end $$;
notify pgrst, 'reload schema';
commit;

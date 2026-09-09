create table if not exists public.pair_greetings (
  id text primary key,
  pair_id uuid not null references public.pairs(id) on delete cascade,
  title text not null,
  message text not null,
  artwork text not null,
  created_at timestamptz not null default now()
);
alter table public.pair_greetings enable row level security;
drop policy if exists pair_greetings_read on public.pair_greetings;
create policy pair_greetings_read on public.pair_greetings for select to authenticated
using (exists (select 1 from public.pairs p where p.id = pair_id and auth.uid() in (p.user_a, p.user_b)));
grant select on public.pair_greetings to authenticated;
grant all on public.pair_greetings to service_role;

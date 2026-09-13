-- Prepare the shared limiter before deploying the server-only website routes.
-- No public data is removed. Only keyed hashes and bounded counters are kept.
begin;
create table if not exists public.website_rate_buckets (
  bucket text primary key,
  hits integer not null check (hits >= 0),
  expires_at timestamptz not null
);
create index if not exists website_rate_expiry_idx on public.website_rate_buckets(expires_at);
alter table public.website_rate_buckets enable row level security;
revoke all on public.website_rate_buckets from public, anon, authenticated;
grant select, insert, update, delete on public.website_rate_buckets to service_role;

create or replace function public.claim_website_request(p_action text, p_sender text, p_recipient text default null, p_gift text default null)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  keys text[];
  ceilings integer[];
  ends timestamptz[];
  hour_start timestamptz := date_trunc('hour', now());
  day_start timestamptz := date_trunc('day', now() at time zone 'UTC') at time zone 'UTC';
  sender_hour integer;
  sender_day integer;
  global_hour integer;
  global_day integer;
  i integer;
begin
  if p_action is null or p_action not in ('gift-create', 'waitlist', 'gift-email', 'gift-read') or p_sender is null or p_sender !~ '^[a-f0-9]{64}$' then
    raise exception 'Invalid request limit parameters';
  end if;
  if p_recipient is not null and p_recipient !~ '^[a-f0-9]{64}$' then raise exception 'Invalid recipient'; end if;
  if p_gift is not null and p_gift !~ '^[A-Za-z0-9_-]{8,24}$' then raise exception 'Invalid gift'; end if;
  if p_action in ('waitlist', 'gift-email') and p_recipient is null then raise exception 'Missing recipient'; end if;
  if p_action = 'gift-email' and p_gift is null then raise exception 'Missing gift'; end if;

  if p_action = 'gift-create' then sender_hour := 10; sender_day := 40; global_hour := 250; global_day := 1000;
  elsif p_action = 'waitlist' then sender_hour := 5; sender_day := 10; global_hour := 100; global_day := 500;
  elsif p_action = 'gift-read' then sender_hour := 300; sender_day := 1000; global_hour := 2000; global_day := 10000;
  else sender_hour := 5; sender_day := 10; global_hour := 100; global_day := 300;
  end if;

  -- Serialize the full check/increment, including global ceilings, across
  -- concurrent requests and all website instances. PUBLIC cannot call this.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('website-limit:' || p_action, 0));
  delete from public.website_rate_buckets where expires_at <= now();
  keys := array[p_action || ':global:h:' || hour_start::text, p_action || ':global:d:' || day_start::text,
                p_action || ':sender:h:' || p_sender || ':' || hour_start::text, p_action || ':sender:d:' || p_sender || ':' || day_start::text];
  ceilings := array[global_hour, global_day, sender_hour, sender_day];
  ends := array[hour_start + interval '1 hour', day_start + interval '1 day', hour_start + interval '1 hour', day_start + interval '1 day'];
  if p_recipient is not null then
    keys := array_append(keys, p_action || ':recipient:' || p_recipient || ':' || day_start::text);
    ceilings := array_append(ceilings, 3); ends := array_append(ends, day_start + interval '1 day');
  end if;
  if p_gift is not null then
    keys := array_append(keys, p_action || ':gift:' || p_gift || ':' || day_start::text);
    ceilings := array_append(ceilings, 3); ends := array_append(ends, day_start + interval '1 day');
  end if;
  for i in 1..array_length(keys, 1) loop
    if coalesce((select hits from public.website_rate_buckets where bucket = keys[i]), 0) >= ceilings[i] then return false; end if;
  end loop;
  for i in 1..array_length(keys, 1) loop
    insert into public.website_rate_buckets(bucket, hits, expires_at) values(keys[i], 1, ends[i])
    on conflict(bucket) do update set hits = public.website_rate_buckets.hits + 1;
  end loop;
  return true;
end;
$$;
revoke all on function public.claim_website_request(text, text, text, text) from public, anon, authenticated;
grant execute on function public.claim_website_request(text, text, text, text) to service_role;
grant select, insert on public.bouquet_gifts to service_role;
grant insert(email, source) on public.waitlist to service_role;
commit;

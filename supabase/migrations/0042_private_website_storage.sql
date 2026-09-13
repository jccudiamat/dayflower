-- Apply after deploying the server-only website routes. Preserve all gifts
-- and signups; revoke direct client access instead of dropping any data.
begin;
revoke all on public.bouquet_gifts from public, anon, authenticated;
drop policy if exists "anyone may create a gift" on public.bouquet_gifts;
drop policy if exists "a gift may be read while it lives" on public.bouquet_gifts;
revoke all on function public.open_bouquet_gift(text) from public, anon, authenticated;
revoke all on function public.claim_gift_email(text, text) from public, anon, authenticated;
revoke all on public.waitlist from public, anon, authenticated;
revoke insert(email, source) on public.waitlist from public, anon, authenticated;
drop policy if exists waitlist_insert_anon on public.waitlist;

-- Enforce lifetime and core shape for future inserts without invalidating
-- legacy keepsakes. Only the trusted website can now insert these rows.
create or replace function public.validate_new_website_gift()
returns trigger language plpgsql set search_path = '' as $$
begin
  if jsonb_typeof(new.payload) is distinct from 'object'
     or new.payload->>'v' is distinct from '1'
     or jsonb_typeof(new.payload->'stems') is distinct from 'array'
     or jsonb_typeof(new.payload->'to') is distinct from 'string'
     or jsonb_typeof(new.payload->'from') is distinct from 'string'
     or jsonb_typeof(new.payload->'message') is distinct from 'string' then raise exception 'Invalid gift'; end if;
  if jsonb_array_length(new.payload->'stems') > 24 or length(new.payload->>'to') > 40
     or length(new.payload->>'from') > 40 or length(new.payload->>'message') > 280 then raise exception 'Invalid gift'; end if;
  if new.payload ? 'photos' then
    if jsonb_typeof(new.payload->'photos') is distinct from 'array' then raise exception 'Invalid photos'; end if;
    if jsonb_array_length(new.payload->'photos') > 8 then raise exception 'Too many photos'; end if;
  end if;
  new.created_at := now(); new.expires_at := now() + interval '400 days'; new.opened_at := null;
  return new;
end;
$$;
revoke all on function public.validate_new_website_gift() from public, anon, authenticated;
drop trigger if exists validate_website_gift on public.bouquet_gifts;
create trigger validate_website_gift before insert on public.bouquet_gifts for each row execute function public.validate_new_website_gift();
commit;

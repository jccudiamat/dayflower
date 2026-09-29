-- Expand the gift note capacity without changing grants, existing gifts, or expiry.
begin;
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
     or length(new.payload->>'from') > 40 or length(new.payload->>'message') > 2000 then raise exception 'Invalid gift'; end if;
  if new.payload ? 'photos' then
    if jsonb_typeof(new.payload->'photos') is distinct from 'array' then raise exception 'Invalid photos'; end if;
    if jsonb_array_length(new.payload->'photos') > 8 then raise exception 'Too many photos'; end if;
  end if;
  new.created_at := now(); new.expires_at := now() + interval '400 days'; new.opened_at := null;
  return new;
end;
$$;
revoke all on function public.validate_new_website_gift() from public, anon, authenticated;
commit;

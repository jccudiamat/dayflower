-- Preserve all existing signups. Service-only email receipt/claim tracking.
alter table public.waitlist
  add column if not exists confirmation_attempted_at timestamptz,
  add column if not exists confirmation_accepted_at timestamptz,
  add column if not exists confirmation_provider_id text;

create or replace function public.claim_waitlist_confirmation(p_email text)
returns table (signup_id uuid, delivery_state text)
language plpgsql security definer set search_path = public
as $$
declare signup public.waitlist%rowtype;
begin
  select * into signup from public.waitlist
    where lower(email) = lower(p_email) for update;
  if not found then return; end if;
  if signup.confirmation_accepted_at is not null then
    return query select signup.id, 'accepted'::text;
  elsif signup.confirmation_attempted_at > now() - interval '5 minutes' then
    return query select signup.id, 'pending'::text;
  else
    update public.waitlist set confirmation_attempted_at = now() where id = signup.id;
    return query select signup.id, 'claimed'::text;
  end if;
end;
$$;
revoke all on function public.claim_waitlist_confirmation(text) from public, anon, authenticated;
grant execute on function public.claim_waitlist_confirmation(text) to service_role;
grant select, update on public.waitlist to service_role;
-- Public signup clients cannot forge internal confirmation receipt fields.
revoke insert on public.waitlist from anon, authenticated;
grant insert (email, source) on public.waitlist to anon, authenticated;

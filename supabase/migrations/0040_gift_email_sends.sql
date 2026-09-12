-- Rate limiting for "email me this gift".
--
-- ⚠️ Without this the endpoint is an open mail relay: anyone could POST an
-- arbitrary address and have our domain deliver to it. That gets the Resend
-- account suspended and mydayflower.com onto spam lists, which would take
-- the waitlist confirmation down with it.
--
-- Two ceilings, because they stop different abuses:
--   • per sender  — one person cannot blast many addresses
--   • per gift    — one gift cannot be mailed to an address over and over
--
-- **The recipient's address is never stored.** The gift is sent and
-- forgotten; all that is kept is which gift was mailed and a salted hash of
-- the sender's IP, which is what the limits are counted against.

create table if not exists public.gift_email_sends (
  id bigserial primary key,
  gift_id text not null,
  sender_hash text not null,
  created_at timestamptz not null default now()
);

create index if not exists gift_email_sends_sender_idx on public.gift_email_sends (sender_hash, created_at desc);
create index if not exists gift_email_sends_gift_idx on public.gift_email_sends (gift_id, created_at desc);

alter table public.gift_email_sends enable row level security;

-- No policies at all, so RLS denies everything: the table is reachable only
-- through the definer function below. 0002 hands `authenticated` privileges
-- on new tables by default, hence the explicit revoke.
revoke all on public.gift_email_sends from anon, authenticated;
revoke all on sequence public.gift_email_sends_id_seq from anon, authenticated;

-- Checks the ceilings and records the send in one statement, so two requests
-- racing cannot both see room under the limit and both proceed.
create or replace function public.claim_gift_email(p_gift_id text, p_sender_hash text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  per_sender integer;
  per_gift integer;
begin
  -- Nothing here is worth keeping once it can no longer affect a decision.
  delete from public.gift_email_sends where created_at < now() - interval '7 days';

  select count(*) into per_sender
    from public.gift_email_sends
   where sender_hash = p_sender_hash and created_at > now() - interval '1 hour';

  select count(*) into per_gift
    from public.gift_email_sends
   where gift_id = p_gift_id and created_at > now() - interval '1 day';

  if per_sender >= 5 or per_gift >= 3 then
    return false;
  end if;

  insert into public.gift_email_sends (gift_id, sender_hash) values (p_gift_id, p_sender_hash);
  return true;
end;
$$;

revoke all on function public.claim_gift_email(text, text) from public;
grant execute on function public.claim_gift_email(text, text) to anon, authenticated;

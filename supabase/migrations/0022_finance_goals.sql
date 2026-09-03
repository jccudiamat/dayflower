-- Dayflower — savings goals.
-- Run in the Supabase SQL editor, or: dart run tool/run_sql.dart <this file>
--
-- Safe to re-run. Additive only.
--
-- A goal is a target and a way of measuring progress towards it. The two
-- ways it can be measured are the whole design:
--
--   account_id set   → progress IS that account's balance, derived
--   account_id null  → progress is `saved_amount`, a number you top up
--
-- ⚠️ **Prefer the linked form.** This project's rule is that balances are
-- derived and never stored (see the header of `finance_summary.dart`),
-- precisely so a number cannot drift from the thing it claims to describe.
-- A goal linked to a savings pot maintains itself and can never disagree
-- with the pot. `saved_amount` exists for the goal that has no account of
-- its own — cash in a drawer, a pot shared with other money — and it is a
-- number somebody has to keep honest by hand.

create table if not exists public.finance_goals (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,

  -- Null = the couple's goal, same convention as accounts and budgets.
  owner_id uuid references public.users (id) on delete cascade,

  name text not null check (length(trim(name)) > 0),
  emoji text not null default '🎯',

  target_amount numeric(14, 2) not null check (target_amount > 0),

  -- Only read when `account_id` is null. Not a constraint, because a goal
  -- that gets linked to an account later should keep whatever was typed
  -- before, in case the link is removed again.
  saved_amount numeric(14, 2) not null default 0 check (saved_amount >= 0),

  -- ⚠️ The goal's own currency, not the couple's main one. A car saved for
  -- in AED is an AED target, and converting it for storage would round the
  -- target every time a rate moved. Conversion happens only when goals are
  -- totalled together — same rule as every other amount in this schema.
  currency text not null default 'PHP',

  -- `set null` rather than cascade: deleting the savings account must not
  -- delete the goal it was funding. The goal falls back to `saved_amount`,
  -- which is a worse answer than a derived balance but a much better one
  -- than the goal vanishing.
  account_id uuid references public.finance_accounts (id) on delete set null,

  -- Optional. Null means "no deadline", which is most goals.
  target_date date,

  archived boolean not null default false,
  created_by uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists finance_goals_pair_idx
  on public.finance_goals (pair_id, archived, created_at);

alter table public.finance_goals enable row level security;

-- ── RLS ─────────────────────────────────────────────────────────────
--
-- Shared goals are visible to both; a personal goal is visible only to its
-- owner. Deliberately narrower than accounts, which have an opt-in
-- `visible_to_partner` flag: a goal is a plan rather than a balance, and
-- "I am saving for this" is a thing people reasonably keep to themselves
-- until they choose not to.
--
-- Per-command policies, never `for all` — the same shape as 0016.
drop policy if exists "goals_select_scope" on public.finance_goals;
create policy "goals_select_scope" on public.finance_goals
  for select using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
    and (owner_id is null or owner_id = auth.uid())
  );

drop policy if exists "goals_insert_scope" on public.finance_goals;
create policy "goals_insert_scope" on public.finance_goals
  for insert with check (
    created_by = auth.uid()
    and (owner_id is null or owner_id = auth.uid())
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

drop policy if exists "goals_update_scope" on public.finance_goals;
create policy "goals_update_scope" on public.finance_goals
  for update using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
    and (owner_id is null or owner_id = auth.uid())
  );

drop policy if exists "goals_delete_scope" on public.finance_goals;
create policy "goals_delete_scope" on public.finance_goals
  for delete using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
    and (owner_id is null or owner_id = auth.uid())
  );

-- 0002's default privileges cover tables created here, but this project has
-- been bitten by a policy filtering rows on a table the role could not
-- touch at all (42501). Spelled out rather than assumed.
grant select, insert, update, delete on public.finance_goals to authenticated;

-- ⚠️ **Realtime, and this is not optional.** `watchGoals` uses `.stream()`,
-- and a Supabase stream on an unpublished table does not merely fail to
-- update — it never emits at all, so the section renders its empty state
-- forever with the rows sitting right there in the database. Caught exactly
-- that way: the wallet carousel (finance_accounts, published in 0011) drew
-- its cards while the goals beside it insisted there were none.
--
-- Every table this app streams is published. If you add another, add it
-- here too.
do $$
begin
  alter publication supabase_realtime add table public.finance_goals;
exception when duplicate_object then
  null;  -- already published; re-running this file is meant to be safe
end $$;

-- ── Activity feed ───────────────────────────────────────────────────
--
-- A shared goal is news; a personal one is not, for the same reason its RLS
-- is narrower. Same guard as `tg_activity_budget` in 0019.
create or replace function public.tg_activity_goal_saving() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.owner_id is not null then
    return null;
  end if;
  perform public.log_activity(
    new.pair_id, new.created_by, 'saving_goal_set',
    new.name, new.emoji, new.id,
    jsonb_build_object('target', new.target_amount, 'currency', new.currency)
  );
  return null;
end $$;

drop trigger if exists activity_goal_saving_ins on public.finance_goals;
create trigger activity_goal_saving_ins after insert on public.finance_goals
  for each row execute function public.tg_activity_goal_saving();

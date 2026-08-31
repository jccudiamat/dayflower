-- Dayflower — Finance v2
-- Run in the Supabase SQL editor, or: dart run tool/run_sql.dart <this file>
--
-- ⚠️ This EXTENDS 0011 in place. It does not drop anything.
--
-- An earlier draft opened with `drop table ... cascade`, on the strength of
-- PROGRESS.md saying 0011 had never been run. It had: the live database was
-- carrying 2 accounts and 9 entries when this was written. Checking beat
-- trusting the notes, and the notes have since been corrected. Everything
-- here is additive, backfilled, and safe to re-run.
--
-- ── The model in one paragraph ──────────────────────────────────────
--
-- **Accounts hold money, entries move it, budgets cap it.** An account's
-- balance is `opening_balance` plus every entry that touches it — derived,
-- never stored, so a mistyped entry can be deleted and every number it
-- touched corrects itself. That rule comes from 0011 and everything below
-- is built to preserve it.
--
-- ── Ownership and privacy ───────────────────────────────────────────
--
-- `owner_id` stays the shared/solo switch: null = the couple's (this is
-- what "Ours" means, and only these count toward shared net worth), a user
-- id = that partner's own.
--
-- 0011 let partners read each other's solo rows unconditionally. That is
-- reversed here: a solo account is **private by default** and its owner
-- opts in per account via `visible_to_partner`. Entries inherit that from
-- the account they touch rather than carrying their own copy, so there is
-- one switch to reason about and no way for two to disagree.
--
-- ⚠️ Existing solo accounts are backfilled to **private**. That is a
-- deliberate visibility change: rows the partner could previously see
-- become hidden until the owner turns them back on. Privacy is the safe
-- direction to fail in, and it is what was asked for.

-- ════════════════════════════════════════════════════════════════════
-- 1. Extend finance_accounts
-- ════════════════════════════════════════════════════════════════════

alter table public.finance_accounts
  add column if not exists class text not null default 'asset',
  add column if not exists subkind text,
  add column if not exists target_amount numeric(14, 2),
  add column if not exists target_date date,
  add column if not exists credit_limit numeric(14, 2),
  add column if not exists interest_rate numeric(6, 3),
  add column if not exists visible_to_partner boolean not null default false,
  add column if not exists include_in_net_worth boolean not null default true,
  add column if not exists archived boolean not null default false;

-- Asset or liability. Explicit rather than derived from `kind`: a card can
-- be debit or credit and only the owner knows which. Liability balances are
-- held POSITIVE and subtracted when net worth is computed, so "owe 5,000"
-- is 5000 — storing it negative would mean every form had to explain why
-- paying a debt makes the number go up.
alter table public.finance_accounts
  drop constraint if exists finance_accounts_class_check;
alter table public.finance_accounts
  add constraint finance_accounts_class_check
  check (class in ('asset', 'liability'));

-- 0011 allowed five kinds; v2 needs cards, funds, loans and receivables.
alter table public.finance_accounts
  drop constraint if exists finance_accounts_kind_check;
alter table public.finance_accounts
  add constraint finance_accounts_kind_check check (kind in (
    'cash', 'bank', 'ewallet', 'card', 'savings',
    'fund', 'investment', 'loan', 'receivable', 'other'
  ));

update public.finance_accounts
   set class = case when kind in ('card', 'loan') then 'liability' else 'asset' end
 where class is null or class not in ('asset', 'liability');

-- "Ours" and "hidden from you" are contradictory: a shared account is
-- always visible to both, or shared net worth would depend on who is
-- looking. Normalised in a trigger rather than a CHECK — the column
-- defaults to false, so a CHECK would reject every shared insert that
-- simply omitted the flag.
create or replace function public.finance_accounts_normalize()
returns trigger
language plpgsql
as $$
begin
  if new.owner_id is null then
    new.visible_to_partner := true;
  end if;
  return new;
end;
$$;

drop trigger if exists finance_accounts_normalize_biu on public.finance_accounts;
create trigger finance_accounts_normalize_biu
  before insert or update on public.finance_accounts
  for each row execute function public.finance_accounts_normalize();

update public.finance_accounts set visible_to_partner = true where owner_id is null;

create index if not exists finance_accounts_pair_idx
  on public.finance_accounts (pair_id, archived, created_at);

-- ════════════════════════════════════════════════════════════════════
-- 2. Extend finance_entries
-- ════════════════════════════════════════════════════════════════════

alter table public.finance_entries
  add column if not exists budget_id uuid,
  add column if not exists currency text,
  add column if not exists fx_rate numeric(20, 8),
  add column if not exists recurring_id uuid;

-- Backfill from the account each entry touches. Defaulting these to 'PHP'
-- would have silently mislabelled nine AED entries as pesos, and the
-- summary would then have "converted" them — a wrong number that looks
-- exactly like a right one.
update public.finance_entries e
   set currency = a.currency
  from public.finance_accounts a
 where e.account_id = a.id and e.currency is null;

-- Entries whose account was already deleted have nothing to inherit from;
-- fall back to whatever currency the pair actually uses.
update public.finance_entries e
   set currency = coalesce((
         select a.currency from public.finance_accounts a
          where a.pair_id = e.pair_id
          group by a.currency
          order by count(*) desc
          limit 1
       ), 'PHP')
 where e.currency is null;

alter table public.finance_entries alter column currency set default 'PHP';
alter table public.finance_entries alter column currency set not null;

create index if not exists finance_entries_budget_idx
  on public.finance_entries (budget_id, occurred_on desc);

-- ════════════════════════════════════════════════════════════════════
-- 3. Settings — one row per person per pair
-- ════════════════════════════════════════════════════════════════════
-- Per user, not per pair: net worth is shown in *your* main currency, and
-- two partners in different countries will not agree on which that is.
create table if not exists public.finance_settings (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  main_currency text not null default 'PHP',
  updated_at timestamptz not null default now(),
  unique (pair_id, user_id)
);

-- Seed each member with the currency they actually keep money in. Without
-- this the overview would open in PHP against AED accounts, find no rate,
-- and report everything as unconvertible on first run.
insert into public.finance_settings (pair_id, user_id, main_currency)
select p.id, u.uid,
       coalesce((
         select a.currency from public.finance_accounts a
          where a.pair_id = p.id
          group by a.currency
          order by count(*) desc
          limit 1
       ), 'PHP')
  from public.pairs p
  cross join lateral (values (p.user_a), (p.user_b)) as u(uid)
 where u.uid is not null
on conflict (pair_id, user_id) do nothing;

-- ════════════════════════════════════════════════════════════════════
-- 4. Exchange rates
-- ════════════════════════════════════════════════════════════════════
-- One row per currency, all quoted against USD as the anchor, so adding a
-- currency costs one row instead of one per pair of currencies.
-- Converting A→B is `amount / usd_rate(A) * usd_rate(B)`.
--
-- `pinned` is the manual override: the live refresh skips pinned rows.
-- `as_of` is shown wherever a converted total appears, because a total
-- built from a three-week-old rate should say so.
create table if not exists public.finance_rates (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  currency text not null,
  usd_rate numeric(20, 8) not null check (usd_rate > 0),
  source text not null default 'manual' check (source in ('manual', 'live')),
  pinned boolean not null default false,
  as_of timestamptz not null default now(),
  updated_by uuid references public.users (id) on delete set null,
  unique (pair_id, currency)
);

-- ════════════════════════════════════════════════════════════════════
-- 5. Budgets
-- ════════════════════════════════════════════════════════════════════
-- Two shapes in one table:
--   'overall'  → the period's total allowance. At most one per owner.
--   'category' → a cap on one category, drawn from the overall one.
--
-- `funding_account_id` is what "budgets are deducted from cash" means: the
-- account the budget is understood to spend out of. A label on the money,
-- not a second ledger — spending is still entries, so a budget can never
-- disagree with the balance it draws from.
create table if not exists public.finance_budgets (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  owner_id uuid references public.users (id) on delete cascade,
  scope text not null default 'category'
    check (scope in ('overall', 'category')),
  name text not null check (length(trim(name)) > 0),
  category text,
  emoji text not null default '🎯',
  limit_amount numeric(14, 2) not null check (limit_amount >= 0),
  currency text not null default 'PHP',
  period text not null default 'monthly'
    check (period in ('weekly', 'monthly', 'yearly')),
  funding_account_id uuid references public.finance_accounts (id)
    on delete set null,
  rollover boolean not null default false,
  -- Editing a limit mid-year should not rewrite what last March was allowed
  -- to spend, so history reads the row that was in effect then.
  starts_on date not null default current_date,
  archived boolean not null default false,
  created_by uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint finance_budgets_category_named check (
    scope <> 'category' or category is not null
  )
);

create index if not exists finance_budgets_pair_idx
  on public.finance_budgets (pair_id, archived, scope);

-- Partial unique indexes, because a plain unique would let the null owner
-- (shared) through repeatedly.
create unique index if not exists finance_budgets_one_overall_shared
  on public.finance_budgets (pair_id, period)
  where scope = 'overall' and owner_id is null and archived = false;

create unique index if not exists finance_budgets_one_overall_owned
  on public.finance_budgets (pair_id, owner_id, period)
  where scope = 'overall' and owner_id is not null and archived = false;

-- Deferred until finance_budgets exists.
alter table public.finance_entries
  drop constraint if exists finance_entries_budget_fk;
alter table public.finance_entries
  add constraint finance_entries_budget_fk
  foreign key (budget_id) references public.finance_budgets (id)
  on delete set null;

alter table public.finance_entries
  drop constraint if exists finance_budget_only_on_expense;
alter table public.finance_entries
  add constraint finance_budget_only_on_expense
  check (budget_id is null or kind = 'expense');

-- ════════════════════════════════════════════════════════════════════
-- 6. Recurring — subscriptions, salary, rent, loan payments
-- ════════════════════════════════════════════════════════════════════
-- A rule, not a ledger. It posts ordinary entries, so nothing downstream
-- needs to know a recurring rule existed.
create table if not exists public.finance_recurring (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  owner_id uuid references public.users (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  kind text not null check (kind in ('income', 'expense', 'transfer')),
  category text not null default 'Other',
  emoji text not null default '🔁',
  amount numeric(14, 2) not null check (amount > 0),
  currency text not null default 'PHP',
  account_id uuid references public.finance_accounts (id) on delete set null,
  to_account_id uuid references public.finance_accounts (id) on delete set null,
  budget_id uuid references public.finance_budgets (id) on delete set null,
  interval text not null default 'monthly'
    check (interval in ('weekly', 'monthly', 'quarterly', 'yearly')),
  next_due date not null default current_date,
  ends_on date,
  -- True: posts by itself. False: shows as due and waits. Subscriptions
  -- want true, variable bills want false.
  auto_post boolean not null default false,
  active boolean not null default true,
  created_by uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Same rule as finance_entries: only spending can consume a budget. The
-- client normalises this already, but a constraint that lives in only one
-- of the two tables is a rule you have to remember rather than one the
-- database keeps for you.
alter table public.finance_recurring
  drop constraint if exists finance_recurring_budget_only_on_expense;
alter table public.finance_recurring
  add constraint finance_recurring_budget_only_on_expense
  check (budget_id is null or kind = 'expense');

create index if not exists finance_recurring_pair_due_idx
  on public.finance_recurring (pair_id, active, next_due);

-- ════════════════════════════════════════════════════════════════════
-- 7. Holdings — what an investment account actually contains
-- ════════════════════════════════════════════════════════════════════
-- Quantity × price, so gold is grams and crypto is coins rather than a
-- number you remember to retype. `unit_cost` is what makes gain/loss
-- possible; without it an investment can say what it is worth today but
-- never whether that is good news.
create table if not exists public.finance_holdings (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  account_id uuid not null references public.finance_accounts (id)
    on delete cascade,
  symbol text not null check (length(trim(symbol)) > 0),
  label text,
  quantity numeric(24, 8) not null default 0,
  unit_cost numeric(20, 8) not null default 0,
  unit_price numeric(20, 8) not null default 0,
  currency text not null default 'PHP',
  price_source text not null default 'manual'
    check (price_source in ('manual', 'live')),
  price_as_of timestamptz not null default now(),
  created_by uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists finance_holdings_account_idx
  on public.finance_holdings (account_id);

-- ════════════════════════════════════════════════════════════════════
-- 8. Plans — "my salary splits like this"
-- ════════════════════════════════════════════════════════════════════
create table if not exists public.finance_plans (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  owner_id uuid references public.users (id) on delete cascade,
  name text not null default 'Monthly plan',
  income_amount numeric(14, 2) not null default 0 check (income_amount >= 0),
  currency text not null default 'PHP',
  period text not null default 'monthly'
    check (period in ('weekly', 'monthly', 'yearly')),
  active boolean not null default true,
  created_by uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Percent and fixed are mutually exclusive so a line can never be read two
-- ways; the UI offers one or the other per row, never both.
create table if not exists public.finance_plan_items (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.finance_plans (id) on delete cascade,
  label text not null check (length(trim(label)) > 0),
  percent numeric(6, 3) check (percent > 0 and percent <= 100),
  fixed_amount numeric(14, 2) check (fixed_amount > 0),
  budget_id uuid references public.finance_budgets (id) on delete set null,
  account_id uuid references public.finance_accounts (id) on delete set null,
  sort_order int not null default 0,
  constraint finance_plan_item_one_measure check (
    (percent is not null and fixed_amount is null)
    or (percent is null and fixed_amount is not null)
  )
);

create index if not exists finance_plan_items_plan_idx
  on public.finance_plan_items (plan_id, sort_order);

-- ════════════════════════════════════════════════════════════════════
-- 9. Row level security
-- ════════════════════════════════════════════════════════════════════

alter table public.finance_settings   enable row level security;
alter table public.finance_rates      enable row level security;
alter table public.finance_accounts   enable row level security;
alter table public.finance_budgets    enable row level security;
alter table public.finance_entries    enable row level security;
alter table public.finance_recurring  enable row level security;
alter table public.finance_holdings   enable row level security;
alter table public.finance_plans      enable row level security;
alter table public.finance_plan_items enable row level security;

-- Membership test, written once, so "you must be in the pair" has exactly
-- one definition.
create or replace function public.is_pair_member(p_pair_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.pairs p
    where p.id = p_pair_id
      and (p.user_a = auth.uid() or p.user_b = auth.uid())
  );
$$;

grant execute on function public.is_pair_member(uuid) to authenticated;

-- 0011's policies are replaced wholesale: the accounts rule changes shape
-- (visibility is now opt-in) and leaving the old one in place would OR the
-- two together, quietly restoring the behaviour being removed.
drop policy if exists "finance_accounts_select_pair" on public.finance_accounts;
drop policy if exists "finance_accounts_insert_own"  on public.finance_accounts;
drop policy if exists "finance_accounts_update_own"  on public.finance_accounts;
drop policy if exists "finance_accounts_delete_own"  on public.finance_accounts;
drop policy if exists "finance_entries_select_pair"  on public.finance_entries;
drop policy if exists "finance_entries_insert_own"   on public.finance_entries;
drop policy if exists "finance_entries_update_own"   on public.finance_entries;
drop policy if exists "finance_entries_delete_own"   on public.finance_entries;

drop policy if exists "finance_accounts_select" on public.finance_accounts;
create policy "finance_accounts_select" on public.finance_accounts
  for select using (
    public.is_pair_member(pair_id)
    and (owner_id is null or owner_id = auth.uid() or visible_to_partner = true)
  );

drop policy if exists "finance_accounts_insert" on public.finance_accounts;
create policy "finance_accounts_insert" on public.finance_accounts
  for insert with check (
    created_by = auth.uid()
    and (owner_id is null or owner_id = auth.uid())
    and public.is_pair_member(pair_id)
  );

drop policy if exists "finance_accounts_update" on public.finance_accounts;
create policy "finance_accounts_update" on public.finance_accounts
  for update using (
    (owner_id is null or owner_id = auth.uid())
    and public.is_pair_member(pair_id)
  );

drop policy if exists "finance_accounts_delete" on public.finance_accounts;
create policy "finance_accounts_delete" on public.finance_accounts
  for delete using (
    (owner_id is null or owner_id = auth.uid())
    and public.is_pair_member(pair_id)
  );

-- Entry visibility is inherited from the account, never stored twice: a
-- solo entry is readable by the partner only while the account it touches
-- is one the owner chose to show.
drop policy if exists "finance_entries_select" on public.finance_entries;
create policy "finance_entries_select" on public.finance_entries
  for select using (
    public.is_pair_member(pair_id)
    and (
      owner_id is null
      or owner_id = auth.uid()
      or exists (
        select 1 from public.finance_accounts a
        where a.id = finance_entries.account_id
          and a.visible_to_partner = true
      )
    )
  );

drop policy if exists "finance_entries_insert" on public.finance_entries;
create policy "finance_entries_insert" on public.finance_entries
  for insert with check (
    created_by = auth.uid()
    and (owner_id is null or owner_id = auth.uid())
    and public.is_pair_member(pair_id)
  );

drop policy if exists "finance_entries_update" on public.finance_entries;
create policy "finance_entries_update" on public.finance_entries
  for update using (
    (owner_id is null or owner_id = auth.uid())
    and public.is_pair_member(pair_id)
  );

drop policy if exists "finance_entries_delete" on public.finance_entries;
create policy "finance_entries_delete" on public.finance_entries
  for delete using (
    (owner_id is null or owner_id = auth.uid())
    and public.is_pair_member(pair_id)
  );

-- Settings: strictly yours.
drop policy if exists "finance_settings_own" on public.finance_settings;
create policy "finance_settings_own" on public.finance_settings
  for all using (user_id = auth.uid() and public.is_pair_member(pair_id))
  with check (user_id = auth.uid() and public.is_pair_member(pair_id));

-- Rates: shared across the pair, no per-row owner to respect.
drop policy if exists "finance_rates_pair" on public.finance_rates;
create policy "finance_rates_pair" on public.finance_rates
  for all using (public.is_pair_member(pair_id))
  with check (public.is_pair_member(pair_id));

-- Budgets, recurring and plans share the plain owner rule. Split per
-- command rather than `for all`: a single policy whose WITH CHECK demands
-- `created_by = auth.uid()` would also apply to UPDATE, which would stop
-- one partner editing a *shared* row the other created — exactly the rows
-- both are supposed to own. Omitting WITH CHECK on update makes Postgres
-- reuse USING, which still blocks reassigning a row to the partner.
do $do$
declare t text;
begin
  foreach t in array array['finance_budgets', 'finance_recurring', 'finance_plans']
  loop
    execute format('drop policy if exists %I on public.%I', t || '_select', t);
    execute format('create policy %I on public.%I for select using ('
      || 'public.is_pair_member(pair_id) and '
      || '(owner_id is null or owner_id = auth.uid()))', t || '_select', t);

    execute format('drop policy if exists %I on public.%I', t || '_insert', t);
    execute format('create policy %I on public.%I for insert with check ('
      || 'created_by = auth.uid() and '
      || '(owner_id is null or owner_id = auth.uid()) and '
      || 'public.is_pair_member(pair_id))', t || '_insert', t);

    execute format('drop policy if exists %I on public.%I', t || '_update', t);
    execute format('create policy %I on public.%I for update using ('
      || '(owner_id is null or owner_id = auth.uid()) and '
      || 'public.is_pair_member(pair_id))', t || '_update', t);

    execute format('drop policy if exists %I on public.%I', t || '_delete', t);
    execute format('create policy %I on public.%I for delete using ('
      || '(owner_id is null or owner_id = auth.uid()) and '
      || 'public.is_pair_member(pair_id))', t || '_delete', t);
  end loop;
end
$do$;

-- Plan items have no owner of their own — they inherit their plan's.
drop policy if exists "finance_plan_items_all" on public.finance_plan_items;
create policy "finance_plan_items_all" on public.finance_plan_items
  for all using (
    exists (
      select 1 from public.finance_plans p
      where p.id = plan_id and public.is_pair_member(p.pair_id)
        and (p.owner_id is null or p.owner_id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.finance_plans p
      where p.id = plan_id and public.is_pair_member(p.pair_id)
        and (p.owner_id is null or p.owner_id = auth.uid())
    )
  );

-- Holdings inherit the visibility of the account they sit in.
drop policy if exists "finance_holdings_select" on public.finance_holdings;
create policy "finance_holdings_select" on public.finance_holdings
  for select using (
    exists (
      select 1 from public.finance_accounts a
      where a.id = account_id and public.is_pair_member(a.pair_id)
        and (a.owner_id is null or a.owner_id = auth.uid()
             or a.visible_to_partner = true)
    )
  );

drop policy if exists "finance_holdings_insert" on public.finance_holdings;
create policy "finance_holdings_insert" on public.finance_holdings
  for insert with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.finance_accounts a
      where a.id = account_id and public.is_pair_member(a.pair_id)
        and (a.owner_id is null or a.owner_id = auth.uid())
    )
  );

drop policy if exists "finance_holdings_update" on public.finance_holdings;
create policy "finance_holdings_update" on public.finance_holdings
  for update using (
    exists (
      select 1 from public.finance_accounts a
      where a.id = account_id and public.is_pair_member(a.pair_id)
        and (a.owner_id is null or a.owner_id = auth.uid())
    )
  );

drop policy if exists "finance_holdings_delete" on public.finance_holdings;
create policy "finance_holdings_delete" on public.finance_holdings
  for delete using (
    exists (
      select 1 from public.finance_accounts a
      where a.id = account_id and public.is_pair_member(a.pair_id)
        and (a.owner_id is null or a.owner_id = auth.uid())
    )
  );

-- ════════════════════════════════════════════════════════════════════
-- 10. Grants — this project has NO default grants (see 0002).
--     RLS without a grant is a 42501, not a filtered result.
-- ════════════════════════════════════════════════════════════════════
grant select, insert, update, delete on public.finance_settings   to authenticated;
grant select, insert, update, delete on public.finance_rates      to authenticated;
grant select, insert, update, delete on public.finance_accounts   to authenticated;
grant select, insert, update, delete on public.finance_budgets    to authenticated;
grant select, insert, update, delete on public.finance_entries    to authenticated;
grant select, insert, update, delete on public.finance_recurring  to authenticated;
grant select, insert, update, delete on public.finance_holdings   to authenticated;
grant select, insert, update, delete on public.finance_plans      to authenticated;
grant select, insert, update, delete on public.finance_plan_items to authenticated;

-- ════════════════════════════════════════════════════════════════════
-- 11. Realtime — a shared ledger that only updates on relaunch isn't
--     shared. Guarded: adding a table already in the publication is an
--     error, and 0011 already added two of these.
-- ════════════════════════════════════════════════════════════════════
do $do$
declare t text;
begin
  foreach t in array array[
    'finance_accounts', 'finance_entries', 'finance_budgets',
    'finance_recurring', 'finance_holdings', 'finance_rates',
    'finance_plans', 'finance_plan_items', 'finance_settings'
  ]
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end
$do$;

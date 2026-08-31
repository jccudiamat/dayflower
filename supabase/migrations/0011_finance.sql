-- Dayflower — Finance tracker (Activities → Finance)
-- Run in the Supabase SQL editor.
--
-- Two tables, one idea: **accounts hold money, entries move it.**
--
--  * An account is a bank, a wallet, a savings pot or an investment. Its
--    balance is `opening_balance` plus every entry that touches it —
--    never stored, always derived, so a mistyped entry can be deleted and
--    the balance corrects itself.
--  * An entry is income (money in), an expense (money out) or a transfer
--    (money from one account to another). Investing and saving are
--    transfers into an account whose *kind* says what it is; that is why
--    there is no `investment` entry kind. One less way for the ledger to
--    disagree with itself.
--
-- `owner_id` is the shared/solo switch, on BOTH tables:
--    null      → the couple's, visible and editable by both
--    a user id → that partner's own
-- Solo rows are still readable by the partner. This is a couples app, not
-- a bank: hiding a number from the person you share rent with would be a
-- feature you asked for, not one you get by accident. Writes are the line
-- — only the owner can change their own rows.
--
-- Dev tables, so drop-and-recreate.

drop table if exists public.finance_entries cascade;
drop table if exists public.finance_accounts cascade;

create table public.finance_accounts (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  -- null = a shared account (joint savings, the household bank)
  owner_id uuid references public.users (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  kind text not null default 'bank'
    check (kind in ('bank', 'cash', 'ewallet', 'savings', 'investment')),
  opening_balance numeric(14, 2) not null default 0,
  currency text not null default 'PHP',
  emoji text not null default '🏦',
  created_by uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index finance_accounts_pair_idx
  on public.finance_accounts (pair_id, created_at);

create table public.finance_entries (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs (id) on delete cascade,
  owner_id uuid references public.users (id) on delete cascade,
  -- Where the money came from (income) or went from (expense/transfer).
  -- `set null` rather than cascade: deleting an account must not silently
  -- erase the month's spending history along with it.
  account_id uuid references public.finance_accounts (id) on delete set null,
  -- Only set for transfers: the account the money lands in.
  to_account_id uuid references public.finance_accounts (id) on delete set null,
  kind text not null check (kind in ('income', 'expense', 'transfer')),
  category text not null default 'Other',
  amount numeric(14, 2) not null check (amount > 0),
  note text,
  occurred_on date not null default current_date,
  created_by uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  -- A transfer needs somewhere to land, and cannot land where it started.
  constraint finance_transfer_has_destination check (
    (kind <> 'transfer' and to_account_id is null)
    or (kind = 'transfer' and to_account_id is not null
        and to_account_id is distinct from account_id)
  )
);

create index finance_entries_pair_date_idx
  on public.finance_entries (pair_id, occurred_on desc);

alter table public.finance_accounts enable row level security;
alter table public.finance_entries enable row level security;

-- ── Accounts ────────────────────────────────────────

create policy "finance_accounts_select_pair" on public.finance_accounts
  for select using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- Shared rows (owner_id null) are anyone-in-the-pair; solo rows are only
-- their owner's. The same predicate governs insert, update and delete, so
-- there is exactly one rule to reason about.
create policy "finance_accounts_insert_own" on public.finance_accounts
  for insert with check (
    created_by = auth.uid()
    and (owner_id is null or owner_id = auth.uid())
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "finance_accounts_update_own" on public.finance_accounts
  for update using (
    (owner_id is null or owner_id = auth.uid())
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "finance_accounts_delete_own" on public.finance_accounts
  for delete using (
    (owner_id is null or owner_id = auth.uid())
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

-- ── Entries ─────────────────────────────────────────

create policy "finance_entries_select_pair" on public.finance_entries
  for select using (
    exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "finance_entries_insert_own" on public.finance_entries
  for insert with check (
    created_by = auth.uid()
    and (owner_id is null or owner_id = auth.uid())
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "finance_entries_update_own" on public.finance_entries
  for update using (
    (owner_id is null or owner_id = auth.uid())
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

create policy "finance_entries_delete_own" on public.finance_entries
  for delete using (
    (owner_id is null or owner_id = auth.uid())
    and exists (
      select 1 from public.pairs p
      where p.id = pair_id
        and (p.user_a = auth.uid() or p.user_b = auth.uid())
    )
  );

grant select, insert, update, delete on public.finance_accounts to authenticated;
grant select, insert, update, delete on public.finance_entries to authenticated;

-- A shared ledger that only updates on relaunch isn't shared.
alter publication supabase_realtime add table public.finance_accounts;
alter publication supabase_realtime add table public.finance_entries;

import 'package:flutter/foundation.dart';

import 'finance_models.dart';

/// How one budget is doing this period.
@immutable
class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.spent,
    required this.limit,
  });

  final FinanceBudget budget;

  /// Spent this period, in the budget's own currency.
  final double spent;
  final double limit;

  double get remaining => limit - spent;
  bool get isOver => spent > limit;

  /// Null when the limit is zero — a bar that would divide by zero is a bar
  /// with nothing to say.
  double? get fraction => limit <= 0 ? null : (spent / limit).clamp(0.0, 1.0);
}

/// Everything the finance screens show as a number, derived in one place so
/// that the overview card, the account tiles and the budget bars can never
/// disagree with each other.
///
/// Two rules hold this together:
///  * **Balances are always derived, never stored** — opening balance plus
///    every entry that touches the account. Deleting a mistyped entry
///    corrects every number it touched, for free.
///  * **Liabilities are stored positive and subtracted here.** A card with
///    5,000 owed has a balance of 5000, and net worth is assets minus
///    liabilities. Storing it as -5000 would mean every form had to explain
///    why paying it off makes the number go up.
@immutable
class FinanceSummary {
  const FinanceSummary({
    required this.accounts,
    required this.balances,
    required this.mainCurrency,
    required this.assets,
    required this.liabilities,
    required this.monthIncome,
    required this.monthExpenses,
    required this.saved,
    required this.invested,
    required this.budgets,
    required this.unconvertible,
  });

  final List<FinanceAccount> accounts;

  /// Account id → balance **in that account's own currency**. Converting
  /// here would throw away the only number the account holder recognises.
  final Map<String, double> balances;

  final String mainCurrency;

  /// Both already converted to [mainCurrency], liabilities positive.
  final double assets;
  final double liabilities;

  final double monthIncome;
  final double monthExpenses;
  final double saved;
  final double invested;

  final List<BudgetProgress> budgets;

  /// Currencies held by some account but with no rate on file. The UI warns
  /// with these rather than pretending the total is complete — a net worth
  /// silently missing an account is worse than one that says what it's
  /// missing.
  final Set<String> unconvertible;

  double get netWorth => assets - liabilities;
  double get monthNet => monthIncome - monthExpenses;

  static const empty = FinanceSummary(
    accounts: [],
    balances: {},
    mainCurrency: 'PHP',
    assets: 0,
    liabilities: 0,
    monthIncome: 0,
    monthExpenses: 0,
    saved: 0,
    invested: 0,
    budgets: [],
    unconvertible: {},
  );

  /// Builds every number for one set of accounts and entries.
  ///
  /// [accounts] and [entries] are expected to be pre-filtered to the scope
  /// being shown — "Ours" passes only shared rows, and that is exactly what
  /// makes shared net worth mean what it says.
  ///
  /// Transfers are deliberately absent from income and expenses: moving
  /// your own money between your own accounts is not spending, and counting
  /// it would make a payday-to-savings sweep look like a month where you
  /// earned and spent the same amount twice.
  factory FinanceSummary.from({
    required List<FinanceAccount> accounts,
    required List<FinanceEntry> entries,
    required List<FinanceBudget> budgets,
    required DateTime month,
    required String mainCurrency,
    required FxTable fx,
  }) {
    final live = accounts.where((a) => !a.archived).toList(growable: false);
    final byId = {for (final a in live) a.id: a};

    final balances = <String, double>{
      for (final a in live) a.id: a.openingBalance,
    };

    var income = 0.0;
    var expenses = 0.0;
    final unconvertible = <String>{};
    final spentByBudget = <String, double>{};

    /// Entry amounts are converted into whichever currency the account they
    /// touch is kept in, so a USD charge on a PHP card moves the PHP
    /// balance by the right amount. Same-currency entries — nearly all of
    /// them — short-circuit without touching the rate table.
    double? inAccountCurrency(FinanceEntry entry, FinanceAccount account) {
      if (entry.currency == account.currency) return entry.amount;
      final converted =
          fx.convert(entry.amount, from: entry.currency, to: account.currency);
      if (converted == null) unconvertible.add(entry.currency);
      return converted;
    }

    for (final entry in entries) {
      final from = entry.accountId == null ? null : byId[entry.accountId];
      if (from != null) {
        final amount = inAccountCurrency(entry, from);
        if (amount != null) {
          // A liability's balance is what you owe, so an expense charged to
          // a card *increases* it while the same expense on a bank account
          // decreases it. Without this the card would pay itself off every
          // time it was used.
          final delta = from.isLiability
              ? (entry.kind == EntryKind.income ? -amount : amount)
              : (entry.kind == EntryKind.income ? amount : -amount);
          balances[from.id] = balances[from.id]! + delta;
        }
      }

      final to = entry.toAccountId == null ? null : byId[entry.toAccountId];
      if (to != null) {
        final amount = inAccountCurrency(entry, to);
        if (amount != null) {
          // Transferring into a liability is paying it down.
          balances[to.id] =
              balances[to.id]! + (to.isLiability ? -amount : amount);
        }
      }

      final inMonth = entry.occurredOn.year == month.year &&
          entry.occurredOn.month == month.month;
      if (!inMonth) continue;

      if (entry.kind == EntryKind.income || entry.kind == EntryKind.expense) {
        final converted = entry.currency == mainCurrency
            ? entry.amount
            : fx.convert(entry.amount, from: entry.currency, to: mainCurrency);
        if (converted == null) {
          unconvertible.add(entry.currency);
        } else if (entry.kind == EntryKind.income) {
          income += converted;
        } else {
          expenses += converted;
        }
      }

      if (entry.budgetId != null && entry.kind == EntryKind.expense) {
        spentByBudget[entry.budgetId!] =
            (spentByBudget[entry.budgetId!] ?? 0) + entry.amount;
      }
    }

    // ── Totals, converted to the currency the user reads in ──────────
    var assets = 0.0;
    var liabilities = 0.0;
    var saved = 0.0;
    var invested = 0.0;

    for (final account in live) {
      if (!account.includeInNetWorth) continue;
      final balance = balances[account.id] ?? 0;
      final converted = account.currency == mainCurrency
          ? balance
          : fx.convert(balance, from: account.currency, to: mainCurrency);
      if (converted == null) {
        unconvertible.add(account.currency);
        continue;
      }
      if (account.isLiability) {
        liabilities += converted;
      } else {
        assets += converted;
        if (account.kind == AccountKind.savings ||
            account.kind == AccountKind.fund) {
          saved += converted;
        }
        if (account.kind == AccountKind.investment) invested += converted;
      }
    }

    final progress = budgets
        .where((b) => !b.archived)
        .map((b) => BudgetProgress(
              budget: b,
              spent: spentByBudget[b.id] ?? 0,
              limit: b.limitAmount,
            ))
        .toList(growable: false);

    return FinanceSummary(
      accounts: live,
      balances: balances,
      mainCurrency: mainCurrency,
      assets: assets,
      liabilities: liabilities,
      monthIncome: income,
      monthExpenses: expenses,
      saved: saved,
      invested: invested,
      budgets: progress,
      unconvertible: unconvertible,
    );
  }
}

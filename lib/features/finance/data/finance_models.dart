import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Whose money a row is. Mirrors `owner_id` across the finance tables:
/// null = the couple's, a user id = that partner's own.
///
/// [partner] is a **read-only view**, and a partial one: 0016 makes solo
/// accounts private by default, so this scope shows only what the partner
/// ticked `visible_to_partner` on. The screen hides every write control
/// here rather than letting a save fail with a 42501 nobody can act on.
enum FinanceScope { shared, mine, partner }

/// Asset or liability. Stored explicitly rather than derived from
/// [AccountKind], because a card can be debit or credit and only the owner
/// knows which.
///
/// Liability balances are held **positive** — "owe 5,000" is 5000, not
/// -5000 — and subtracted when net worth is computed. Storing them negative
/// would mean every form had to explain why paying a debt makes the number
/// go up.
enum AccountClass {
  asset('Asset'),
  liability('Liability');

  const AccountClass(this.label);
  final String label;

  static AccountClass fromName(String? name) => AccountClass.values.firstWhere(
        (c) => c.name == name,
        orElse: () => AccountClass.asset,
      );
}

/// What an account *is*. The kind is what makes a savings pot count as
/// savings and a loan count against you.
enum AccountKind {
  cash('Cash', '💵', AppColors.sage, AccountClass.asset),
  bank('Bank', '🏦', AppColors.secondary, AccountClass.asset),
  ewallet('E-wallet', '📱', AppColors.brand, AccountClass.asset),
  card('Card', '💳', AppColors.danger, AccountClass.liability),
  savings('Savings', '🐷', AppColors.amber, AccountClass.asset),
  fund('Fund', '🎯', AppColors.lavender, AccountClass.asset),
  investment('Investment', '📈', AppColors.lavender, AccountClass.asset),
  loan('Loan', '🏚️', AppColors.danger, AccountClass.liability),
  receivable('Owed to me', '🤝', AppColors.sage, AccountClass.asset),
  other('Other', '📦', AppColors.muted, AccountClass.asset);

  const AccountKind(this.label, this.emoji, this.color, this.defaultClass);

  final String label;
  final String emoji;
  final Color color;

  /// What this kind usually is. A starting point for the form, never a
  /// constraint — the user can flip a card to an asset if theirs is debit.
  final AccountClass defaultClass;

  static AccountKind fromName(String? name) => AccountKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => AccountKind.bank,
      );

  /// Kinds that hold positions rather than a single balance.
  bool get holdsPositions => this == AccountKind.investment;

  /// Kinds that have something to reach.
  bool get hasTarget => this == AccountKind.fund || this == AccountKind.savings;

  /// The `subkind` options offered for this kind. Free text in the DB —
  /// this is the fast path, not a constraint.
  List<String> get subkinds {
    switch (this) {
      case AccountKind.investment:
        return const ['Crypto', 'Stocks', 'Gold', 'Bonds', 'REIT', 'Other'];
      case AccountKind.fund:
        return const ['Emergency', 'House', 'Travel', 'Car', 'Wedding', 'Other'];
      case AccountKind.loan:
        return const ['Mortgage', 'Auto', 'Personal', 'Student', 'Other'];
      default:
        return const [];
    }
  }
}

/// Income in, expense out, transfer between two of your own accounts.
///
/// Investing and saving are transfers into an account whose [AccountKind]
/// says what it is. Giving them their own entry kinds would let the ledger
/// and the balances disagree about the same peso.
enum EntryKind {
  income('Income', AppColors.success),
  expense('Expense', AppColors.danger),
  transfer('Transfer', AppColors.secondary);

  const EntryKind(this.label, this.color);
  final String label;
  final Color color;

  static EntryKind fromName(String? name) => EntryKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => EntryKind.expense,
      );

  List<String> get categories {
    switch (this) {
      case EntryKind.income:
        return const [
          'Salary', 'Freelance', 'Bonus', 'Gift', 'Refund', 'Interest', 'Other',
        ];
      case EntryKind.expense:
        return const [
          'Food', 'Groceries', 'Rent', 'Bills', 'Transport', 'Shopping',
          'Health', 'Subscriptions', 'Gifts', 'Travel', 'Fun', 'Debt', 'Other',
        ];
      case EntryKind.transfer:
        return const ['Savings', 'Investment', 'Fund', 'Top-up', 'Other'];
    }
  }
}

/// How often a budget or recurring rule comes round.
enum FinancePeriod {
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  const FinancePeriod(this.label);
  final String label;

  static FinancePeriod fromName(String? name) =>
      FinancePeriod.values.firstWhere(
        (p) => p.name == name,
        orElse: () => FinancePeriod.monthly,
      );
}

/// `overall` is the month's total allowance; `category` caps one slice of
/// it. At most one active overall budget per owner — enforced by a partial
/// unique index in 0016, not just by the UI.
enum BudgetScope {
  overall('Overall'),
  category('Category');

  const BudgetScope(this.label);
  final String label;

  static BudgetScope fromName(String? name) => BudgetScope.values.firstWhere(
        (s) => s.name == name,
        orElse: () => BudgetScope.category,
      );
}

/// Display symbols for the currencies the pickers offer. A currency with no
/// entry here falls back to its code, which is correct for anything exotic —
/// "CHF 40" reads fine, and inventing a symbol would not.
const kCurrencySymbols = <String, String>{
  'PHP': '₱',
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'AED': 'AED ',
  'SAR': 'SAR ',
  'QAR': 'QAR ',
  'SGD': 'S\$',
  'AUD': 'A\$',
  'CAD': 'C\$',
  'NZD': 'NZ\$',
  'HKD': 'HK\$',
  'JPY': '¥',
  'CNY': '¥',
  'KRW': '₩',
  'INR': '₹',
  'THB': '฿',
  'MYR': 'RM',
  'IDR': 'Rp',
  'VND': '₫',
  'CHF': 'CHF ',
};

/// The symbol for [currency], or the code itself with a trailing space.
String currencySymbol(String currency) =>
    kCurrencySymbols[currency] ?? '$currency ';

double toDouble(Object? value) => switch (value) {
      null => 0,
      num n => n.toDouble(),
      // numeric comes back from PostgREST as a String often enough that
      // parsing defensively is cheaper than chasing the one that didn't.
      String s => double.tryParse(s) ?? 0,
      _ => 0,
    };

double? toDoubleOrNull(Object? value) => value == null ? null : toDouble(value);

/* ── Accounts ───────────────────────────────────────────────── */

@immutable
class FinanceAccount {
  const FinanceAccount({
    required this.id,
    required this.pairId,
    this.ownerId,
    required this.name,
    required this.accountClass,
    required this.kind,
    this.subkind,
    required this.openingBalance,
    required this.currency,
    required this.emoji,
    this.targetAmount,
    this.targetDate,
    this.creditLimit,
    this.interestRate,
    required this.visibleToPartner,
    required this.includeInNetWorth,
    required this.archived,
    required this.createdBy,
  });

  final String id;
  final String pairId;

  /// Null for a shared account — the only rows that count toward shared
  /// net worth.
  final String? ownerId;

  final String name;
  final AccountClass accountClass;
  final AccountKind kind;
  final String? subkind;
  final double openingBalance;
  final String currency;
  final String emoji;
  final double? targetAmount;
  final DateTime? targetDate;
  final double? creditLimit;
  final double? interestRate;

  /// Whether the partner may see this account at all. Ignored for shared
  /// accounts, which a DB trigger forces to true.
  final bool visibleToPartner;

  final bool includeInNetWorth;
  final bool archived;
  final String createdBy;

  bool get isShared => ownerId == null;
  bool get isLiability => accountClass == AccountClass.liability;

  factory FinanceAccount.fromMap(Map<String, dynamic> map) => FinanceAccount(
        id: map['id'] as String,
        pairId: map['pair_id'] as String,
        ownerId: map['owner_id'] as String?,
        name: map['name'] as String,
        accountClass: AccountClass.fromName(map['class'] as String?),
        kind: AccountKind.fromName(map['kind'] as String?),
        subkind: map['subkind'] as String?,
        openingBalance: toDouble(map['opening_balance']),
        currency: map['currency'] as String? ?? 'PHP',
        emoji: map['emoji'] as String? ?? '🏦',
        targetAmount: toDoubleOrNull(map['target_amount']),
        targetDate: map['target_date'] == null
            ? null
            : DateTime.parse(map['target_date'] as String),
        creditLimit: toDoubleOrNull(map['credit_limit']),
        interestRate: toDoubleOrNull(map['interest_rate']),
        visibleToPartner: map['visible_to_partner'] as bool? ?? false,
        includeInNetWorth: map['include_in_net_worth'] as bool? ?? true,
        archived: map['archived'] as bool? ?? false,
        createdBy: map['created_by'] as String,
      );
}

/* ── Budgets ────────────────────────────────────────────────── */

@immutable
class FinanceBudget {
  const FinanceBudget({
    required this.id,
    required this.pairId,
    this.ownerId,
    required this.scope,
    required this.name,
    this.category,
    required this.emoji,
    required this.limitAmount,
    required this.currency,
    required this.period,
    this.fundingAccountId,
    required this.rollover,
    required this.startsOn,
    required this.archived,
    required this.createdBy,
  });

  final String id;
  final String pairId;
  final String? ownerId;
  final BudgetScope scope;
  final String name;
  final String? category;
  final String emoji;
  final double limitAmount;
  final String currency;
  final FinancePeriod period;

  /// The account this budget is understood to spend out of — what "budgets
  /// are deducted from cash" means. A label on the money, not a second
  /// ledger: spending is still entries, so a budget can never disagree
  /// with the balance it draws from.
  final String? fundingAccountId;

  final bool rollover;
  final DateTime startsOn;
  final bool archived;
  final String createdBy;

  bool get isShared => ownerId == null;
  bool get isOverall => scope == BudgetScope.overall;

  factory FinanceBudget.fromMap(Map<String, dynamic> map) => FinanceBudget(
        id: map['id'] as String,
        pairId: map['pair_id'] as String,
        ownerId: map['owner_id'] as String?,
        scope: BudgetScope.fromName(map['scope'] as String?),
        name: map['name'] as String,
        category: map['category'] as String?,
        emoji: map['emoji'] as String? ?? '🎯',
        limitAmount: toDouble(map['limit_amount']),
        currency: map['currency'] as String? ?? 'PHP',
        period: FinancePeriod.fromName(map['period'] as String?),
        fundingAccountId: map['funding_account_id'] as String?,
        rollover: map['rollover'] as bool? ?? false,
        startsOn: DateTime.parse(map['starts_on'] as String),
        archived: map['archived'] as bool? ?? false,
        createdBy: map['created_by'] as String,
      );
}

/* ── Entries ────────────────────────────────────────────────── */

@immutable
class FinanceEntry {
  const FinanceEntry({
    required this.id,
    required this.pairId,
    this.ownerId,
    this.accountId,
    this.toAccountId,
    this.budgetId,
    required this.kind,
    required this.category,
    required this.amount,
    required this.currency,
    this.fxRate,
    this.note,
    required this.occurredOn,
    required this.createdBy,
  });

  final String id;
  final String pairId;
  final String? ownerId;

  /// Where the money came from / went from. Null once the account it
  /// referenced was deleted — the entry survives, the link doesn't.
  final String? accountId;

  /// Only set on transfers: where it landed.
  final String? toAccountId;

  /// Which budget this spending counts against. Null is normal.
  final String? budgetId;

  final EntryKind kind;
  final String category;
  final double amount;

  /// The entry's own currency, which need not match the account's.
  final String currency;

  /// Rate to the owner's main currency **at the time of the entry**.
  /// Snapshotted so that editing today's rate cannot silently rewrite what
  /// last year's charts say you spent. Null means "convert at today's
  /// rate", which is the honest answer for rows written before a rate
  /// existed.
  final double? fxRate;

  final String? note;
  final DateTime occurredOn;
  final String createdBy;

  bool get isShared => ownerId == null;

  /// What this entry does to [accountId]'s balance, in the entry's own
  /// currency. Income adds; an expense and the outgoing leg of a transfer
  /// both subtract.
  double get signedAmount => kind == EntryKind.income ? amount : -amount;

  factory FinanceEntry.fromMap(Map<String, dynamic> map) => FinanceEntry(
        id: map['id'] as String,
        pairId: map['pair_id'] as String,
        ownerId: map['owner_id'] as String?,
        accountId: map['account_id'] as String?,
        toAccountId: map['to_account_id'] as String?,
        budgetId: map['budget_id'] as String?,
        kind: EntryKind.fromName(map['kind'] as String?),
        category: map['category'] as String? ?? 'Other',
        amount: toDouble(map['amount']),
        currency: map['currency'] as String? ?? 'PHP',
        fxRate: toDoubleOrNull(map['fx_rate']),
        note: map['note'] as String?,
        occurredOn: DateTime.parse(map['occurred_on'] as String),
        createdBy: map['created_by'] as String,
      );
}

/* ── Exchange rates ─────────────────────────────────────────── */

@immutable
class FxRate {
  const FxRate({
    required this.currency,
    required this.usdRate,
    required this.source,
    required this.pinned,
    required this.asOf,
  });

  final String currency;

  /// Units of [currency] per 1 USD. USD itself is 1.
  final double usdRate;

  /// 'manual' or 'live'.
  final String source;

  /// A pinned rate is the user's own number and the live refresh leaves it
  /// alone.
  final bool pinned;

  final DateTime asOf;

  factory FxRate.fromMap(Map<String, dynamic> map) => FxRate(
        currency: map['currency'] as String,
        usdRate: toDouble(map['usd_rate']),
        source: map['source'] as String? ?? 'manual',
        pinned: map['pinned'] as bool? ?? false,
        asOf: DateTime.parse(map['as_of'] as String).toLocal(),
      );
}

/// Converts between currencies through USD as the anchor.
///
/// Deliberately fails *visibly* rather than silently: an unknown currency
/// returns null so the UI can say "no rate for SGD" instead of quietly
/// treating 1 SGD as 1 PHP and producing a net worth that is wrong by a
/// factor of forty.
@immutable
class FxTable {
  const FxTable(this.rates);

  final Map<String, FxRate> rates;

  static const FxTable empty = FxTable({});

  /// The oldest rate any conversion here leans on — what the UI shows as
  /// "rates as of …". A total is only as fresh as its stalest input.
  DateTime? get oldestAsOf {
    if (rates.isEmpty) return null;
    return rates.values.map((r) => r.asOf).reduce((a, b) => a.isBefore(b) ? a : b);
  }

  double? rateFor(String currency) {
    if (currency == 'USD') return 1;
    return rates[currency]?.usdRate;
  }

  /// [amount] in [from], expressed in [to]. Null when either side has no
  /// rate on file.
  double? convert(double amount, {required String from, required String to}) {
    if (from == to) return amount;
    final fromRate = rateFor(from);
    final toRate = rateFor(to);
    if (fromRate == null || toRate == null || fromRate == 0) return null;
    return amount / fromRate * toRate;
  }

  bool has(String currency) => rateFor(currency) != null;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/features/finance/data/finance_models.dart';
import 'package:dayflower/features/finance/data/finance_summary.dart';

/// The finance numbers are derived in one place so the overview card, the
/// account tiles and the budget bars can never disagree. That only holds if
/// the derivation is right, and several of its rules are the kind that look
/// fine until real money is in them — a liability that pays itself off, a
/// portfolio stuck at its funding amount, a total silently missing an
/// account. Each of those is a test here.

const _pair = 'pair-1';
const _me = 'user-1';

FinanceAccount _account({
  required String id,
  required AccountKind kind,
  AccountClass? cls,
  double opening = 0,
  String currency = 'AED',
  bool includeInNetWorth = true,
}) =>
    FinanceAccount(
      id: id,
      pairId: _pair,
      ownerId: _me,
      name: id,
      accountClass: cls ?? kind.defaultClass,
      kind: kind,
      openingBalance: opening,
      currency: currency,
      emoji: '💰',
      visibleToPartner: false,
      includeInNetWorth: includeInNetWorth,
      archived: false,
      createdBy: _me,
    );

FinanceEntry _entry({
  required String id,
  required EntryKind kind,
  required double amount,
  String? accountId,
  String? toAccountId,
  String? budgetId,
  String currency = 'AED',
  DateTime? on,
}) =>
    FinanceEntry(
      id: id,
      pairId: _pair,
      ownerId: _me,
      accountId: accountId,
      toAccountId: toAccountId,
      budgetId: budgetId,
      kind: kind,
      category: 'Other',
      amount: amount,
      currency: currency,
      occurredOn: on ?? DateTime(2026, 9, 1),
      createdBy: _me,
    );

FinanceSummary _build({
  List<FinanceAccount> accounts = const [],
  List<FinanceEntry> entries = const [],
  List<FinanceBudget> budgets = const [],
  List<Holding> holdings = const [],
  String main = 'AED',
  FxTable fx = FxTable.empty,
}) =>
    FinanceSummary.from(
      accounts: accounts,
      entries: entries,
      budgets: budgets,
      holdings: holdings,
      month: DateTime(2026, 9),
      mainCurrency: main,
      fx: fx,
    );

void main() {
  group('balances', () {
    test('an expense on an asset account reduces it', () {
      final s = _build(
        accounts: [_account(id: 'bank', kind: AccountKind.bank, opening: 1000)],
        entries: [
          _entry(id: 'e', kind: EntryKind.expense, amount: 250, accountId: 'bank')
        ],
      );
      expect(s.balances['bank'], 750);
    });

    test('an expense on a CARD increases what is owed', () {
      // The one that bites: without the liability branch a credit card pays
      // itself off every time you use it.
      final s = _build(
        accounts: [_account(id: 'card', kind: AccountKind.card, opening: 500)],
        entries: [
          _entry(id: 'e', kind: EntryKind.expense, amount: 200, accountId: 'card')
        ],
      );
      expect(s.balances['card'], 700);
      expect(s.liabilities, 700);
      expect(s.assets, 0);
      expect(s.netWorth, -700);
    });

    test('transferring into a liability pays it down', () {
      final s = _build(
        accounts: [
          _account(id: 'bank', kind: AccountKind.bank, opening: 1000),
          _account(id: 'card', kind: AccountKind.card, opening: 500),
        ],
        entries: [
          _entry(
            id: 't',
            kind: EntryKind.transfer,
            amount: 300,
            accountId: 'bank',
            toAccountId: 'card',
          )
        ],
      );
      expect(s.balances['bank'], 700);
      expect(s.balances['card'], 200);
      expect(s.netWorth, 500);
    });

    test('transfers are not income or spending', () {
      final s = _build(
        accounts: [
          _account(id: 'bank', kind: AccountKind.bank, opening: 1000),
          _account(id: 'save', kind: AccountKind.savings),
        ],
        entries: [
          _entry(
            id: 't',
            kind: EntryKind.transfer,
            amount: 400,
            accountId: 'bank',
            toAccountId: 'save',
          )
        ],
      );
      expect(s.monthIncome, 0);
      expect(s.monthExpenses, 0);
      expect(s.netWorth, 1000, reason: 'moving money changes nothing overall');
    });
  });

  group('investments', () {
    test('an account with positions is worth the positions, not the cash', () {
      final s = _build(
        accounts: [
          _account(id: 'crypto', kind: AccountKind.investment, opening: 1000)
        ],
        holdings: [
          Holding(
            id: 'h',
            pairId: _pair,
            accountId: 'crypto',
            symbol: 'BTC',
            quantity: 0.5,
            unitCost: 1000,
            unitPrice: 1400,
            currency: 'AED',
            priceAsOf: DateTime(2026, 9),
            createdBy: _me,
          )
        ],
      );
      // 0.5 x 1400 = 700 — not the 1000 paid in, and not 1700 either.
      expect(s.invested, 700);
      expect(s.assets, 700);
      expect(s.marketValues['crypto'], 700);
    });

    test('gain is market minus book, and null percent without a cost', () {
      final held = Holding(
        id: 'h',
        pairId: _pair,
        accountId: 'a',
        symbol: 'XAU',
        quantity: 2,
        unitCost: 100,
        unitPrice: 150,
        currency: 'AED',
        priceAsOf: DateTime(2026, 9),
        createdBy: _me,
      );
      expect(held.marketValue, 300);
      expect(held.bookValue, 200);
      expect(held.gain, 100);
      expect(held.gainPercent, closeTo(0.5, 1e-9));
    });

    test('no cost basis reports no percentage rather than -100%', () {
      final gifted = Holding(
        id: 'h',
        pairId: _pair,
        accountId: 'a',
        symbol: 'XAU',
        quantity: 1,
        unitCost: 0,
        unitPrice: 150,
        currency: 'AED',
        priceAsOf: DateTime(2026, 9),
        createdBy: _me,
      );
      expect(gifted.gainPercent, isNull);
    });
  });

  group('currency', () {
    final fx = FxTable({
      'AED': FxRate(
          currency: 'AED',
          usdRate: 3.6725,
          source: 'live',
          pinned: false,
          asOf: DateTime(2026, 9)),
      'PHP': FxRate(
          currency: 'PHP',
          usdRate: 58.20,
          source: 'live',
          pinned: false,
          asOf: DateTime(2026, 9)),
    });

    test('converts an account into the main currency', () {
      final s = _build(
        accounts: [
          _account(id: 'a', kind: AccountKind.bank, opening: 22000)
        ],
        main: 'PHP',
        fx: fx,
      );
      expect(s.assets, closeTo(22000 / 3.6725 * 58.20, 0.01));
    });

    test('an unconvertible account is excluded AND named', () {
      // The failure mode this guards: a net worth that quietly drops an
      // account reads exactly like a correct one.
      final s = _build(
        accounts: [
          _account(id: 'a', kind: AccountKind.bank, opening: 100, currency: 'AED'),
          _account(id: 'b', kind: AccountKind.bank, opening: 999, currency: 'JPY'),
        ],
        main: 'AED',
        fx: fx,
      );
      expect(s.assets, 100);
      expect(s.unconvertible, contains('JPY'));
    });
  });

  group('budgets and flags', () {
    test('spending charged to a budget fills it', () {
      final budget = FinanceBudget(
        id: 'b1',
        pairId: _pair,
        ownerId: _me,
        scope: BudgetScope.category,
        name: 'Food',
        category: 'Food',
        emoji: '🍜',
        limitAmount: 1000,
        currency: 'AED',
        period: FinancePeriod.monthly,
        rollover: false,
        startsOn: DateTime(2026, 9),
        archived: false,
        createdBy: _me,
      );
      final s = _build(
        accounts: [_account(id: 'bank', kind: AccountKind.bank, opening: 5000)],
        budgets: [budget],
        entries: [
          _entry(
              id: 'e',
              kind: EntryKind.expense,
              amount: 250,
              accountId: 'bank',
              budgetId: 'b1')
        ],
      );
      final progress = s.budgets.single;
      expect(progress.spent, 250);
      expect(progress.remaining, 750);
      expect(progress.isOver, isFalse);
      expect(progress.fraction, closeTo(0.25, 1e-9));
    });

    test('an account excluded from net worth still keeps its balance', () {
      final s = _build(
        accounts: [
          _account(
              id: 'x',
              kind: AccountKind.bank,
              opening: 4242,
              includeInNetWorth: false)
        ],
      );
      expect(s.balances['x'], 4242);
      expect(s.assets, 0);
    });
  });
}

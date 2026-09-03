import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/features/finance/data/finance_models.dart';
import 'package:dayflower/features/finance/data/finance_summary.dart';

/// A goal draws a ring and a fraction, and both are easy to get quietly
/// wrong: a linked account that goes overdrawn, a goal that overshoots, a
/// target of zero. None of those throw — they just render a percentage that
/// is a lie.

FinanceGoal _goal({
  double target = 100000,
  double saved = 0,
  String? accountId,
  DateTime? targetDate,
  String currency = 'AED',
}) =>
    FinanceGoal(
      id: 'g1',
      pairId: 'pair-1',
      name: 'Tesla Model S',
      emoji: '🚗',
      targetAmount: target,
      savedAmount: saved,
      currency: currency,
      accountId: accountId,
      targetDate: targetDate,
      archived: false,
      createdBy: 'user-1',
    );

void main() {
  group('an unlinked goal uses its own number', () {
    test('progress is the saved amount', () {
      final goal = _goal(target: 120000, saved: 45940);
      expect(goal.savedGiven(const {}), 45940);
      expect(goal.fractionGiven(const {}), closeTo(0.3828, 0.0001));
      expect(goal.remainingGiven(const {}), 74060);
      expect(goal.isReachedGiven(const {}), isFalse);
    });

    test('balances are ignored entirely', () {
      // The account map is passed to every goal, linked or not. An unlinked
      // goal must not accidentally pick a balance out of it.
      final goal = _goal(saved: 500);
      expect(goal.savedGiven(const {'acc': 99999}), 500);
    });
  });

  group('a linked goal tracks its account', () {
    test('progress is the balance, not the stored number', () {
      // The stored 500 is stale on purpose: linking is what makes the goal
      // self-maintaining, and the whole point is that the balance wins.
      final goal = _goal(target: 1000, saved: 500, accountId: 'save');
      expect(goal.savedGiven(const {'save': 800}), 800);
      expect(goal.fractionGiven(const {'save': 800}), closeTo(0.8, 1e-9));
    });

    test('the stored number survives for when it is unlinked again', () {
      final goal = _goal(target: 1000, saved: 500, accountId: 'save');
      expect(goal.savedAmount, 500,
          reason: 'linking must not discard what was typed');
    });

    test('an account that has gone overdrawn is zero, not negative', () {
      // ⚠️ A negative would draw a ring backwards and a negative
      // percentage. Being overdrawn has not un-saved money towards a car.
      final goal = _goal(target: 1000, accountId: 'save');
      expect(goal.savedGiven(const {'save': -250}), 0);
      expect(goal.fractionGiven(const {'save': -250}), 0);
    });

    test('a deleted account reads as nothing saved', () {
      // 0022 nulls `account_id` on delete rather than cascading, so the
      // goal outlives the pot. Until it is relinked there is no balance.
      final goal = _goal(target: 1000, accountId: 'gone');
      expect(goal.savedGiven(const {}), 0);
    });
  });

  group('the edges of the ring', () {
    test('overshooting is finished, not owed', () {
      final goal = _goal(target: 1000, saved: 1500);
      expect(goal.fractionGiven(const {}), 1.0, reason: 'clamped');
      expect(goal.remainingGiven(const {}), 0,
          reason: 'never negative — an overshot goal is done');
      expect(goal.isReachedGiven(const {}), isTrue);
    });

    test('a zero target has no fraction rather than infinity', () {
      // The DB forbids it, but a row written before that check, or by hand,
      // must not divide by zero on the way to the screen.
      final goal = _goal(target: 0, saved: 10);
      expect(goal.fractionGiven(const {}), isNull);
    });

    test('exactly on target counts as reached', () {
      expect(_goal(target: 1000, saved: 1000).isReachedGiven(const {}), isTrue);
    });
  });

  group('deadlines', () {
    test('no date means no countdown', () {
      expect(_goal().daysLeft, isNull);
    });

    test('a past date goes negative so the card can say so', () {
      final goal = _goal(
        targetDate: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(goal.daysLeft, lessThan(0));
    });
  });

  group('rows off the wire', () {
    test('numerics arriving as strings still parse', () {
      // PostgREST can render a large `numeric` as a string; the cast that
      // assumes otherwise throws once and takes the screen with it.
      final goal = FinanceGoal.fromMap({
        'id': 'g1',
        'pair_id': 'p1',
        'owner_id': null,
        'name': 'House',
        'emoji': '🏠',
        'target_amount': '2500000.00',
        'saved_amount': '125000.50',
        'currency': 'PHP',
        'account_id': null,
        'target_date': null,
        'archived': false,
        'created_by': 'u1',
      });
      expect(goal.targetAmount, 2500000);
      expect(goal.savedAmount, closeTo(125000.50, 1e-9));
      expect(goal.isLinked, isFalse);
    });
  });

  group('currency stays where it was put', () {
    // The rule the whole schema turns on: an amount is only ever converted
    // when it is being totalled with other amounts. On its own, it stays in
    // the money it was recorded in.
    test('a goal keeps its own currency, whatever the main one is', () {
      final goal = _goal(currency: 'AED', target: 50000);
      expect(goal.currency, 'AED');
    });

    test('an account balance is never converted', () {
      final summary = FinanceSummary.from(
        accounts: [
          FinanceAccount(
            id: 'usd',
            pairId: 'p',
            ownerId: 'u',
            name: 'Dollar card',
            accountClass: AccountKind.bank.defaultClass,
            kind: AccountKind.bank,
            openingBalance: 1000,
            currency: 'USD',
            emoji: '💵',
            visibleToPartner: false,
            includeInNetWorth: true,
            archived: false,
            createdBy: 'u',
          ),
        ],
        entries: const [],
        budgets: const [],
        month: DateTime(2026, 9),
        mainCurrency: 'PHP',
        fx: FxTable({
          'USD': FxRate(
              currency: 'USD',
              usdRate: 1,
              source: 'live',
              pinned: false,
              asOf: DateTime(2026, 9)),
          'PHP': FxRate(
              currency: 'PHP',
              usdRate: 58,
              source: 'live',
              pinned: false,
              asOf: DateTime(2026, 9)),
        }),
      );

      // The card shows 1,000 dollars, not 58,000 pesos.
      expect(summary.balances['usd'], 1000);
      // The total, which mixes currencies, is the one that converts.
      expect(summary.assets, closeTo(58000, 0.01));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/features/finance/data/finance_models.dart';
import 'package:dayflower/features/finance/domain/finance_insights.dart';

/// A chart that is wrong looks exactly like a chart that is right, and the
/// image this page exports goes to somebody who cannot check it. So the
/// arithmetic behind the wedges, the bars and the sentences is pinned here.

const _pair = 'pair-1';
const _me = 'user-1';

FinanceEntry _entry({
  required EntryKind kind,
  required double amount,
  String category = 'Food',
  String currency = 'AED',
  required DateTime on,
}) =>
    FinanceEntry(
      id: '${on.microsecondsSinceEpoch}-$category-$amount',
      pairId: _pair,
      ownerId: _me,
      kind: kind,
      category: category,
      amount: amount,
      currency: currency,
      occurredOn: on,
      createdBy: _me,
    );

final _fx = FxTable({
  'AED': FxRate(
      currency: 'AED',
      usdRate: 3.6725,
      source: 'live',
      pinned: false,
      asOf: DateTime(2026, 9)),
  'USD': FxRate(
      currency: 'USD',
      usdRate: 1,
      source: 'live',
      pinned: false,
      asOf: DateTime(2026, 9)),
});

FinanceInsights _build(List<FinanceEntry> entries, {FxTable? fx}) =>
    FinanceInsights.from(
      entries: entries,
      month: DateTime(2026, 9),
      currency: 'AED',
      fx: fx ?? _fx,
      netWorth: 0,
      saved: 0,
      invested: 0,
    );

void main() {
  group('the month', () {
    test('adds income and expenses, and leaves transfers out', () {
      // A payday-to-savings sweep is not income and not spending. Counting
      // it would show a month where you earned and spent the same amount
      // twice, and put "Transfer" on the donut as a category.
      final insights = _build([
        _entry(kind: EntryKind.income, amount: 5000, on: DateTime(2026, 9, 1)),
        _entry(kind: EntryKind.expense, amount: 800, on: DateTime(2026, 9, 3)),
        _entry(
            kind: EntryKind.transfer, amount: 2000, on: DateTime(2026, 9, 4)),
      ]);
      expect(insights.income, 5000);
      expect(insights.expenses, 800);
      expect(insights.net, 4200);
      expect(insights.categories.map((c) => c.category), ['Food']);
    });

    test('categories come back biggest first, with their share', () {
      final insights = _build([
        _entry(
            kind: EntryKind.expense,
            amount: 100,
            category: 'Transport',
            on: DateTime(2026, 9, 2)),
        _entry(
            kind: EntryKind.expense,
            amount: 300,
            category: 'Food',
            on: DateTime(2026, 9, 3)),
      ]);
      expect(insights.categories.first.category, 'Food');
      expect(insights.categories.first.share, closeTo(0.75, 1e-9));
      expect(insights.topCategory!.amount, 300);
    });

    test('a foreign amount is converted before it is added in', () {
      // This is a total, which is the one place conversion belongs.
      final insights = _build([
        _entry(
            kind: EntryKind.expense,
            amount: 100,
            currency: 'USD',
            on: DateTime(2026, 9, 2)),
      ]);
      expect(insights.expenses, closeTo(367.25, 0.01));
      expect(insights.unconvertible, isEmpty);
    });

    test('an unconvertible amount is left out AND named', () {
      // ⚠️ The failure this guards: a chart quietly missing a currency
      // looks exactly like a correct one.
      final insights = _build([
        _entry(
            kind: EntryKind.expense,
            amount: 500,
            currency: 'AED',
            on: DateTime(2026, 9, 2)),
        _entry(
            kind: EntryKind.expense,
            amount: 900,
            currency: 'JPY',
            on: DateTime(2026, 9, 3)),
      ]);
      expect(insights.expenses, 500);
      expect(insights.unconvertible, contains('JPY'));
    });
  });

  group('the trailing months', () {
    test('there are six of them, ending with the month being viewed', () {
      final insights = _build(const []);
      expect(insights.months.length, FinanceInsights.monthsBack);
      expect(insights.months.last.month, DateTime(2026, 9));
      expect(insights.months.first.month, DateTime(2026, 4));
    });

    test('a month with no entries is marked as such', () {
      // A month of zero and a month with no data draw the same bar and mean
      // different things. Only this tells them apart.
      final insights = _build([
        _entry(kind: EntryKind.expense, amount: 10, on: DateTime(2026, 9, 1)),
      ]);
      expect(insights.months.last.hasEntries, isTrue);
      expect(insights.months.first.hasEntries, isFalse);
    });

    test('last month comes from the series, not a second pass', () {
      final insights = _build([
        _entry(kind: EntryKind.expense, amount: 200, on: DateTime(2026, 8, 5)),
        _entry(kind: EntryKind.expense, amount: 100, on: DateTime(2026, 9, 5)),
      ]);
      expect(insights.previousExpenses, 200);
      expect(insights.spendDelta, closeTo(-0.5, 1e-9));
    });

    test('no previous month means no delta at all', () {
      // Not "down 100%". An absence is not a fall.
      final insights = _build([
        _entry(kind: EntryKind.expense, amount: 100, on: DateTime(2026, 9, 5)),
      ]);
      expect(insights.previousExpenses, isNull);
      expect(insights.spendDelta, isNull);
    });
  });

  group('the rates and the sentences', () {
    test('savings rate is null when nothing came in', () {
      // "0% saved" would imply you earned something and kept none of it.
      final insights = _build([
        _entry(kind: EntryKind.expense, amount: 100, on: DateTime(2026, 9, 5)),
      ]);
      expect(insights.savingsRate, isNull);
    });

    test('spending more than came in is a negative rate, not a crash', () {
      final insights = _build([
        _entry(kind: EntryKind.income, amount: 100, on: DateTime(2026, 9, 1)),
        _entry(kind: EntryKind.expense, amount: 150, on: DateTime(2026, 9, 5)),
      ]);
      expect(insights.savingsRate, closeTo(-0.5, 1e-9));
      expect(insights.headlines.any((l) => l.contains('more than came in')),
          isTrue);
    });

    test('the sentences describe rather than advise', () {
      final insights = _build([
        _entry(kind: EntryKind.expense, amount: 200, on: DateTime(2026, 8, 5)),
        _entry(kind: EntryKind.income, amount: 1000, on: DateTime(2026, 9, 1)),
        _entry(kind: EntryKind.expense, amount: 100, on: DateTime(2026, 9, 5)),
      ]);
      final lines = insights.headlines;
      expect(lines.any((l) => l.contains('50% less than last month')), isTrue);
      expect(lines.any((l) => l.contains('Food was your biggest category')),
          isTrue);
      expect(lines.any((l) => l.contains('kept 90%')), isTrue);
      // Nothing that tells them what to do with their money.
      for (final line in lines) {
        expect(line.toLowerCase(), isNot(contains('should')));
        expect(line.toLowerCase(), isNot(contains('try to')));
      }
    });

    test('a thin month says so instead of implying a trend', () {
      final insights = _build([
        _entry(kind: EntryKind.expense, amount: 100, on: DateTime(2026, 9, 5)),
      ]);
      expect(insights.headlines.any((l) => l.contains('not much here to read')),
          isTrue);
    });

    test('an empty month is empty, and has nothing to say', () {
      final insights = _build(const []);
      expect(insights.isEmpty, isTrue);
      expect(insights.headlines, isEmpty);
      expect(insights.averageMonthlySpend, 0);
    });
  });
}

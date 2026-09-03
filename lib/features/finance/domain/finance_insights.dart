import 'package:flutter/foundation.dart';

import '../data/finance_models.dart';

/// Everything the Insights page draws and says, derived in one pass.
///
/// Pure, and separate from the widgets on purpose: a chart that is wrong is
/// indistinguishable from a chart that is right, so the arithmetic behind
/// one wants to be testable without a screen. The same reasoning that put
/// `FinanceSummary` in its own file.
///
/// ⚠️ **Everything here is converted into [currency], and that is correct
/// precisely because everything here is a total.** A category is many
/// entries added together; a month is many categories. The rule the rest of
/// the app follows — an amount on its own stays in the money it was
/// recorded in — has nothing to bite on at this level, because nothing on
/// this page is a single amount.
@immutable
class FinanceInsights {
  const FinanceInsights({
    required this.month,
    required this.currency,
    required this.income,
    required this.expenses,
    required this.categories,
    required this.months,
    required this.previousExpenses,
    required this.netWorth,
    required this.saved,
    required this.invested,
    required this.entryCount,
    required this.unconvertible,
  });

  final DateTime month;
  final String currency;

  final double income;
  final double expenses;

  /// Spending by category this month, biggest first. Empty categories are
  /// left out rather than drawn as slivers nobody can see or read.
  final List<CategorySlice> categories;

  /// The trailing months ending with [month], oldest first.
  final List<MonthTotals> months;

  /// Null when there is nothing on file for the month before — which is
  /// different from a month of zero, and the difference is the whole reason
  /// this is nullable: "down 100%" from an absence is not a fact.
  final double? previousExpenses;

  final double netWorth;
  final double saved;
  final double invested;

  /// How many entries this month. A chart drawn from three of them is a
  /// chart about three things, and the page says so rather than implying a
  /// trend.
  final int entryCount;

  /// Currencies with no rate on file. Their amounts are **left out** of
  /// every figure here rather than counted at 1:1 — and the page says so,
  /// because a total silently missing an account looks exactly like a
  /// correct one.
  final Set<String> unconvertible;

  double get net => income - expenses;

  /// Share of income kept. Null when nothing came in — a rate of "0%" would
  /// imply you earned something and saved none of it.
  double? get savingsRate {
    if (income <= 0) return null;
    return (net / income).clamp(-1.0, 1.0);
  }

  double? get spendDelta {
    final previous = previousExpenses;
    if (previous == null || previous <= 0) return null;
    return (expenses - previous) / previous;
  }

  CategorySlice? get topCategory =>
      categories.isEmpty ? null : categories.first;

  /// The average of the months on file that actually have spending, so one
  /// empty month at the start of a couple's history doesn't halve it.
  double get averageMonthlySpend {
    final spent = months.where((m) => m.expenses > 0).toList();
    if (spent.isEmpty) return 0;
    return spent.fold<double>(0, (sum, m) => sum + m.expenses) / spent.length;
  }

  bool get isEmpty => income == 0 && expenses == 0 && categories.isEmpty;

  static FinanceInsights empty(String currency, DateTime month) =>
      FinanceInsights(
        month: month,
        currency: currency,
        income: 0,
        expenses: 0,
        categories: const [],
        months: const [],
        previousExpenses: null,
        netWorth: 0,
        saved: 0,
        invested: 0,
        entryCount: 0,
        unconvertible: const {},
      );

  /// How many months of history the charts look back over.
  static const monthsBack = 6;

  factory FinanceInsights.from({
    required List<FinanceEntry> entries,
    required DateTime month,
    required String currency,
    required FxTable fx,
    required double netWorth,
    required double saved,
    required double invested,
  }) {
    final unconvertible = <String>{};

    /// Converts, or records why it couldn't and returns null. Skipping is
    /// the only honest option: counting a 100 USD charge as 100 PHP would
    /// put a wrong number on a chart with nothing to mark it as wrong.
    double? convert(double amount, String from) {
      final converted = fx.convert(amount, from: from, to: currency);
      if (converted == null) unconvertible.add(from);
      return converted;
    }

    bool inMonth(FinanceEntry e, DateTime m) =>
        e.occurredOn.year == m.year && e.occurredOn.month == m.month;

    // ── This month ────────────────────────────────────────
    var income = 0.0;
    var expenses = 0.0;
    var entryCount = 0;
    final byCategory = <String, double>{};

    for (final entry in entries) {
      if (!inMonth(entry, month)) continue;
      // Transfers are absent throughout, same as everywhere else: moving
      // your own money between your own accounts is not spending, and a
      // payday-to-savings sweep would otherwise show up as a category.
      if (entry.kind == EntryKind.transfer) continue;
      entryCount++;
      final amount = convert(entry.amount, entry.currency);
      if (amount == null) continue;
      if (entry.kind == EntryKind.income) {
        income += amount;
      } else {
        expenses += amount;
        byCategory[entry.category] = (byCategory[entry.category] ?? 0) + amount;
      }
    }

    final slices = byCategory.entries
        .where((e) => e.value > 0)
        .map((e) => CategorySlice(
              category: e.key,
              amount: e.value,
              share: expenses <= 0 ? 0 : e.value / expenses,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // ── The trailing months ───────────────────────────────
    final months = <MonthTotals>[];
    for (var back = monthsBack - 1; back >= 0; back--) {
      final m = DateTime(month.year, month.month - back);
      var monthIn = 0.0;
      var monthOut = 0.0;
      var any = false;
      for (final entry in entries) {
        if (!inMonth(entry, m)) continue;
        if (entry.kind == EntryKind.transfer) continue;
        any = true;
        final amount = convert(entry.amount, entry.currency);
        if (amount == null) continue;
        if (entry.kind == EntryKind.income) {
          monthIn += amount;
        } else {
          monthOut += amount;
        }
      }
      months.add(MonthTotals(
        month: m,
        income: monthIn,
        expenses: monthOut,
        hasEntries: any,
      ));
    }

    // The month before this one, from the series that was just built —
    // rather than a second pass that could drift from it.
    final previous = months.length >= 2 ? months[months.length - 2] : null;

    return FinanceInsights(
      month: month,
      currency: currency,
      income: income,
      expenses: expenses,
      categories: slices,
      months: months,
      previousExpenses: (previous != null && previous.hasEntries)
          ? previous.expenses
          : null,
      netWorth: netWorth,
      saved: saved,
      invested: invested,
      entryCount: entryCount,
      unconvertible: unconvertible,
    );
  }

  /// The sentences under the charts.
  ///
  /// Written as observations rather than advice. This app has no business
  /// telling a couple what to do with their money, and "you spent 40% of
  /// your income on food" is a fact they can act on however they like.
  List<String> get headlines {
    final lines = <String>[];

    final delta = spendDelta;
    if (delta != null) {
      final percent = (delta.abs() * 100).round();
      if (percent == 0) {
        lines.add('You spent almost exactly what you did last month.');
      } else {
        lines.add(delta < 0
            ? 'You spent $percent% less than last month.'
            : 'You spent $percent% more than last month.');
      }
    }

    final top = topCategory;
    if (top != null && top.share > 0) {
      lines.add('${top.category} was your biggest category, at '
          '${(top.share * 100).round()}% of everything that went out.');
    }

    final rate = savingsRate;
    if (rate != null) {
      lines.add(rate >= 0
          ? 'You kept ${(rate * 100).round()}% of what came in.'
          : 'You spent ${(rate.abs() * 100).round()}% more than came in.');
    }

    final average = averageMonthlySpend;
    if (average > 0 && expenses > 0) {
      final difference = (expenses - average).abs() / average;
      // Only worth saying when it is actually unusual. "1% above average"
      // is noise dressed up as an insight.
      if (difference >= 0.15) {
        lines.add(expenses > average
            ? 'That is above your usual month.'
            : 'That is a quieter month than usual for you.');
      }
    }

    if (entryCount > 0 && entryCount < 5) {
      // Said plainly rather than hidden: four entries do not make a trend,
      // and a chart drawn from them looks exactly like one that does.
      lines.add('Only $entryCount ${entryCount == 1 ? 'entry' : 'entries'} '
          'this month, so there is not much here to read yet.');
    }

    return lines;
  }
}

/// One wedge of the spending donut.
@immutable
class CategorySlice {
  const CategorySlice({
    required this.category,
    required this.amount,
    required this.share,
  });

  final String category;
  final double amount;

  /// 0…1 of the month's spending.
  final double share;
}

/// One column of the in-and-out chart.
@immutable
class MonthTotals {
  const MonthTotals({
    required this.month,
    required this.income,
    required this.expenses,
    required this.hasEntries,
  });

  final DateTime month;
  final double income;
  final double expenses;

  /// Whether anything at all was recorded. A month of zero and a month with
  /// no data are drawn the same way but mean different things, and only
  /// this tells them apart.
  final bool hasEntries;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../finance/data/finance_repository.dart';

/// The one savings goal the Together tab shows, and how far along it is.
class TogetherSavings {
  const TogetherSavings({
    required this.goal,
    required this.saved,
    required this.fraction,
    this.balances = const {},
  });

  final FinanceGoal goal;

  /// In [FinanceGoal.currency], never converted: the couple set the target
  /// in that currency and recognise the number in it.
  final double saved;

  /// 0 to 1.
  final double fraction;

  /// The account balances progress was read from, so "to go" is worked
  /// out from the same numbers as "saved".
  final Map<String, double> balances;
}

/// Which goal "Our Savings" is about: a shared one, never a private one —
/// the card says *our* — and of those, the one with the nearest deadline,
/// or the first made when none has a deadline.
///
/// 🔴 **Progress is worked out exactly as the Finances screen does it.** A
/// goal linked to an account is as full as that account's balance, and the
/// balance is derived from every entry that touched it. Reading
/// `savedAmount` for a linked goal would show whatever was typed before it
/// was linked — a different number from Finances for the same goal.
final togetherSavingsProvider =
    Provider.autoDispose<AsyncValue<TogetherSavings?>>((ref) {
  return ref.watch(financeGoalsProvider).whenData((goals) {
    final shared =
        goals.where((g) => !g.archived && g.ownerId == null).toList();
    if (shared.isEmpty) return null;

    // Picked by hand rather than sorted: List.sort is not stable, and two
    // undated goals would otherwise swap places between rebuilds.
    var goal = shared.first;
    for (final candidate in shared) {
      final date = candidate.targetDate;
      if (date == null) continue;
      final best = goal.targetDate;
      if (best == null || date.isBefore(best)) goal = candidate;
    }

    var balances = const <String, double>{};
    if (goal.isLinked) {
      balances = FinanceSummary.from(
        accounts: ref.watch(financeAccountsProvider).valueOrNull ?? const [],
        entries: ref.watch(financeEntriesProvider).valueOrNull ?? const [],
        budgets: const [],
        month: DateTime.now(),
        mainCurrency: goal.currency,
        fx: ref.watch(financeRatesProvider).valueOrNull ?? FxTable.empty,
      ).balances;
    }
    return TogetherSavings(
      goal: goal,
      saved: goal.savedGiven(balances),
      fraction: goal.fractionGiven(balances) ?? 0,
      balances: balances,
    );
  });
});

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_error_notice.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/ios_back_button.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/finance_repository.dart';
import '../widgets/currency_sheet.dart';

/// The couple's money, in three views: **Ours**, **Mine**, and theirs.
///
/// Everything on screen is derived from two lists (accounts and entries)
/// filtered by scope — there is no stored balance anywhere, so a deleted
/// entry corrects every number it touched.
///
/// The partner's scope is deliberately read-only: RLS lets you *see* their
/// solo rows but only they can write them, so the controls disappear
/// rather than offering a save that would come back 42501.
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  FinanceScope _scope = FinanceScope.shared;
  late DateTime _month = _thisMonth();

  static DateTime _thisMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  /// The `owner_id` that [scope] writes and reads. Null means shared.
  String? _ownerFor(FinanceScope scope, String myId, String? partnerId) =>
      switch (scope) {
        FinanceScope.shared => null,
        FinanceScope.mine => myId,
        FinanceScope.partner => partnerId,
      };

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final pair = ref.watch(currentPairProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    // Totals are shown in the reader's own main currency; per-account
    // amounts stay in the currency that account is actually kept in.
    final currency = ref.watch(financeMainCurrencyProvider).valueOrNull ?? 'PHP';
    final fx = ref.watch(financeRatesProvider).valueOrNull ?? FxTable.empty;
    final accountsAsync = ref.watch(financeAccountsProvider);
    final entriesAsync = ref.watch(financeEntriesProvider);
    final budgetsAsync = ref.watch(financeBudgetsProvider);

    final partnerId =
        userId == null ? null : pair?.partnerIdFor(userId);
    final partnerName = partner?.displayName ?? 'Them';
    final readOnly = _scope == FinanceScope.partner;

    final owner = userId == null
        ? null
        : _ownerFor(_scope, userId, partnerId);
    // `shared` legitimately has a null owner, so a null here can't stand in
    // for "no scope" — the shared case is checked first.
    final scopeMatches = _scope == FinanceScope.shared
        ? (String? o) => o == null
        : (String? o) => o != null && o == owner;

    final accounts = (accountsAsync.valueOrNull ?? const [])
        .where((a) => scopeMatches(a.ownerId))
        .toList();
    final entries = (entriesAsync.valueOrNull ?? const [])
        .where((e) => scopeMatches(e.ownerId))
        .toList();
    final budgets = (budgetsAsync.valueOrNull ?? const [])
        .where((b) => scopeMatches(b.ownerId))
        .toList();

    final summary = FinanceSummary.from(
      accounts: accounts,
      entries: entries,
      budgets: budgets,
      month: _month,
      mainCurrency: currency,
      fx: fx,
    );
    final monthEntries = entries
        .where((e) =>
            e.occurredOn.year == _month.year &&
            e.occurredOn.month == _month.month)
        .toList();

    final loading = accountsAsync.isLoading ||
        entriesAsync.isLoading ||
        budgetsAsync.isLoading;
    // Both streams feed `valueOrNull ?? const []`, so a failure would
    // otherwise render as "you have no accounts" — which looks exactly
    // like the honest empty state and means the opposite.
    final loadError = accountsAsync.error ?? entriesAsync.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IosBackButton(onTap: () => context.go(Routes.activities)),
                  const SizedBox(width: AppSpace.xs),
                  const Expanded(
                    child: FeatureScreenHeader(
                      title: 'Finances',
                      subtitle: 'What comes in, what goes out, what grows',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: AppSegmented<FinanceScope>(
                options: {
                  FinanceScope.shared: 'Ours',
                  FinanceScope.mine: 'Mine',
                  FinanceScope.partner: partnerName,
                },
                value: _scope,
                onChanged: (v) => setState(() => _scope = v),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Expanded(
              child: loading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpace.sm, 0,
                          AppSpace.sm, AppSpace.xl + AppSpace.md),
                      children: [
                        if (loadError != null)
                          AppErrorNotice(
                            message: 'Your finances could not load',
                            detail: loadError,
                          ),
                        _MonthBar(
                          month: _month,
                          onShift: (by) => setState(() =>
                              _month = DateTime(_month.year, _month.month + by)),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        _NetWorthCard(
                          summary: summary,
                          currency: currency,
                          onTapCurrency: () => showCurrencySheet(context),
                          scopeLabel: switch (_scope) {
                            FinanceScope.shared => 'Ours together',
                            FinanceScope.mine => 'Mine alone',
                            FinanceScope.partner => "$partnerName's",
                          },
                        ),
                        const SizedBox(height: AppSpace.sm),
                        _MonthTiles(summary: summary, currency: currency),
                        const SizedBox(height: AppSpace.md),
                        _SectionHeader(
                          label: 'Accounts',
                          action: readOnly ? null : 'Add',
                          onAction: () => _openAccountSheet(
                            ownerId: owner,
                            currency: currency,
                          ),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        if (accounts.isEmpty)
                          _EmptyHint(
                            emoji: '🏦',
                            title: 'No accounts here yet',
                            body: readOnly
                                ? "They haven't added any of their own."
                                : 'Add a bank, a wallet, a savings pot or an '
                                    'investment to start tracking balances.',
                          )
                        else
                          ...accounts.map((account) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: AppSpace.xs),
                                child: _AccountCard(
                                  account: account,
                                  balance: summary.balances[account.id] ?? 0,
                                  currency: currency,
                                  onTap: readOnly
                                      ? null
                                      : () => _openAccountSheet(
                                            ownerId: owner,
                                            currency: currency,
                                            existing: account,
                                          ),
                                ),
                              )),
                        // ── Budgets ────────────────────────────
                        const SizedBox(height: AppSpace.md),
                        _SectionHeader(
                          label: 'Budgets',
                          action: readOnly ? null : 'Add',
                          onAction: () => _openBudgetSheet(
                            ownerId: owner,
                            accounts: accounts,
                            budgets: budgets,
                            currency: currency,
                          ),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        if (summary.budgets.isEmpty)
                          _EmptyHint(
                            emoji: '🎯',
                            title: 'No budgets set',
                            body: readOnly
                                ? "They haven't set any."
                                : 'Set a monthly allowance, then cap the '
                                    'categories that need it. Spending you '
                                    'log against one fills its bar.',
                          )
                        else
                          // Overall first — it is the allowance the
                          // category budgets are drawn from, so reading it
                          // second would be reading the parts before the
                          // whole.
                          ...[
                            ...summary.budgets.where((b) => b.budget.isOverall),
                            ...summary.budgets.where((b) => !b.budget.isOverall),
                          ].map((progress) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: AppSpace.xs),
                                child: _BudgetCard(
                                  progress: progress,
                                  onTap: readOnly
                                      ? null
                                      : () => _openBudgetSheet(
                                            ownerId: owner,
                                            accounts: accounts,
                                            budgets: budgets,
                                            currency: currency,
                                            existing: progress.budget,
                                          ),
                                ),
                              )),

                        const SizedBox(height: AppSpace.md),
                        _SectionHeader(
                          label: DateFormat('MMMM').format(_month).toUpperCase(),
                          action: readOnly ? null : 'Add',
                          onAction: () => _openEntrySheet(
                            ownerId: owner,
                            accounts: accounts,
                            budgets: budgets,
                          ),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        if (monthEntries.isEmpty)
                          _EmptyHint(
                            emoji: '🧾',
                            title: 'Nothing logged this month',
                            body: readOnly
                                ? 'Their month is still empty.'
                                : 'Log what you earned, spent, saved or '
                                    'invested and the balances follow.',
                          )
                        else
                          ..._buildEntryList(
                            monthEntries,
                            accounts,
                            currency,
                            readOnly ? null : (e) => _openEntrySheet(
                                  ownerId: owner,
                                  accounts: accounts,
                                  budgets: budgets,
                                  existing: e,
                                ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton(
              onPressed: () =>
                  _openEntrySheet(
                      ownerId: owner, accounts: accounts, budgets: budgets),
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              child: const Icon(CupertinoIcons.add),
            ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  /// Entries with a date header wherever the day changes. The list is
  /// already newest-first from the repository, so this only has to notice
  /// the boundaries.
  List<Widget> _buildEntryList(
    List<FinanceEntry> entries,
    List<FinanceAccount> accounts,
    String currency,
    void Function(FinanceEntry)? onTap,
  ) {
    final byId = {for (final a in accounts) a.id: a};
    final widgets = <Widget>[];
    DateTime? lastDay;
    for (final entry in entries) {
      final day = entry.occurredOn;
      if (lastDay == null ||
          day.day != lastDay.day ||
          day.month != lastDay.month) {
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, AppSpace.xs, 4, AppSpace.xxs),
          child: Text(DateFormat('EEEE d').format(day), style: AppText.label()),
        ));
        lastDay = day;
      }
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.xxs),
        child: _EntryRow(
          entry: entry,
          fromAccount: byId[entry.accountId],
          toAccount: byId[entry.toAccountId],
          currency: currency,
          onTap: onTap == null ? null : () => onTap(entry),
        ),
      ));
    }
    return widgets;
  }

  // ── Sheets ──────────────────────────────────────

  Future<void> _openAccountSheet({
    required String? ownerId,
    required String currency,
    FinanceAccount? existing,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    final pair = ref.read(currentPairProvider).valueOrNull;
    if (userId == null || pair == null) return;

    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountSheet(
        existing: existing,
        currency: currency,
        isShared: (existing?.ownerId ?? ownerId) == null,
      ),
    );
    if (result == null || !mounted) return;

    final repo = ref.read(financeRepositoryProvider);
    try {
      switch (result) {
        case _Deleted():
          final ok = await showConfirmDialog(
            context,
            title: 'Delete ${existing!.name}?',
            message: 'Its balance goes with it. Entries you logged against '
                'it stay in the list.',
            confirmLabel: 'Delete',
          );
          if (ok) await repo.deleteAccount(existing.id);
        case _AccountSaved(:final draft):
          await repo.saveAccount(
            id: existing?.id,
            pairId: pair.id,
            ownerId: existing?.ownerId ?? ownerId,
            name: draft.name,
            accountClass: draft.accountClass,
            kind: draft.kind,
            subkind: draft.subkind,
            openingBalance: draft.openingBalance,
            currency: draft.currency,
            emoji: draft.emoji,
            targetAmount: draft.targetAmount,
            creditLimit: draft.creditLimit,
            visibleToPartner: draft.visibleToPartner,
            userId: userId,
          );
        case _EntrySaved():
        case _BudgetSaved():
          break; // not reachable from this sheet
      }
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  Future<void> _openBudgetSheet({
    required String? ownerId,
    required List<FinanceAccount> accounts,
    required List<FinanceBudget> budgets,
    required String currency,
    FinanceBudget? existing,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    final pair = ref.read(currentPairProvider).valueOrNull;
    if (userId == null || pair == null) return;

    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BudgetSheet(
        existing: existing,
        accounts: accounts,
        currency: currency,
        // Only one overall budget is allowed per owner per period — a
        // partial unique index in 0016 enforces it, so the sheet hides the
        // option rather than letting the save come back a 23505.
        overallTaken: budgets.any((b) =>
            !b.archived &&
            b.scope == BudgetScope.overall &&
            b.id != existing?.id),
      ),
    );
    if (result == null || !mounted) return;

    final repo = ref.read(financeRepositoryProvider);
    try {
      switch (result) {
        case _Deleted():
          final ok = await showConfirmDialog(
            context,
            title: 'Delete ${existing!.name}?',
            message: 'Spending logged against it stays — the entries lose '
                'the label, not the money.',
            confirmLabel: 'Delete',
          );
          if (ok) await repo.deleteBudget(existing.id);
        case _BudgetSaved(:final draft):
          await repo.saveBudget(
            id: existing?.id,
            pairId: pair.id,
            ownerId: existing?.ownerId ?? ownerId,
            scope: draft.scope,
            name: draft.name,
            category: draft.category,
            emoji: draft.emoji,
            limitAmount: draft.limitAmount,
            currency: draft.currency,
            period: draft.period,
            fundingAccountId: draft.fundingAccountId,
            rollover: draft.rollover,
            startsOn: existing?.startsOn,
            userId: userId,
          );
        case _AccountSaved():
        case _EntrySaved():
          break; // not reachable from this sheet
      }
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  Future<void> _openEntrySheet({
    required String? ownerId,
    required List<FinanceAccount> accounts,
    required List<FinanceBudget> budgets,
    FinanceEntry? existing,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    final pair = ref.read(currentPairProvider).valueOrNull;
    if (userId == null || pair == null) return;

    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EntrySheet(
        existing: existing,
        accounts: accounts,
        budgets: budgets,
        currency: ref.read(financeMainCurrencyProvider).valueOrNull ?? 'PHP',
      ),
    );
    if (result == null || !mounted) return;

    final repo = ref.read(financeRepositoryProvider);
    try {
      switch (result) {
        case _Deleted():
          final ok = await showConfirmDialog(
            context,
            title: 'Delete this entry?',
            message: 'Every balance it touched corrects itself.',
            confirmLabel: 'Delete',
          );
          if (ok) await repo.deleteEntry(existing!.id);
        case _EntrySaved(:final draft):
          await repo.saveEntry(
            id: existing?.id,
            pairId: pair.id,
            ownerId: existing?.ownerId ?? ownerId,
            accountId: draft.accountId,
            toAccountId: draft.toAccountId,
            budgetId: draft.budgetId,
            kind: draft.kind,
            category: draft.category,
            amount: draft.amount,
            currency: draft.currency,
            note: draft.note,
            occurredOn: draft.occurredOn,
            userId: userId,
          );
        case _AccountSaved():
        case _BudgetSaved():
          break; // not reachable from this sheet
      }
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not save that: $error')),
  );
}

// ── Money formatting ────────────────────────────────

/// Symbols for the currencies the account sheet offers. Anything else
/// falls back to its code, which is ugly but never wrong.
// Lives in finance_models.dart so the currency sheet can share one list;
// this alias keeps the call sites in this file unchanged.
const _symbols = kCurrencySymbols;

String _money(double value, String currency, {bool signed = false}) {
  final symbol = _symbols[currency] ?? '$currency ';
  final formatted = NumberFormat.currency(
    symbol: symbol,
    decimalDigits: value.truncateToDouble() == value ? 0 : 2,
  ).format(value.abs());
  if (!signed) return value < 0 ? '-$formatted' : formatted;
  return value < 0 ? '-$formatted' : '+$formatted';
}

// ── Header pieces ───────────────────────────────────

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, required this.onShift});
  final DateTime month;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Arrow(icon: CupertinoIcons.chevron_back, onTap: () => onShift(-1)),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(month),
            textAlign: TextAlign.center,
            style: AppText.subtitle(),
          ),
        ),
        _Arrow(icon: CupertinoIcons.chevron_forward, onTap: () => onShift(1)),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: AppColors.body),
      splashRadius: 20,
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({
    required this.summary,
    required this.currency,
    required this.scopeLabel,
    required this.onTapCurrency,
  });

  final FinanceSummary summary;
  final String currency;
  final String scopeLabel;

  /// Opens the currency & rates sheet. The pill lives on this card because
  /// this is the number the choice changes.
  final VoidCallback onTapCurrency;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(scopeLabel.toUpperCase(),
                    style: AppText.label(AppColors.onDarkMuted)),
              ),
              // Tappable rather than a settings row buried elsewhere: the
              // currency is a property of the number it sits above.
              GestureDetector(
                onTap: onTapCurrency,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.xs, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(currency, style: AppText.label(AppColors.onDark)),
                      const SizedBox(width: 3),
                      const Icon(CupertinoIcons.chevron_down,
                          size: 10, color: AppColors.onDarkMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(_money(summary.netWorth, currency),
              style: AppText.stat(AppColors.onDark)),
          const SizedBox(height: 2),
          Text(
            summary.liabilities > 0
                ? '${_money(summary.assets, currency)} in assets · '
                    '${_money(summary.liabilities, currency)} owed'
                : 'across every account',
            style: AppText.caption(AppColors.onDarkMuted),
          ),
          // A total that silently dropped an account is worse than one that
          // admits what it could not convert.
          if (summary.unconvertible.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'No rate for ${summary.unconvertible.join(', ')} — left out',
              style: AppText.caption(AppColors.brandLight),
            ),
          ],
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: _DarkStat(
                  label: 'Saved',
                  value: _money(summary.saved, currency),
                  emoji: '🐷',
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: Colors.white.withValues(alpha: .12),
              ),
              Expanded(
                child: _DarkStat(
                  label: 'Invested',
                  value: _money(summary.invested, currency),
                  emoji: '📈',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkStat extends StatelessWidget {
  const _DarkStat({
    required this.label,
    required this.value,
    required this.emoji,
  });
  final String label, value, emoji;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(label.toUpperCase(),
                  style: AppText.label(AppColors.onDarkMuted)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.subtitle(AppColors.onDark)),
        ],
      ),
    );
  }
}

class _MonthTiles extends StatelessWidget {
  const _MonthTiles({required this.summary, required this.currency});
  final FinanceSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Tile(
            label: 'In',
            value: _money(summary.monthIncome, currency),
            color: AppColors.success,
            icon: CupertinoIcons.arrow_down_left,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: _Tile(
            label: 'Out',
            value: _money(summary.monthExpenses, currency),
            color: AppColors.danger,
            icon: CupertinoIcons.arrow_up_right,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: _Tile(
            label: 'Left',
            value: _money(summary.monthNet, currency),
            color: summary.monthNet < 0 ? AppColors.danger : AppColors.secondary,
            icon: CupertinoIcons.equal,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label, value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs, vertical: AppSpace.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
              Text(label.toUpperCase(), style: AppText.label(color)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: AppText.subtitle().copyWith(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    this.action,
    required this.onAction,
  });
  final String label;
  final String? action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label.toUpperCase(), style: AppText.label())),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              children: [
                const Icon(CupertinoIcons.add, size: 13, color: AppColors.brand),
                const SizedBox(width: 3),
                Text(action!, style: AppText.label(AppColors.brand)),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.emoji,
    required this.title,
    required this.body,
  });
  final String emoji, title, body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: AppSpace.xs),
          Text(title, style: AppText.subtitle(), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(body, style: AppText.caption(), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Rows ────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.balance,
    required this.currency,
    required this.onTap,
  });

  final FinanceAccount account;
  final double balance;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppElevation.card,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: account.kind.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child:
                    Text(account.emoji, style: const TextStyle(fontSize: 19)),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(AppColors.ink)
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 1),
                    Text(account.kind.label,
                        style: AppText.label(account.kind.color)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Text(
                _money(balance, currency),
                style: AppText.subtitle(
                  balance < 0 ? AppColors.danger : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.fromAccount,
    required this.toAccount,
    required this.currency,
    required this.onTap,
  });

  final FinanceEntry entry;
  final FinanceAccount? fromAccount;
  final FinanceAccount? toAccount;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isTransfer = entry.kind == EntryKind.transfer;
    final subtitle = switch (entry.kind) {
      EntryKind.transfer =>
        '${fromAccount?.name ?? 'Somewhere'} → ${toAccount?.name ?? 'somewhere'}',
      _ => fromAccount?.name ?? 'No account',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: entry.kind.color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  switch (entry.kind) {
                    EntryKind.income => CupertinoIcons.arrow_down_left,
                    EntryKind.expense => CupertinoIcons.arrow_up_right,
                    EntryKind.transfer => CupertinoIcons.arrow_right_arrow_left,
                  },
                  size: 13,
                  color: entry.kind.color,
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.note?.trim().isNotEmpty == true
                          ? entry.note!.trim()
                          : entry.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(AppColors.ink),
                    ),
                    const SizedBox(height: 1),
                    Text('${entry.category} · $subtitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption()),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Text(
                isTransfer
                    ? _money(entry.amount, currency)
                    : _money(entry.signedAmount, currency, signed: true),
                style: AppText.body(
                  isTransfer ? AppColors.body : entry.kind.color,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sheet results ───────────────────────────────────

sealed class _SheetResult {
  const _SheetResult();
}

class _Deleted extends _SheetResult {
  const _Deleted();
}

class _AccountSaved extends _SheetResult {
  const _AccountSaved(this.draft);
  final _AccountDraft draft;
}

class _EntrySaved extends _SheetResult {
  const _EntrySaved(this.draft);
  final _EntryDraft draft;
}

class _BudgetSaved extends _SheetResult {
  const _BudgetSaved(this.draft);
  final _BudgetDraft draft;
}

class _BudgetDraft {
  const _BudgetDraft({
    required this.scope,
    required this.name,
    required this.category,
    required this.emoji,
    required this.limitAmount,
    required this.currency,
    required this.period,
    required this.fundingAccountId,
    required this.rollover,
  });
  final BudgetScope scope;
  final String name;

  /// Null for the overall budget, which caps everything rather than one
  /// slice of it.
  final String? category;

  final String emoji;
  final double limitAmount;
  final String currency;
  final FinancePeriod period;

  /// Which account this budget is understood to spend out of.
  final String? fundingAccountId;

  final bool rollover;
}

class _AccountDraft {
  const _AccountDraft({
    required this.name,
    required this.accountClass,
    required this.kind,
    required this.subkind,
    required this.openingBalance,
    required this.currency,
    required this.emoji,
    required this.targetAmount,
    required this.creditLimit,
    required this.visibleToPartner,
  });
  final String name;
  final AccountClass accountClass;
  final AccountKind kind;
  final String? subkind;
  final double openingBalance;
  final String currency;
  final String emoji;
  final double? targetAmount;
  final double? creditLimit;

  /// Ignored for shared accounts, which are visible to both by definition.
  final bool visibleToPartner;
}

class _EntryDraft {
  const _EntryDraft({
    required this.kind,
    required this.category,
    required this.amount,
    required this.currency,
    required this.accountId,
    required this.toAccountId,
    required this.budgetId,
    required this.note,
    required this.occurredOn,
  });
  final EntryKind kind;
  final String category;
  final double amount;

  /// The entry's own currency — defaults to the chosen account's, because
  /// spending from a USD card is almost always in USD.
  final String currency;

  final String? accountId;
  final String? toAccountId;

  /// Which budget this expense is charged against. Null is normal.
  final String? budgetId;

  final String? note;
  final DateTime occurredOn;
}

// ── Account sheet ───────────────────────────────────

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({
    required this.existing,
    required this.currency,
    required this.isShared,
  });

  final FinanceAccount? existing;

  /// The reader's main currency — only a default for the picker now that
  /// accounts each carry their own.
  final String currency;

  /// Shared accounts skip the privacy switch: "Ours" and "hidden from you"
  /// are contradictory, and 0016 forces them visible anyway.
  final bool isShared;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late final TextEditingController _emoji;
  late final TextEditingController _target;
  late final TextEditingController _creditLimit;
  late AccountKind _kind;
  late AccountClass _class;
  late String _currency;
  String? _subkind;
  late bool _visible;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _balance = TextEditingController(
      text: existing == null ? '' : _plain(existing.openingBalance),
    );
    _kind = existing?.kind ?? AccountKind.bank;
    _class = existing?.accountClass ?? _kind.defaultClass;
    _subkind = existing?.subkind;
    _emoji = TextEditingController(text: existing?.emoji ?? _kind.emoji);
    _currency = existing?.currency ?? widget.currency;
    _target = TextEditingController(
      text: existing?.targetAmount == null
          ? ''
          : _plain(existing!.targetAmount!),
    );
    _creditLimit = TextEditingController(
      text: existing?.creditLimit == null ? '' : _plain(existing!.creditLimit!),
    );
    // Solo accounts are private until their owner says otherwise — 0016
    // reverses the old behaviour of partners seeing everything by default.
    _visible = existing?.visibleToPartner ?? false;
  }

  static String _plain(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _emoji.dispose();
    _target.dispose();
    _creditLimit.dispose();
    super.dispose();
  }

  /// Switching kind swaps the emoji too, but only while it is still the
  /// previous kind's default — a hand-picked one is never overwritten.
  void _pickKind(AccountKind kind) {
    setState(() {
      final wasDefault = _emoji.text.trim() == _kind.emoji;
      final wasKindsClass = _class == _kind.defaultClass;
      _kind = kind;
      if (wasDefault) _emoji.text = kind.emoji;
      // Follow the new kind's usual side of the balance sheet, but only
      // while the user hasn't deliberately flipped it — someone who marked
      // their card an asset meant it.
      if (wasKindsClass) _class = kind.defaultClass;
      if (!kind.subkinds.contains(_subkind)) _subkind = null;
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the account a name first.')),
      );
      return;
    }
    final emoji = _emoji.text.trim();
    Navigator.pop(
      context,
      _AccountSaved(_AccountDraft(
        name: name,
        accountClass: _class,
        kind: _kind,
        subkind: _subkind,
        openingBalance: double.tryParse(_balance.text.trim()) ?? 0,
        currency: _currency,
        emoji: emoji.isEmpty ? _kind.emoji : emoji,
        targetAmount: double.tryParse(_target.text.trim()),
        creditLimit: double.tryParse(_creditLimit.text.trim()),
        visibleToPartner: _visible,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return AppBottomSheet(
      title: isNew ? 'Add an account' : 'Edit account',
      subtitle: 'Its balance is the opening amount plus everything you log',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppFieldLabel('Kind'),
          SizedBox(
            height: 74,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: AccountKind.values.map((kind) {
                final selected = kind == _kind;
                return GestureDetector(
                  onTap: () => _pickKind(kind),
                  child: AnimatedContainer(
                    duration: AppMotion.micro,
                    width: 84,
                    margin: const EdgeInsets.only(right: AppSpace.xs),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: selected ? AppColors.brand : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(kind.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: AppSpace.xxs),
                        Text(kind.label,
                            style: AppText.label(selected
                                ? AppColors.brand
                                : AppColors.muted)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppFieldLabel('Icon'),
                    AppSheetField(
                      controller: _emoji,
                      maxLength: 2,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppFieldLabel('Name'),
                    AppSheetField(
                      controller: _name,
                      hint: 'BPI joint account',
                      autofocus: isNew,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          AppFieldLabel(isNew ? 'Starting balance' : 'Opening balance'),
          AppSheetField(
            controller: _balance,
            hint: '0',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('Currency'),
          Wrap(
              spacing: AppSpace.xxs,
              runSpacing: AppSpace.xxs,
              children: _symbols.keys.map((code) {
                final selected = code == _currency;
                return GestureDetector(
                  onTap: () => setState(() => _currency = code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.xs, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.blush : AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: selected ? AppColors.brand : AppColors.border,
                      ),
                    ),
                    child: Text('${_symbols[code]} $code',
                        style: AppText.caption(
                            selected ? AppColors.brandDark : AppColors.body)),
                  ),
                );
              }).toList(),
          ),

          // ── Asset or liability ───────────────────────────
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('Counts as'),
          AppSegmented<AccountClass>(
            options: const {
              AccountClass.asset: 'Asset',
              AccountClass.liability: 'Liability',
            },
            value: _class,
            onChanged: (value) => setState(() => _class = value),
          ),
          const SizedBox(height: AppSpace.xxs),
          Text(
            _class == AccountClass.liability
                ? 'Enter what you owe as a positive number — it is '
                    'subtracted from net worth.'
                : 'Added to net worth.',
            style: AppText.caption(),
          ),

          // ── Subkind, for the kinds that have one ─────────
          if (_kind.subkinds.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            const AppFieldLabel('Type'),
            Wrap(
              spacing: AppSpace.xxs,
              runSpacing: AppSpace.xxs,
              children: _kind.subkinds.map((option) {
                final selected = option == _subkind;
                return GestureDetector(
                  onTap: () => setState(
                      () => _subkind = selected ? null : option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.xs, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.blush : AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: selected ? AppColors.brand : AppColors.border,
                      ),
                    ),
                    child: Text(option,
                        style: AppText.caption(
                            selected ? AppColors.brandDark : AppColors.body)),
                  ),
                );
              }).toList(),
            ),
          ],

          // ── A fund's finish line ─────────────────────────
          if (_kind.hasTarget) ...[
            const SizedBox(height: AppSpace.sm),
            const AppFieldLabel('Target'),
            AppSheetField(
              controller: _target,
              hint: 'e.g. 100000 — leave blank for none',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],

          // ── What a card or loan is allowed to reach ──────
          if (_kind == AccountKind.card || _kind == AccountKind.loan) ...[
            const SizedBox(height: AppSpace.sm),
            const AppFieldLabel('Credit limit'),
            AppSheetField(
              controller: _creditLimit,
              hint: 'Optional',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],

          // ── Privacy. Shared accounts have nothing to decide. ──
          if (!widget.isShared) ...[
            const SizedBox(height: AppSpace.sm),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _visible = !_visible),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Let them see this account',
                            style: AppText.body(AppColors.ink)
                                .copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          _visible
                              ? 'They can see the balance and its entries. '
                                  'Only you can change them.'
                              : 'Hidden from them entirely, entries included.',
                          style: AppText.caption(),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _visible,
                    activeThumbColor: AppColors.brand,
                    onChanged: (value) => setState(() => _visible = value),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpace.md),
          GradientButton(
            label: isNew ? 'Add account' : 'Save changes',
            onPressed: _save,
          ),
          if (!isNew) ...[
            const SizedBox(height: AppSpace.xs),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, const _Deleted()),
                child: Text('Delete account',
                    style: AppText.caption(AppColors.danger)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Entry sheet ─────────────────────────────────────

class _EntrySheet extends StatefulWidget {
  const _EntrySheet({
    required this.existing,
    required this.accounts,
    required this.budgets,
    required this.currency,
  });

  final FinanceEntry? existing;
  final List<FinanceAccount> accounts;

  /// Category budgets an expense can be charged against. Overall budgets
  /// are the total allowance, not something a single row is billed to.
  final List<FinanceBudget> budgets;

  final String currency;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late EntryKind _kind;
  late String _category;
  late String? _accountId;
  late String? _toAccountId;
  late String? _budgetId;
  late String _currency;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = existing?.kind ?? EntryKind.expense;
    _amount = TextEditingController(
      text: existing == null ? '' : _plain(existing.amount),
    );
    _note = TextEditingController(text: existing?.note ?? '');
    _category = existing?.category ?? _kind.categories.first;
    _accountId = existing?.accountId ??
        (widget.accounts.isEmpty ? null : widget.accounts.first.id);
    _toAccountId = existing?.toAccountId ?? _defaultDestination();
    _budgetId = existing?.budgetId;
    // An entry is in its account's currency unless told otherwise: paying
    // from a USD card is almost always a USD charge.
    _currency = existing?.currency ?? _accountCurrency() ?? widget.currency;
    _date = existing?.occurredOn ?? DateTime.now();
  }

  /// The currency of the account the money is coming from, if one is set.
  String? _accountCurrency() {
    for (final account in widget.accounts) {
      if (account.id == _accountId) return account.currency;
    }
    return null;
  }

  static String _plain(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : v.toString();

  /// A transfer's likely destination is the first savings or investment
  /// account that isn't where the money is coming from.
  String? _defaultDestination() {
    for (final account in widget.accounts) {
      if (account.id == _accountId) continue;
      if (account.kind == AccountKind.savings ||
          account.kind == AccountKind.investment) {
        return account.id;
      }
    }
    return widget.accounts
        .where((a) => a.id != _accountId)
        .map((a) => a.id)
        .firstOrNull;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _pickKind(EntryKind kind) {
    setState(() {
      _kind = kind;
      // Only spending consumes a budget — the DB rejects the rest.
      if (kind != EntryKind.expense) _budgetId = null;
      // Categories don't overlap between kinds, so a stale one would show
      // "Salary" on an expense.
      if (!kind.categories.contains(_category)) {
        _category = kind.categories.first;
      }
      _toAccountId ??= _defaultDestination();
    });
  }

  List<FinanceBudget> get _billableBudgets => widget.budgets
      .where((b) => !b.archived && b.scope == BudgetScope.category)
      .toList(growable: false);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount above zero.')),
      );
      return;
    }
    if (_kind == EntryKind.transfer &&
        (_toAccountId == null || _toAccountId == _accountId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('A transfer needs a different account to land in.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _EntrySaved(_EntryDraft(
        kind: _kind,
        category: _category,
        amount: amount,
        currency: _currency,
        accountId: _accountId,
        toAccountId: _toAccountId,
        budgetId: _budgetId,
        note: _note.text,
        occurredOn: _date,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final isTransfer = _kind == EntryKind.transfer;
    return AppBottomSheet(
      title: isNew ? 'Log an entry' : 'Edit entry',
      subtitle: isTransfer
          ? 'Moving your own money — it never counts as income or spending'
          : 'Money in, money out',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSegmented<EntryKind>(
            options: {for (final k in EntryKind.values) k: k.label},
            value: _kind,
            onChanged: _pickKind,
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('Amount'),
          AppSheetField(
            controller: _amount,
            hint: '0',
            autofocus: isNew,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefix: Padding(
              padding: const EdgeInsets.only(left: AppSpace.sm, right: 6),
              child: Text(
                _symbols[_currency] ?? _currency,
                style: AppText.subtitle(AppColors.brand),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          AppFieldLabel(isTransfer ? 'From' : 'Account'),
          _AccountPicker(
            accounts: widget.accounts,
            selected: _accountId,
            allowNone: !isTransfer,
            onChanged: (id) => setState(() {
              _accountId = id;
              if (_toAccountId == id) _toAccountId = _defaultDestination();
              // Follow the account into its own currency: spending from a
              // USD card is a USD charge far more often than not.
              final adopted = _accountCurrency();
              if (adopted != null) _currency = adopted;
            }),
          ),
          if (isTransfer) ...[
            const SizedBox(height: AppSpace.sm),
            const AppFieldLabel('To'),
            _AccountPicker(
              accounts:
                  widget.accounts.where((a) => a.id != _accountId).toList(),
              selected: _toAccountId,
              allowNone: false,
              onChanged: (id) => setState(() => _toAccountId = id),
            ),
          ],
          // Only spending can consume a budget, and only category budgets
          // are billable — the overall one is the allowance they all draw
          // from, not a line item.
          if (_kind == EntryKind.expense && _billableBudgets.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            const AppFieldLabel('Charge to budget'),
            Wrap(
              spacing: AppSpace.xxs,
              runSpacing: AppSpace.xxs,
              children: [
                _BudgetChip(
                  label: 'None',
                  selected: _budgetId == null,
                  onTap: () => setState(() => _budgetId = null),
                ),
                for (final budget in _billableBudgets)
                  _BudgetChip(
                    label: '${budget.emoji} ${budget.name}',
                    selected: budget.id == _budgetId,
                    onTap: () => setState(() => _budgetId = budget.id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('Category'),
          Wrap(
            spacing: AppSpace.xxs,
            runSpacing: AppSpace.xxs,
            children: _kind.categories.map((category) {
              final selected = category == _category;
              return GestureDetector(
                onTap: () => setState(() => _category = category),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.xs, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.blush : AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: selected ? AppColors.brand : AppColors.border,
                    ),
                  ),
                  child: Text(category,
                      style: AppText.caption(
                          selected ? AppColors.brandDark : AppColors.body)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('When'),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.calendar,
                      size: 15, color: AppColors.brand),
                  const SizedBox(width: AppSpace.xs),
                  Text(DateFormat('EEE d MMM yyyy').format(_date),
                      style: AppText.body(AppColors.ink)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('Note (optional)'),
          AppSheetField(
            controller: _note,
            hint: 'Groceries at the palengke',
            maxLines: 2,
          ),
          const SizedBox(height: AppSpace.md),
          GradientButton(
            label: isNew ? 'Log it' : 'Save changes',
            onPressed: _save,
          ),
          if (!isNew) ...[
            const SizedBox(height: AppSpace.xs),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, const _Deleted()),
                child: Text('Delete entry',
                    style: AppText.caption(AppColors.danger)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.accounts,
    required this.selected,
    required this.allowNone,
    required this.onChanged,
  });

  final List<FinanceAccount> accounts;
  final String? selected;

  /// Income and expenses can be logged without an account — cash you spent
  /// before setting the tracker up still belongs in the month's total. A
  /// transfer cannot: it has to move between two real balances.
  final bool allowNone;

  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return Text(
        allowNone
            ? 'No accounts yet — this still counts toward the month.'
            : 'Add a second account before transferring between them.',
        style: AppText.caption(),
      );
    }
    return Wrap(
      spacing: AppSpace.xxs,
      runSpacing: AppSpace.xxs,
      children: [
        if (allowNone) _chip(context, null, 'None', ''),
        ...accounts.map((a) => _chip(context, a.id, a.name, a.emoji)),
      ],
    );
  }

  Widget _chip(BuildContext context, String? id, String label, String emoji) {
    final isSelected = id == selected;
    return GestureDetector(
      onTap: () => onChanged(id),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blush : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.border,
          ),
        ),
        child: Text(
          emoji.isEmpty ? label : '$emoji $label',
          style: AppText.caption(
              isSelected ? AppColors.brandDark : AppColors.body),
        ),
      ),
    );
  }
}

/// Pill used by the entry sheet's budget picker. Its own widget because the
/// "None" option and the real budgets have to look identical — a budget
/// that renders differently from "no budget" invites mis-taps.
class _BudgetChip extends StatelessWidget {
  const _BudgetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.blush : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppText.caption(
              selected ? AppColors.brandDark : AppColors.body),
        ),
      ),
    );
  }
}

// ── Budget card ─────────────────────────────────────

/// One budget and how much of it is gone.
///
/// The bar is the point: a number pair ("2,400 of 5,000") gives you the
/// facts, but only the bar tells you at a glance that you are three days
/// into the month and most of the way through Food.
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.progress, this.onTap});

  final BudgetProgress progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final budget = progress.budget;
    final over = progress.isOver;

    // Over budget is the one state that earns a colour of its own; a bar
    // that simply stops at 100% hides the size of the overshoot.
    final barColor = over
        ? AppColors.danger
        : budget.isOverall
            ? AppColors.secondary
            : AppColors.brand;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: AppSpace.card,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: over ? AppColors.blushMid : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(budget.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(AppColors.ink)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          budget.isOverall
                              ? '${budget.period.label} allowance'
                              : budget.category ?? '',
                          style: AppText.caption(),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _money(progress.spent, budget.currency),
                    style: AppText.subtitle(
                        over ? AppColors.danger : AppColors.ink),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  // A zero limit has nothing to be a fraction of, so show an
                  // empty bar rather than dividing by zero.
                  value: progress.fraction ?? 0,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceSubtle,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(
                over
                    ? 'Over by ${_money(-progress.remaining, budget.currency)} '
                        'of ${_money(progress.limit, budget.currency)}'
                    : '${_money(progress.remaining, budget.currency)} left '
                        'of ${_money(progress.limit, budget.currency)}',
                style:
                    AppText.caption(over ? AppColors.danger : AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Budget sheet ────────────────────────────────────

class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet({
    required this.existing,
    required this.accounts,
    required this.currency,
    required this.overallTaken,
  });

  final FinanceBudget? existing;
  final List<FinanceAccount> accounts;
  final String currency;

  /// True when an overall budget already exists for this owner, so the
  /// scope switch offers only 'category'.
  final bool overallTaken;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late final TextEditingController _name;
  late final TextEditingController _limit;
  late final TextEditingController _emoji;
  late BudgetScope _scope;
  late String _category;
  late String _currency;
  late FinancePeriod _period;
  String? _fundingAccountId;
  late bool _rollover;

  /// Budgets constrain spending, so the category list is the expense one
  /// and nothing else.
  static List<String> get _categories => EntryKind.expense.categories;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _scope = existing?.scope ??
        (widget.overallTaken ? BudgetScope.category : BudgetScope.overall);
    _category = existing?.category ?? _categories.first;
    _name = TextEditingController(
      text: existing?.name ??
          (_scope == BudgetScope.overall ? 'Monthly budget' : _category),
    );
    _limit = TextEditingController(
      text: existing == null ? '' : _plain(existing.limitAmount),
    );
    _emoji = TextEditingController(
      text: existing?.emoji ?? (_scope == BudgetScope.overall ? '📊' : '🎯'),
    );
    _currency = existing?.currency ?? widget.currency;
    _period = existing?.period ?? FinancePeriod.monthly;
    _fundingAccountId = existing?.fundingAccountId;
    _rollover = existing?.rollover ?? false;
  }

  static String _plain(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    _emoji.dispose();
    super.dispose();
  }

  /// Switching scope renames the budget too, but only while the name is
  /// still the one this sheet suggested — a hand-typed name is never
  /// overwritten.
  void _pickScope(BudgetScope scope) {
    setState(() {
      final suggested =
          _scope == BudgetScope.overall ? 'Monthly budget' : _category;
      final untouched = _name.text.trim() == suggested;
      _scope = scope;
      if (untouched) {
        _name.text =
            scope == BudgetScope.overall ? 'Monthly budget' : _category;
      }
      final icon = _emoji.text.trim();
      if (icon == '📊' || icon == '🎯') {
        _emoji.text = scope == BudgetScope.overall ? '📊' : '🎯';
      }
    });
  }

  void _pickCategory(String category) {
    setState(() {
      final untouched = _name.text.trim() == _category;
      _category = category;
      if (untouched) _name.text = category;
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the budget a name first.')),
      );
      return;
    }
    final limit = double.tryParse(_limit.text.trim().replaceAll(',', ''));
    if (limit == null || limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a limit above zero.')),
      );
      return;
    }
    final emoji = _emoji.text.trim();
    Navigator.pop(
      context,
      _BudgetSaved(_BudgetDraft(
        scope: _scope,
        name: name,
        category: _scope == BudgetScope.category ? _category : null,
        emoji: emoji.isEmpty ? '🎯' : emoji,
        limitAmount: limit,
        currency: _currency,
        period: _period,
        fundingAccountId: _fundingAccountId,
        rollover: _rollover,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final canBeOverall =
        !widget.overallTaken || widget.existing?.scope == BudgetScope.overall;

    return AppBottomSheet(
      title: isNew ? 'New budget' : 'Edit budget',
      subtitle: 'Spending you charge to it fills its bar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canBeOverall) ...[
            const AppFieldLabel('Type'),
            AppSegmented<BudgetScope>(
              options: const {
                BudgetScope.overall: 'Overall',
                BudgetScope.category: 'Category',
              },
              value: _scope,
              onChanged: _pickScope,
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              _scope == BudgetScope.overall
                  ? 'The whole allowance. One per period.'
                  : 'A cap on one kind of spending, drawn from the overall '
                      'allowance.',
              style: AppText.caption(),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          if (_scope == BudgetScope.category) ...[
            const AppFieldLabel('Category'),
            Wrap(
              spacing: AppSpace.xxs,
              runSpacing: AppSpace.xxs,
              children: _categories.map((category) {
                final selected = category == _category;
                return GestureDetector(
                  onTap: () => _pickCategory(category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.xs, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.blush : AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: selected ? AppColors.brand : AppColors.border,
                      ),
                    ),
                    child: Text(category,
                        style: AppText.caption(
                            selected ? AppColors.brandDark : AppColors.body)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppFieldLabel('Icon'),
                    AppSheetField(
                      controller: _emoji,
                      maxLength: 2,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppFieldLabel('Name'),
                    AppSheetField(controller: _name, hint: 'Food'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('Limit'),
          AppSheetField(
            controller: _limit,
            hint: '0',
            autofocus: isNew,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefix: Padding(
              padding: const EdgeInsets.only(left: AppSpace.sm, right: 6),
              child: Text(
                _symbols[_currency] ?? _currency,
                style: AppText.subtitle(AppColors.brand),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('Resets'),
          AppSegmented<FinancePeriod>(
            options: const {
              FinancePeriod.weekly: 'Weekly',
              FinancePeriod.monthly: 'Monthly',
              FinancePeriod.yearly: 'Yearly',
            },
            value: _period,
            onChanged: (value) => setState(() => _period = value),
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('Currency'),
          Wrap(
            spacing: AppSpace.xxs,
            runSpacing: AppSpace.xxs,
            children: _symbols.keys.map((code) {
              final selected = code == _currency;
              return GestureDetector(
                onTap: () => setState(() => _currency = code),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.xs, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.blush : AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: selected ? AppColors.brand : AppColors.border,
                    ),
                  ),
                  child: Text('${_symbols[code]} $code',
                      style: AppText.caption(
                          selected ? AppColors.brandDark : AppColors.body)),
                ),
              );
            }).toList(),
          ),
          // Which pot this is understood to spend out of. A label on the
          // money, not a second ledger — the balance still comes from
          // entries, so the two can never disagree.
          if (widget.accounts.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            const AppFieldLabel('Spends from'),
            _AccountPicker(
              accounts: widget.accounts,
              selected: _fundingAccountId,
              allowNone: true,
              onChanged: (id) => setState(() => _fundingAccountId = id),
            ),
          ],
          const SizedBox(height: AppSpace.sm),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _rollover = !_rollover),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Roll over what is left',
                          style: AppText.body(AppColors.ink)
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        _rollover
                            ? 'Unspent money carries into the next period.'
                            : 'The budget starts fresh each period.',
                        style: AppText.caption(),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _rollover,
                  activeThumbColor: AppColors.brand,
                  onChanged: (value) => setState(() => _rollover = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          GradientButton(
            label: isNew ? 'Add budget' : 'Save changes',
            onPressed: _save,
          ),
          if (!isNew) ...[
            const SizedBox(height: AppSpace.xs),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, const _Deleted()),
                child: Text('Delete budget',
                    style: AppText.caption(AppColors.danger)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

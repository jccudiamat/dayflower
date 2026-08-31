import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/finance_repository.dart';

/// Picks the currency every total is shown in, and keeps the rates that
/// make those totals possible.
///
/// The two belong in one sheet because they fail together: choosing a main
/// currency you have no rate for turns the overview into a row of dashes,
/// and the only useful thing to do at that moment is add the rate. Sending
/// the user to a second screen to fix what the first one just broke would
/// be a worse design than one slightly longer sheet.
Future<void> showCurrencySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CurrencySheet(),
  );
}

class CurrencySheet extends ConsumerStatefulWidget {
  const CurrencySheet({super.key});

  @override
  ConsumerState<CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends ConsumerState<CurrencySheet> {
  bool _refreshing = false;
  String? _error;

  Future<void> _setMain(String currency) async {
    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;
    try {
      await ref.read(financeRepositoryProvider).setMainCurrency(
            pairId: pair.id,
            userId: userId,
            currency: currency,
          );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _refreshRates() async {
    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;

    final inUse = ref.read(financeCurrenciesInUseProvider);
    final table = ref.read(financeRatesProvider).valueOrNull ?? FxTable.empty;
    final pinned = {
      for (final entry in table.rates.entries)
        if (entry.value.pinned) entry.key,
    };

    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final count = await ref.read(financeRepositoryProvider).refreshLiveRates(
            pairId: pair.id,
            userId: userId,
            currencies: inUse,
            pinned: pinned,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count == 0
              ? 'Nothing to update — every rate is pinned or already yours.'
              : 'Updated $count rate${count == 1 ? '' : 's'}.'),
        ),
      );
    } catch (e) {
      // Say why. A refresh that silently does nothing is worse than one
      // that admits it could not reach the network.
      if (mounted) {
        setState(() => _error = 'Could not reach the rate service. '
            'You can still type a rate in by hand below.');
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _editRate(String currency, FxRate? existing) async {
    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;

    final controller = TextEditingController(
      text: existing == null ? '' : _trim(existing.usdRate),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('1 USD in $currency', style: AppText.title()),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'e.g. 3.6725',
            suffixText: currency,
            hintStyle: AppText.body(AppColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: AppText.body(AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.trim().replaceAll(',', '')),
            ),
            child: Text('Save', style: AppText.body(AppColors.brand)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value <= 0) return;

    try {
      // Typing a rate pins it: the user just told us what it is, and the
      // next live refresh overwriting that would be the tool arguing with
      // the person using it.
      await ref.read(financeRepositoryProvider).saveRate(
            pairId: pair.id,
            currency: currency,
            usdRate: value,
            pinned: true,
            userId: userId,
          );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _unpin(String currency, FxRate rate) async {
    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;
    try {
      await ref.read(financeRepositoryProvider).saveRate(
            pairId: pair.id,
            currency: currency,
            usdRate: rate.usdRate,
            pinned: false,
            userId: userId,
          );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  static String _trim(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final main = ref.watch(financeMainCurrencyProvider).valueOrNull ?? 'PHP';
    final table = ref.watch(financeRatesProvider).valueOrNull ?? FxTable.empty;
    final inUse = ref.watch(financeCurrenciesInUseProvider);

    // Every currency worth offering: the common list, plus anything an
    // account or budget already uses that isn't on it.
    final offered = <String>{...kCommonCurrencies, ...inUse}.toList()..sort();

    // Currencies that need a rate to reach `main`, and don't have one.
    final missing = inUse
        .where((c) => c != main && !table.has(c))
        .toList(growable: false);

    return AppBottomSheet(
      title: 'Currency & rates',
      subtitle: 'Totals convert to your main currency. Each account keeps '
          'the currency it is actually held in.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppFieldLabel('Main currency'),
          Wrap(
            spacing: AppSpace.xxs,
            runSpacing: AppSpace.xxs,
            children: offered.map((code) {
              final selected = code == main;
              return GestureDetector(
                onTap: selected ? null : () => _setMain(code),
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
                  child: Text(
                    '${currencySymbol(code).trim()} $code',
                    style: AppText.caption(
                        selected ? AppColors.brandDark : AppColors.body),
                  ),
                ),
              );
            }).toList(),
          ),

          if (missing.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.xs),
              decoration: BoxDecoration(
                color: AppColors.dangerSubtle,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'No rate for ${missing.join(', ')} → $main. '
                'Those accounts are left out of the totals until there is '
                'one — a net worth quietly missing an account would be worse '
                'than one that says so.',
                style: AppText.caption(AppColors.danger),
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(_error!, style: AppText.caption(AppColors.danger)),
          ],

          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(child: Text('RATES', style: AppText.label())),
              if (table.oldestAsOf != null)
                Text(
                  'as of ${DateFormat('d MMM').format(table.oldestAsOf!)}',
                  style: AppText.caption(),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xxs),

          // Only currencies actually in play. Listing all twenty would bury
          // the two that matter.
          ...inUse.where((c) => c != main).map((currency) {
            final rate = table.rates[currency];
            return _RateRow(
              currency: currency,
              main: main,
              rate: rate,
              table: table,
              onEdit: () => _editRate(currency, rate),
              onUnpin:
                  rate != null && rate.pinned ? () => _unpin(currency, rate) : null,
            );
          }),

          if (inUse.where((c) => c != main).isEmpty)
            Text(
              'Everything is in $main, so there is nothing to convert.',
              style: AppText.caption(),
            ),

          const SizedBox(height: AppSpace.md),
          GradientButton(
            label: _refreshing ? 'Fetching…' : 'Refresh live rates',
            onPressed: _refreshing ? null : _refreshRates,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Rates you type in are pinned and a refresh leaves them alone.',
            style: AppText.caption(),
          ),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.currency,
    required this.main,
    required this.rate,
    required this.table,
    required this.onEdit,
    required this.onUnpin,
  });

  final String currency;
  final String main;
  final FxRate? rate;
  final FxTable table;
  final VoidCallback onEdit;
  final VoidCallback? onUnpin;

  @override
  Widget build(BuildContext context) {
    // Show the conversion the user actually cares about — one unit of the
    // foreign currency in their own money — rather than the USD anchor the
    // table happens to be stored against.
    final converted = table.convert(1, from: currency, to: main);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  converted == null
                      ? '1 $currency = —'
                      : '1 $currency = ${converted.toStringAsFixed(4)} $main',
                  style: AppText.body(
                    converted == null ? AppColors.danger : AppColors.ink,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  rate == null
                      ? 'No rate yet — tap to add one'
                      : rate!.pinned
                          ? 'Yours · pinned'
                          : 'Live · ${DateFormat('d MMM').format(rate!.asOf)}',
                  style: AppText.caption(),
                ),
              ],
            ),
          ),
          if (onUnpin != null)
            TextButton(
              onPressed: onUnpin,
              child: Text('Unpin', style: AppText.caption(AppColors.muted)),
            ),
          TextButton(
            onPressed: onEdit,
            child: Text(rate == null ? 'Add' : 'Edit',
                style: AppText.caption(AppColors.brand)),
          ),
        ],
      ),
    );
  }
}

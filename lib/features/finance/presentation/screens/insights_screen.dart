import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/ios_back_button.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/finance_repository.dart';
import '../../domain/finance_insights.dart';
import '../widgets/insight_charts.dart';

/// The month, read back to you — and exportable as one image.
///
/// The whole point of the export is that the thing shared is *the card*,
/// not a screenshot of a phone: no status bar, no nav bar, no half-scrolled
/// third chart. So the shareable part is one widget under a
/// [RepaintBoundary] and the page is built around it, rather than the
/// export being a screenshot of the page.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  final _shareable = GlobalKey();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  FinanceScope _scope = FinanceScope.shared;
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final pair = ref.watch(currentPairProvider).valueOrNull;
    final me = ref.watch(userProfileProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final currency = ref.watch(financeMainCurrencyProvider).valueOrNull ?? 'PHP';
    final fx = ref.watch(financeRatesProvider).valueOrNull ?? FxTable.empty;

    final partnerId = userId == null ? null : pair?.partnerIdFor(userId);
    final owner = switch (_scope) {
      FinanceScope.shared => null,
      FinanceScope.mine => userId,
      FinanceScope.partner => partnerId,
    };
    bool scopeMatches(String? o) =>
        _scope == FinanceScope.shared ? o == null : (o != null && o == owner);

    final accounts = (ref.watch(financeAccountsProvider).valueOrNull ??
            const <FinanceAccount>[])
        .where((a) => scopeMatches(a.ownerId))
        .toList();
    final entries = (ref.watch(financeEntriesProvider).valueOrNull ??
            const <FinanceEntry>[])
        .where((e) => scopeMatches(e.ownerId))
        .toList();
    final accountIds = {for (final a in accounts) a.id};
    final holdings =
        (ref.watch(financeHoldingsProvider).valueOrNull ?? const <Holding>[])
            .where((h) => accountIds.contains(h.accountId))
            .toList();

    // Net worth and the pots come from the one place that derives them, so
    // this page cannot disagree with the Finances screen behind it.
    final summary = FinanceSummary.from(
      accounts: accounts,
      entries: entries,
      budgets: const [],
      holdings: holdings,
      month: _month,
      mainCurrency: currency,
      fx: fx,
    );

    final insights = FinanceInsights.from(
      entries: entries,
      month: _month,
      currency: currency,
      fx: fx,
      netWorth: summary.netWorth,
      saved: summary.saved,
      invested: summary.invested,
    );

    final names = [
      me?.petName ?? me?.displayName,
      partner?.petName ?? partner?.displayName,
    ].whereType<String>().join(' & ');

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
                children: [
                  IosBackButton(onTap: () => context.go(Routes.finance)),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(child: Text('Insights', style: AppText.hero())),
                  _ShareButton(
                    busy: _sharing,
                    onTap: insights.isEmpty ? null : _share,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.sm, 0, AppSpace.sm, AppSpace.lg),
                children: [
                  _MonthPicker(
                    month: _month,
                    onShift: (by) => setState(
                        () => _month = DateTime(_month.year, _month.month + by)),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  AppSegmented<FinanceScope>(
                    options: {
                      FinanceScope.shared: 'Ours',
                      FinanceScope.mine: 'Mine',
                      if (partner != null)
                        FinanceScope.partner:
                            partner.petName ?? partner.displayName,
                    },
                    value: _scope,
                    onChanged: (value) => setState(() => _scope = value),
                  ),
                  const SizedBox(height: AppSpace.sm),

                  // Everything inside this boundary is what gets exported.
                  RepaintBoundary(
                    key: _shareable,
                    child: InsightsCard(
                      insights: insights,
                      names: names,
                      scopeLabel: switch (_scope) {
                        FinanceScope.shared => 'Together',
                        FinanceScope.mine => 'Mine',
                        FinanceScope.partner => 'Theirs',
                      },
                    ),
                  ),

                  if (insights.unconvertible.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xs),
                    _Warning(
                      text: 'Amounts in '
                          '${insights.unconvertible.join(', ')} are left out '
                          '— there is no rate on file for them yet.',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders the card to a PNG and hands it to the system share sheet.
  ///
  /// ⚠️ **`pixelRatio` is not cosmetic here.** A `RepaintBoundary` renders
  /// at logical size by default, so the export would come out at roughly
  /// 340px wide — fine on the screen it came from and unreadable everywhere
  /// it is going. 3× is about a phone screenshot's density.
  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _shareable.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final bytes = data.buffer.asUint8List();

      final path = await _writeTemp(bytes);
      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'image/png')],
          text: 'Our ${DateFormat('MMMM').format(_month)}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't make the image: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// A real file, because a share sheet takes a file rather than bytes.
  ///
  /// The name carries the month, so a saved image is identifiable months
  /// later — and it is overwritten each time rather than accumulating one
  /// PNG per share in the cache directory.
  Future<String> _writeTemp(Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final name = 'dayflower-${DateFormat('yyyy-MM').format(_month)}.png';
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

/* ── The exported card ───────────────────────────────────── */

/// The thing that becomes the image.
///
/// Self-contained on purpose: it carries its own background, its own
/// heading and its own footer mark, because once it is a PNG in somebody
/// else's chat there is no app around it to supply any of that.
class InsightsCard extends StatelessWidget {
  const InsightsCard({
    super.key,
    required this.insights,
    required this.names,
    required this.scopeLabel,
  });

  final FinanceInsights insights;
  final String names;
  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM y').format(insights.month),
                      style: AppText.title(Colors.white),
                    ),
                    Text(
                      names.isEmpty ? scopeLabel : '$names · $scopeLabel',
                      style: AppText.caption(AppColors.onDarkMuted),
                    ),
                  ],
                ),
              ),
              const Text('🌷', style: TextStyle(fontSize: 20)),
            ],
          ),

          if (insights.isEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            Center(
              child: Text(
                'Nothing recorded this month.',
                style: AppText.body(AppColors.onDarkMuted),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
          ] else ...[
            const SizedBox(height: AppSpace.md),
            _Headline(insights: insights),

            const SizedBox(height: AppSpace.md),
            Text('WHERE IT WENT',
                style: AppText.label(AppColors.onDarkMuted)),
            const SizedBox(height: AppSpace.xs),
            CategoryDonut(
              slices: insights.categories,
              total: insights.expenses,
              currency: insights.currency,
            ),

            const SizedBox(height: AppSpace.md),
            Text('THE LAST ${FinanceInsights.monthsBack} MONTHS',
                style: AppText.label(AppColors.onDarkMuted)),
            const SizedBox(height: AppSpace.xs),
            MonthlyBars(
              months: insights.months,
              currency: insights.currency,
            ),

            if (insights.headlines.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              for (final line in insights.headlines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('·', style: AppText.body(AppColors.brandLight)),
                      const SizedBox(width: AppSpace.xs),
                      Expanded(
                        child: Text(line,
                            style: AppText.caption(AppColors.onDark)),
                      ),
                    ],
                  ),
                ),
            ],
          ],

          const SizedBox(height: AppSpace.sm),
          Divider(color: Colors.white.withValues(alpha: .10), height: 1),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Text('Dayflower', style: AppText.label(AppColors.onDarkMuted)),
              const Spacer(),
              Text(
                // Says which money the figures are in. Without it a shared
                // image is a set of numbers with no unit.
                'in ${insights.currency}',
                style: AppText.label(AppColors.onDarkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// In, out, and what is left — the three numbers everything else explains.
class _Headline extends StatelessWidget {
  const _Headline({required this.insights});
  final FinanceInsights insights;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Figure(
          label: 'IN',
          value: insights.income,
          currency: insights.currency,
          colour: AppColors.sage,
        ),
        _Figure(
          label: 'OUT',
          value: insights.expenses,
          currency: insights.currency,
          colour: AppColors.brand,
        ),
        _Figure(
          label: 'LEFT',
          value: insights.net,
          currency: insights.currency,
          colour: insights.net >= 0 ? AppColors.onDark : AppColors.brandLight,
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.currency,
    required this.colour,
  });

  final String label;
  final double value;
  final String currency;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final symbol = kCurrencySymbols[currency] ?? '$currency ';
    final text = value.abs() >= 10000
        ? NumberFormat.compactCurrency(symbol: symbol, decimalDigits: 1)
            .format(value)
        : NumberFormat.currency(symbol: symbol, decimalDigits: 0).format(value);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label(AppColors.onDarkMuted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              style: AppText.subtitle(colour).copyWith(fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }
}

/* ── Chrome ──────────────────────────────────────────────── */

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .4 : 1,
      child: Material(
        color: AppColors.brand,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(CupertinoIcons.share,
                    size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.month, required this.onShift});

  final DateTime month;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final isThisMonth = month.year == DateTime.now().year &&
        month.month == DateTime.now().month;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => onShift(-1),
          icon: const Icon(CupertinoIcons.chevron_left, size: 16),
          color: AppColors.muted,
        ),
        Text(DateFormat('MMMM y').format(month), style: AppText.subtitle()),
        IconButton(
          // No forward past the current month: there is nothing recorded in
          // the future, and a chart of it is an empty chart.
          onPressed: isThisMonth ? null : () => onShift(1),
          icon: const Icon(CupertinoIcons.chevron_right, size: 16),
          color: isThisMonth ? AppColors.border : AppColors.muted,
        ),
      ],
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(
        color: AppColors.dangerSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text, style: AppText.caption(AppColors.danger)),
    );
  }
}

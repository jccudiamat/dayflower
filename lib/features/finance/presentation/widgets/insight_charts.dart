/// The charts on the Insights page.
///
/// Hand-painted rather than pulled from a charting package. Two reasons,
/// and the second is the one that decided it: this app already draws its
/// own progress rings, dashed arch and sparkline, so a package would be a
/// second visual language; and every charting library brings its own colour
/// system, which is exactly the thing that has to match here — the image
/// this page exports is the app, seen by whoever it is sent to.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/finance_models.dart';
import '../../domain/finance_insights.dart';



/// The palette wedges and bars are drawn from, in order.
///
/// Ordered so that neighbouring slices are never neighbouring hues — a
/// donut is read by comparing adjacent wedges, and two pinks side by side
/// are one wedge with a seam in it.
const _series = <Color>[
  AppColors.brand,
  AppColors.secondary,
  AppColors.amber,
  AppColors.sage,
  AppColors.gradientPurple,
  AppColors.brandLight,
];

Color seriesColour(int index) => _series[index % _series.length];

/* ── Where it went ───────────────────────────────────────── */

/// Spending by category, as a donut with a legend beside it.
///
/// A donut rather than a pie because the hole is where the total goes, and
/// the total is the thing the legend's percentages are shares *of* — having
/// to look elsewhere for it is what makes most pie charts hard to read.
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({
    super.key,
    required this.slices,
    required this.total,
    required this.currency,
  });

  final List<CategorySlice> slices;
  final double total;
  final String currency;

  /// Everything past this is gathered into one "Other" wedge. Six is about
  /// where a legend stops being readable and a wedge stops being clickable
  /// at this size.
  static const _maxWedges = 5;

  List<CategorySlice> get _wedges {
    if (slices.length <= _maxWedges + 1) return slices;
    final head = slices.take(_maxWedges).toList();
    final tail = slices.skip(_maxWedges);
    final rest = tail.fold<double>(0, (sum, s) => sum + s.amount);
    return [
      ...head,
      CategorySlice(
        category: 'Everything else',
        amount: rest,
        share: total <= 0 ? 0 : rest / total,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final wedges = _wedges;
    if (wedges.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 118,
          height: 118,
          child: CustomPaint(
            painter: _DonutPainter(wedges),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('OUT', style: AppText.label(AppColors.onDarkMuted)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _compact(total, currency),
                      style: AppText.subtitle(Colors.white)
                          .copyWith(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < wedges.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: seriesColour(i),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          wedges[i].category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption(AppColors.onDark),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(wedges[i].share * 100).round()}%',
                        style: AppText.caption(AppColors.onDarkMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.wedges);
  final List<CategorySlice> wedges;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2 - 8;
    const stroke = 15.0;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: .10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // From twelve o'clock and clockwise, the direction a dial is read.
    var start = -math.pi / 2;
    for (var i = 0; i < wedges.length; i++) {
      final sweep = 2 * math.pi * wedges[i].share;
      if (sweep <= 0) continue;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        start,
        // A hair short, so adjacent wedges have a visible seam instead of
        // melting into one another.
        math.max(sweep - 0.02, 0.005),
        false,
        Paint()
          ..color = seriesColour(i)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}

/* ── In and out, month by month ──────────────────────────── */

/// Paired bars per month: what came in, what went out.
///
/// Both scaled against the same peak, which is the only way the two are
/// comparable — scaling each to its own maximum would make a £200 month and
/// a £2,000 month draw the same bar.
class MonthlyBars extends StatelessWidget {
  const MonthlyBars({
    super.key,
    required this.months,
    required this.currency,
  });

  final List<MonthTotals> months;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();

    final peak = months.fold<double>(
      0,
      (max, m) => math.max(max, math.max(m.income, m.expenses)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _Key(colour: AppColors.sage, label: 'In'),
            const SizedBox(width: AppSpace.sm),
            const _Key(colour: AppColors.brand, label: 'Out'),
            const Spacer(),
            if (peak > 0)
              Text(
                'peak ${_compact(peak, currency)}',
                style: AppText.label(AppColors.onDarkMuted),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in months)
                Expanded(
                  child: _MonthColumn(
                    totals: m,
                    peak: peak,
                    // Only the month being viewed is filled in; the rest
                    // are context, and dimming them is what makes the
                    // current one findable at a glance.
                    isCurrent: m == months.last,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthColumn extends StatelessWidget {
  const _MonthColumn({
    required this.totals,
    required this.peak,
    required this.isCurrent,
  });

  final MonthTotals totals;
  final double peak;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    double height(double value) {
      if (peak <= 0) return 0;
      final scaled = 72 * (value / peak);
      // A month with something in it always draws at least a stub, or a
      // small month reads as no month at all.
      return value > 0 ? math.max(scaled, 3) : 0;
    }

    final opacity = isCurrent ? 1.0 : .55;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Bar(
              height: height(totals.income),
              colour: AppColors.sage.withValues(alpha: opacity),
            ),
            const SizedBox(width: 3),
            _Bar(
              height: height(totals.expenses),
              colour: AppColors.brand.withValues(alpha: opacity),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          DateFormat('MMM').format(totals.month),
          style: AppText.label(
            isCurrent ? AppColors.onDark : AppColors.onDarkMuted,
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.colour});
  final double height;
  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: height,
        decoration: BoxDecoration(
          color: colour,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      );
}

class _Key extends StatelessWidget {
  const _Key({required this.colour, required this.label});
  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: AppText.label(AppColors.onDarkMuted)),
        ],
      );
}

String _compact(double value, String currency) {
  final symbol = kCurrencySymbols[currency] ?? '$currency ';
  if (value.abs() >= 10000) {
    return NumberFormat.compactCurrency(symbol: symbol, decimalDigits: 1)
        .format(value);
  }
  return NumberFormat.currency(symbol: symbol, decimalDigits: 0).format(value);
}

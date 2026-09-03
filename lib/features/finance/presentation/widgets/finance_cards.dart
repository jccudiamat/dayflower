/// The card-and-carousel layer of the Finance screen.
///
/// Laid out after the reference the user supplied: a horizontal **Wallet**
/// of account cards, a **spend** card carrying a sparkline and a
/// month-on-month delta, and a horizontal row of **Goals** drawn as
/// progress rings.
///
/// ⚠️ **The palette is this app's, not the reference's.** The reference is
/// built on a saturated teal; Dayflower's dark surface is the aubergine
/// already used by the Us stat tiles and the net-worth card, with the brand
/// pink for progress. Copying the teal would have put a second, unrelated
/// colour system into an app whose whole identity is the pink→purple
/// gradient.
///
/// One thing from the reference is deliberately **not** here: its
/// "Transfer to" row of friends' faces. This app has exactly one other
/// person in it, and a horizontal list to pick them from would be a control
/// with one option pretending to be a picker.
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/finance_models.dart';



const _symbols = kCurrencySymbols;

String money(double value, String currency, {bool compact = false}) {
  final symbol = _symbols[currency] ?? '$currency ';
  if (compact && value.abs() >= 100000) {
    return NumberFormat.compactCurrency(symbol: symbol, decimalDigits: 1)
        .format(value);
  }
  return NumberFormat.currency(
    symbol: symbol,
    decimalDigits: value.truncateToDouble() == value ? 0 : 2,
  ).format(value);
}

/* ── Wallet ──────────────────────────────────────────────── */

/// The accounts, side by side, the way the reference shows cards.
///
/// Horizontal rather than the stacked list it replaced: balances are
/// glanceable and comparative — you want to see them next to each other —
/// and a vertical list of five accounts pushed everything else off the
/// screen.
class WalletStrip extends StatelessWidget {
  const WalletStrip({
    super.key,
    required this.accounts,
    required this.balances,
    required this.marketValues,
    required this.onTap,
    required this.onAdd,
  });

  final List<FinanceAccount> accounts;

  /// Account id → balance **in that account's own currency**. Never
  /// converted here: the number on a card is the one its holder would
  /// recognise, and conversion happens only where things are totalled.
  final Map<String, double> balances;
  final Map<String, double> marketValues;

  final void Function(FinanceAccount)? onTap;
  final VoidCallback? onAdd;

  static const double _height = 128;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        itemCount: accounts.length + (onAdd == null ? 0 : 1),
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.xs),
        itemBuilder: (context, i) {
          if (i == accounts.length) return _AddCard(onTap: onAdd!);
          final account = accounts[i];
          return _WalletCard(
            account: account,
            // An investment account is worth its positions, not the cash
            // that was put in — same rule as the net-worth total.
            amount: marketValues[account.id] ?? balances[account.id] ?? 0,
            onTap: onTap == null ? null : () => onTap!(account),
          );
        },
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.account,
    required this.amount,
    required this.onTap,
  });

  final FinanceAccount account;
  final double amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLiability = account.accountClass == AccountClass.liability;

    return SizedBox(
      width: 176,
      child: Material(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(account.emoji, style: const TextStyle(fontSize: 20)),
                    const Spacer(),
                    Text(
                      account.currency,
                      style: AppText.label(AppColors.onDarkMuted),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(AppColors.onDarkMuted),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(amount, account.currency, compact: true),
                    maxLines: 1,
                    style: AppText.title(Colors.white).copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isLiability)
                  // Liabilities are stored positive, so the card has to say
                  // which direction the number points or 1,600 owed reads
                  // exactly like 1,600 held.
                  Text('owed', style: AppText.label(AppColors.brandLight)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.add,
                    size: 20, color: AppColors.secondary),
                const SizedBox(height: 4),
                Text('Add', style: AppText.caption(AppColors.secondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ── Spending ────────────────────────────────────────────── */

/// "Total spent in April · ↓13%", with the month drawn behind it.
///
/// The delta is the point of the card. A spend figure on its own is a
/// number; the same figure next to last month's is a direction, and a
/// direction is the only part anybody acts on.
class SpendCard extends StatelessWidget {
  const SpendCard({
    super.key,
    required this.month,
    required this.spent,
    required this.previousSpent,
    required this.daily,
    required this.currency,
  });

  final DateTime month;

  /// Both already converted to [currency] — this is a total, and totals are
  /// the one place conversion belongs.
  final double spent;

  /// Null when there is no previous month on file, which is different from
  /// a previous month of zero: the first month has nothing to compare to
  /// and the card shows no chip at all rather than "↑100%".
  final double? previousSpent;

  /// One figure per day of the month, oldest first, in [currency].
  final List<double> daily;

  final String currency;

  double? get _delta {
    final previous = previousSpent;
    if (previous == null || previous <= 0) return null;
    return (spent - previous) / previous;
  }

  @override
  Widget build(BuildContext context) {
    final delta = _delta;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total spent in ${DateFormat('MMMM').format(month)}',
                  style: AppText.caption(AppColors.onDarkMuted),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          money(spent, currency, compact: true),
                          maxLines: 1,
                          style: AppText.title(Colors.white).copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (delta != null) ...[
                      const SizedBox(width: AppSpace.xs),
                      _DeltaChip(delta: delta),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          SizedBox(
            width: 108,
            height: 46,
            child: CustomPaint(painter: _SparklinePainter(daily)),
          ),
        ],
      ),
    );
  }
}

/// ↓13% — and down is the good direction here, which is why this is not the
/// usual green-up/red-down. Spending less than last month is the win.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta});
  final double delta;

  @override
  Widget build(BuildContext context) {
    final down = delta < 0;
    final percent = (delta.abs() * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (down ? AppColors.success : AppColors.brand)
            .withValues(alpha: .22),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            down ? CupertinoIcons.arrow_down : CupertinoIcons.arrow_up,
            size: 11,
            color: down ? AppColors.success : AppColors.brandLight,
          ),
          const SizedBox(width: 2),
          Text(
            '$percent%',
            style: AppText.label(
              down ? AppColors.success : AppColors.brandLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// The little line behind the spend figure.
///
/// It plots the **running total** through the month rather than each day's
/// spend, so the shape always climbs and its steepness is the story. A
/// per-day plot of a couple's spending is mostly zeroes with occasional
/// spikes, which reads as noise at this size.
class _SparklinePainter extends CustomPainter {
  const _SparklinePainter(this.daily);

  final List<double> daily;

  @override
  void paint(Canvas canvas, Size size) {
    if (daily.length < 2) return;

    var running = 0.0;
    final totals = [for (final d in daily) running += d];
    final peak = totals.last;
    // Nothing spent yet: a flat line at the bottom says that honestly, and
    // dividing by the peak would not.
    final scale = peak <= 0 ? 0.0 : 1 / peak;

    final path = Path();
    for (var i = 0; i < totals.length; i++) {
      final x = size.width * (i / (totals.length - 1));
      final y = size.height - (size.height - 2) * (totals[i] * scale);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // A soft fill under the line, so the card reads as a chart at a glance
    // rather than as a stray stroke.
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.brandLight.withValues(alpha: .35),
            AppColors.brandLight.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.brandLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      !listEquals(old.daily, daily);
}

bool listEquals(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/* ── Goals ───────────────────────────────────────────────── */

/// The goals, as rings, side by side.
class GoalsStrip extends StatelessWidget {
  const GoalsStrip({
    super.key,
    required this.goals,
    required this.balances,
    required this.onTap,
    required this.onAdd,
  });

  final List<FinanceGoal> goals;

  /// Passed straight through to [FinanceGoal.savedGiven] — the same map
  /// that draws the wallet cards, so a linked goal's ring and its account's
  /// balance can never disagree.
  final Map<String, double> balances;

  final void Function(FinanceGoal)? onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        itemCount: goals.length + (onAdd == null ? 0 : 1),
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.xs),
        itemBuilder: (context, i) {
          if (i == goals.length) return _AddCard(onTap: onAdd!);
          final goal = goals[i];
          return _GoalCard(
            goal: goal,
            saved: goal.savedGiven(balances),
            fraction: goal.fractionGiven(balances) ?? 0,
            onTap: onTap == null ? null : () => onTap!(goal),
          );
        },
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.saved,
    required this.fraction,
    required this.onTap,
  });

  final FinanceGoal goal;
  final double saved;
  final double fraction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reached = saved >= goal.targetAmount;

    return SizedBox(
      width: 232,
      child: Material(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.sm),
            child: Row(
              children: [
                _ProgressRing(fraction: fraction, reached: reached),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(goal.emoji,
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              goal.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.subtitle(Colors.white)
                                  .copyWith(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${money(saved, goal.currency, compact: true)}'
                          '  /  '
                          '${money(goal.targetAmount, goal.currency, compact: true)}',
                          maxLines: 1,
                          style: AppText.caption(AppColors.onDarkMuted),
                        ),
                      ),
                      if (goal.isLinked)
                        // Says the number maintains itself, which is the
                        // difference between this and a figure somebody has
                        // to remember to update.
                        Text('tracks an account',
                            style: AppText.label(AppColors.onDarkMuted))
                      else if (goal.daysLeft != null)
                        Text(
                          goal.daysLeft! < 0
                              ? 'past its date'
                              : '${goal.daysLeft} days left',
                          style: AppText.label(
                            goal.daysLeft! < 0
                                ? AppColors.brandLight
                                : AppColors.onDarkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The percentage ring from the reference.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.fraction, required this.reached});

  final double fraction;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 62,
      child: CustomPaint(
        painter: _RingPainter(fraction: fraction, reached: reached),
        child: Center(
          child: Text(
            reached ? '✓' : '${(fraction * 100).toStringAsFixed(1)}%',
            style: AppText.label(Colors.white).copyWith(
              fontSize: reached ? 20 : 12.5,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.reached});

  final double fraction;
  final bool reached;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2 - 3;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: .14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    if (fraction <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2, // from twelve o'clock, the way a dial is read
      2 * math.pi * fraction,
      false,
      Paint()
        ..color = reached ? AppColors.success : AppColors.brandLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        // Rounded, so a 2% ring is still a visible mark rather than a
        // hairline nobody can see.
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.reached != reached;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../finance/presentation/widgets/finance_cards.dart' show money;
import '../../data/together_assets.dart';
import '../../data/together_savings.dart';
import 'together_art.dart';
import 'together_card.dart';

/// Our Savings: the couple's savings goal, how much is in it, and how far
/// that is from the target. Opens Finances, which is where it is kept —
/// and which, since the old Together list went, is reached from here.
class TogetherSavingsCard extends ConsumerWidget {
  const TogetherSavingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savings = ref.watch(togetherSavingsProvider);
    void open() => context.push(Routes.finance);
    final current = savings.valueOrNull;

    return TogetherCard(
      padding: const EdgeInsets.all(TogetherStyle.padTight),
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TogetherCardHeader(
            icon: Icons.bar_chart_rounded,
            iconColor: TogetherStyle.iconSavings,
            title: 'Our Savings',
            subtitle: switch (savings) {
              AsyncData(value: final s?) => s.goal.name,
              AsyncData() => 'Nothing saved for yet',
              AsyncError() => 'Plan money together',
              _ => null,
            },
          ),
          const SizedBox(height: AppSpace.compact),
          if (savings.isLoading)
            const TogetherSkeleton(lines: 3)
          else if (current == null)
            ..._empty(open)
          else
            ..._progress(current),
        ],
      ),
    );
  }

  List<Widget> _progress(TogetherSavings s) {
    final currency = s.goal.currency;
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shrinks rather than wraps: "₱1,250,000" in a half card is
              // one number, and a number broken over two lines is two.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                // softWrap off, for the reason in TogetherCardHeader.
                child: Text(money(s.saved, currency),
                    maxLines: 1,
                    softWrap: false,
                    style: TogetherStyle.figure(24)),
              ),
              const SizedBox(height: 2),
              Text('of ${money(s.goal.targetAmount, currency)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TogetherStyle.listMeta()),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.xxs),
        const TogetherArt(
          TogetherAssets.savings,
          fallbackIcon: Icons.beach_access_rounded,
          width: 36,
          height: 36,
        ),
      ]),
      const SizedBox(height: AppSpace.compact - 2),
      Semantics(
        label: '${(s.fraction * 100).round()}% of the way there',
        child: TogetherProgressBar(value: s.fraction),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: Text(
            s.fraction >= 1
                ? 'Reached!'
                : '${money(s.goal.remainingGiven(s.balances), currency)} to go',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TogetherStyle.listMeta(),
          ),
        ),
        Text('${(s.fraction * 100).round()}%',
            style:
                TogetherStyle.listMeta().copyWith(color: TogetherStyle.link)),
      ]),
      const Spacer(),
      const SizedBox(height: AppSpace.compact - 2),
      const _Chip('Small steps, bigger experiences. ♡'),
    ];
  }

  List<Widget> _empty(VoidCallback open) => [
        Row(children: [
          const TogetherArt(
            TogetherAssets.savingsEmpty,
            fallbackIcon: Icons.savings_rounded,
            width: 44,
            height: 44,
          ),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text('Start a goal you’ll reach together.',
                style: TogetherStyle.tagline()),
          ),
        ]),
        const Spacer(),
        const SizedBox(height: AppSpace.compact - 2),
        TogetherPill(
          label: 'Start a goal',
          style: TogetherPillStyle.soft,
          small: true,
          onTap: open,
        ),
      ];
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: TogetherStyle.chipFill,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        // The icon rides inside the first line rather than holding a
        // column of its own: in a half card at 360pt a column that wide
        // left "experiences." no room and broke it mid-word.
        child: Text.rich(
          TextSpan(children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Icon(Icons.draw_rounded,
                    size: 14, color: TogetherStyle.chipInk),
              ),
            ),
            TextSpan(text: text),
          ]),
          style: TogetherStyle.chipLabel(),
        ),
      );
}

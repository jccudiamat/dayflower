import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../../us/domain/couple_dates.dart';

/// Uses the same real start date as Events. Manual events remain owned by
/// that screen; do not duplicate its temporary seed data on Home.
class GiftOccasionCard extends ConsumerWidget {
  const GiftOccasionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = ref.watch(currentPairProvider).valueOrNull?.togetherSince;
    final now = DateTime.now();
    final anniversary = start == null ? null : nextAnniversary(start, now);
    final monthsary = start == null ? null : nextMonthsary(start, now);
    final isAnniversary = anniversary != null && anniversary == monthsary;
    final occasion = isAnniversary ? 'Anniversary' : 'Monthsary';

    return Container(
      padding: AppSpace.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(CupertinoIcons.gift,
                color: AppColors.secondary, size: 20),
            const SizedBox(width: AppSpace.xs),
            Text(
                monthsary == null
                    ? 'A LITTLE THOUGHTFULNESS'
                    : 'YOUR NEXT MILESTONE',
                style: AppText.label()),
          ]),
          const SizedBox(height: AppSpace.xs),
          Text(
              monthsary == null
                  ? 'For someone you love'
                  : 'Your ${occasion.toLowerCase()}',
              style: AppText.subtitle()),
          const SizedBox(height: AppSpace.xxs),
          Text(
              monthsary == null
                  ? 'Gift ideas for your partner, family & friends.'
                  : '${DateFormat('MMMM d').format(monthsary)} · A little something to mark the day.',
              style: AppText.caption()),
          const SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.xs,
            children: [
              TextButton.icon(
                onPressed: () => context.push(Uri(
                  path: Routes.gifts,
                  queryParameters:
                      monthsary == null ? null : {'occasion': occasion},
                ).toString()),
                icon: const Icon(CupertinoIcons.gift, size: 17),
                label: const Text('Gift ideas'),
              ),
              TextButton(
                onPressed: () => context.push(Routes.events),
                child: const Text('View events'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

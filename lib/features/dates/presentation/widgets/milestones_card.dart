import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../us/domain/couple_dates.dart';

/// What the start date implies, without anybody entering it twice.
class MilestonesCard extends StatelessWidget {
  const MilestonesCard({super.key, required this.start});
  final DateTime start;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthsary = nextMonthsary(start, now);
    final anniversary = nextAnniversary(start, now);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COMING UP', style: AppText.label()),
          const SizedBox(height: AppSpace.xs),
          _MilestoneRow(
            emoji: '🌷',
            title: '${monthsBetween(start, monthsary)} month monthsary',
            date: monthsary,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Divider(height: 1, color: AppColors.border),
          ),
          _MilestoneRow(
            emoji: '💞',
            title: '${anniversaryNumber(start, anniversary)} year anniversary',
            date: anniversary,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Both are worked out from your start date — they appear on '
            'Events on their own.',
            style: AppText.caption(),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.emoji,
    required this.title,
    required this.date,
  });

  final String emoji;
  final String title;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final days = daysBetween(DateTime.now(), date);
    final away = days == 0
        ? 'Today'
        : days == 1
            ? 'Tomorrow'
            : 'in $days days';

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.subtitle()),
              Text(DateFormat('EEEE d MMMM').format(date),
                  style: AppText.caption()),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.blush,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            away,
            style: AppText.label(AppColors.brandDark),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

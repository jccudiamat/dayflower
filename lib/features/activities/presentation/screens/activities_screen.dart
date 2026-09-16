import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../../core/widgets/feature_cards.dart';
import '../../../finance/data/finance_repository.dart';
import '../../../reminders/data/reminder_repository.dart';

/// Existing shared tools, grouped under Together.
class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueReminders = ref.watch(dueReminderCountProvider);
    final openReminders = ref.watch(myOpenRemindersProvider).length;
    final accounts = ref.watch(financeAccountsProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
              child: FeatureScreenHeader(
                title: 'Together',
                subtitle: 'Plan, do and look forward together',
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.sm, 0, AppSpace.sm, AppSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FeatureRow(
                      emoji: '📅', color: AppColors.brand, title: 'Events',
                      blurb: 'Your dates, countdowns and milestones',
                      onTap: () => context.push(Routes.events)),
                    const SizedBox(height: AppSpace.sm),
                    FeatureRow(
                      emoji: '⏰',
                      color: AppColors.brand,
                      title: 'Reminders',
                      blurb: _reminderBlurb(openReminders),
                      badge: dueReminders > 0 ? '$dueReminders due' : null,
                      onTap: () => context.push(Routes.reminders),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    FeatureRow(
                      emoji: '💰',
                      color: AppColors.sage,
                      title: 'Finances',
                      blurb: accounts.isEmpty
                          ? 'Income, expenses, savings, investments'
                          : '${accounts.length} account'
                              '${accounts.length == 1 ? '' : 's'} tracked',
                      onTap: () => context.push(Routes.finance),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    FeatureRow(
                      emoji: '🎁', color: AppColors.brand, title: 'Gifts',
                      blurb: 'Gift ideas and your saved favorites',
                      onTap: () => context.push(Routes.gifts)),
                    const SizedBox(height: AppSpace.xs),
                    FeatureRow(
                      emoji: '🗺️', color: AppColors.sage, title: 'Travel map',
                      blurb: 'Places you have been and want to go',
                      onTap: () => context.push(Routes.travel)),
                    const SizedBox(height: AppSpace.md),
                    Text('COMING SOON', style: AppText.label()),
                    const SizedBox(height: AppSpace.xs),
                    LayoutBuilder(builder: (context, box) {
                      const gap = AppSpace.xs;
                      final columns = MediaQuery.textScalerOf(context).scale(14) > 18 ||
                          box.maxWidth < 280 ? 1 : 2;
                      final w = (box.maxWidth - gap * (columns - 1)) / columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: _soon
                            .map((a) => SizedBox(
                                  width: w,
                                  child: _SoonTile(
                                    activity: a,
                                    onTap: () => _comingSoon(context, a.title),
                                  ),
                                ))
                            .toList(),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  static String _reminderBlurb(int open) => open == 0
      ? 'Nudge them, or ask to be nudged'
      : '$open waiting on you';

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is coming soon.')),
    );
  }
}

// ── The hero ────────────────────────────────────────

// ── The ones that don't ─────────────────────────────

class _Activity {
  const _Activity({
    required this.emoji,
    required this.title,
    required this.blurb,
    required this.color,
  });
  final String emoji, title, blurb;
  final Color color;
}

/// Goals used to sit here. It is built now — see [Routes.chapters] — so it
/// moved up rather than being duplicated as a SOON tile.
const _soon = <_Activity>[
  _Activity(
      emoji: '💪',
      title: 'Fitness',
      blurb: 'Move more, together',
      color: AppColors.sage),
  _Activity(
      emoji: '🎲',
      title: 'Async games',
      blurb: 'Take your turn whenever',
      color: AppColors.secondary),
  _Activity(
      emoji: '🎧',
      title: 'Music',
      blurb: 'A playlist you both build',
      color: AppColors.brand),
];

class _SoonTile extends StatelessWidget {
  const _SoonTile({required this.activity, required this.onTap});
  final _Activity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.sm),
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
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activity.color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child:
                      Text(activity.emoji, style: const TextStyle(fontSize: 18)),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('SOON', style: AppText.label()),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Text(activity.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(AppColors.ink)
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(activity.blurb,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption()),
          ],
        ),
      ),
    );
  }
}

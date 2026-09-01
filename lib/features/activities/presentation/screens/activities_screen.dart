import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../chapters/data/chapter_repository.dart';
import '../../../finance/data/finance_repository.dart';
import '../../../reminders/data/reminder_repository.dart';

/// The Activities tab is a hub, not a single feature. Tapping the tab used
/// to drop you straight into the photo booth, which made the booth *be* the
/// tab — there was nowhere to add anything else. This screen is the menu;
/// the booth is now one entry in it, at [Routes.booth].
///
/// The four built entries carry live status (reminders due, this month's
/// goal progress) so the hub is worth opening rather than just passing
/// through. The rest are declared as SOON tiles rather than hidden, so the
/// shape of the tab is visible and nothing pretends to work — same rule as
/// the login screen's OAuth buttons.
class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueReminders = ref.watch(dueReminderCountProvider);
    final openReminders = ref.watch(myOpenRemindersProvider).length;
    final accounts = ref.watch(financeAccountsProvider).valueOrNull ?? const [];
    final goals = ref.watch(currentMonthGoalsProvider);
    final unwritten = ref.watch(unwrittenChapterProvider);

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
                title: 'Activities',
                subtitle: 'Things to do together, apart',
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
                    _BoothCard(onTap: () => context.go(Routes.booth)),
                    const SizedBox(height: AppSpace.sm),
                    _FeatureRow(
                      emoji: '⏰',
                      color: AppColors.brand,
                      title: 'Reminders',
                      blurb: _reminderBlurb(openReminders),
                      badge: dueReminders > 0 ? '$dueReminders due' : null,
                      onTap: () => context.go(Routes.reminders),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    _FeatureRow(
                      emoji: '💰',
                      color: AppColors.sage,
                      title: 'Finances',
                      blurb: accounts.isEmpty
                          ? 'Income, expenses, savings, investments'
                          : '${accounts.length} account'
                              '${accounts.length == 1 ? '' : 's'} tracked',
                      onTap: () => context.go(Routes.finance),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    _FeatureRow(
                      emoji: '📖',
                      color: AppColors.secondary,
                      title: 'Chapters',
                      blurb: _chapterBlurb(goals, unwritten),
                      badge: unwritten == null ? null : 'Review due',
                      onTap: () => context.go(Routes.chapters),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    // Settings used to be reachable only through the avatar
                    // on Home, and the new header has no avatar. Without a
                    // second door, sign-out, timezone, disconnect and
                    // check-for-updates would all be stranded.
                    _FeatureRow(
                      emoji: '⚙️',
                      color: AppColors.muted,
                      title: 'Settings',
                      blurb: 'Profile, timezone, widget, sign out',
                      onTap: () => context.go(Routes.settings),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Text('COMING SOON', style: AppText.label()),
                    const SizedBox(height: AppSpace.xs),
                    LayoutBuilder(builder: (context, box) {
                      const gap = AppSpace.xs;
                      final w = (box.maxWidth - gap) / 2;
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

  static String _chapterBlurb(
    List<MonthlyGoal> goals,
    ChapterKey? unwritten,
  ) {
    if (unwritten != null) {
      return '${DateFormat('MMMM').format(unwritten.firstDay)} is waiting to '
          'be written';
    }
    if (goals.isEmpty) return 'Twelve months, twelve stories';
    final done = goals.where((g) => g.isDone).length;
    return '$done of ${goals.length} goals this month';
  }

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is coming soon.')),
    );
  }
}

// ── The hero ────────────────────────────────────────

class _BoothCard extends StatelessWidget {
  const _BoothCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .15)),
                  ),
                  child: const Text('📸', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Booth & Strip',
                          style: AppText.title(AppColors.onDark)),
                      const SizedBox(height: 2),
                      Text('Photo strips, ten templates',
                          style: AppText.caption(AppColors.onDarkMuted)),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.chevron_forward,
                    size: 15, color: AppColors.onDarkMuted),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text('Pose apart, print together. 🌷',
                style: AppText.note(AppColors.onDarkMuted)),
          ],
        ),
      ),
    );
  }
}

// ── The ones that work ──────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.emoji,
    required this.color,
    required this.title,
    required this.blurb,
    this.badge,
    required this.onTap,
  });

  final String emoji;
  final Color color;
  final String title;
  final String blurb;

  /// A short status pill — only rendered when there is something the user
  /// should act on, so an empty hub stays quiet.
  final String? badge;

  final VoidCallback onTap;

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
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.subtitle()),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: AppSpace.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.blush,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(badge!,
                                style: AppText.label(AppColors.brandDark)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(blurb,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption()),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              const Icon(CupertinoIcons.chevron_forward,
                  size: 14, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

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
      emoji: '🎲',
      title: 'Async games',
      blurb: 'Take your turn whenever',
      color: AppColors.secondary),
  _Activity(
      emoji: '🗺️',
      title: 'Travel map',
      blurb: 'Where you\'ve been, where next',
      color: AppColors.sage),
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

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/story_components.dart';
import '../../../chapters/data/chapter_repository.dart';
import '../../../finance/data/finance_repository.dart';
import '../../../reminders/data/reminder_repository.dart';

class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueReminderCountProvider);
    final accounts = ref.watch(financeAccountsProvider).valueOrNull ?? [];
    final goals = ref.watch(currentMonthGoalsProvider);
    Widget row(IconData icon, String title, String subtitle, String? route) =>
        Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xs),
            child: UtilityRow(
                icon: icon,
                title: title,
                subtitle: subtitle,
                onTap: route == null ? null : () => context.push(route)));
    return StoryScaffold(
        title: 'Together',
        subtitle: 'Plan, do and look forward together.',
        children: [
          const StorySection('Plan'),
          row(CupertinoIcons.calendar, 'Events', 'Your dates and milestones',
              Routes.events),
          row(
              CupertinoIcons.alarm,
              'Reminders',
              due > 0 ? '$due waiting on you' : 'Nudge each other',
              Routes.reminders),
          row(CupertinoIcons.gift, 'Gifts',
              'Plan surprises for the moments ahead', Routes.gifts),
          row(
              CupertinoIcons.airplane,
              'Trips',
              'Save your next adventure in Our Map',
              '${Routes.ourMap}?tab=next'),
          const StorySection('Life'),
          row(
              CupertinoIcons.money_dollar_circle,
              'Finances',
              accounts.isEmpty
                  ? 'When you’re ready to plan money together'
                  : '${accounts.length} shared accounts',
              Routes.finance),
          row(CupertinoIcons.heart, 'Fitness', 'Move more, together', null),
          row(
              CupertinoIcons.checkmark_circle,
              'Shared Goals',
              '${goals.where((g) => g.isDone).length} of ${goals.length} goals this month',
              Routes.goals),
          const StorySection('Play'),
          row(CupertinoIcons.game_controller, 'Async Games',
              'Take your turn anytime', null),
          row(CupertinoIcons.music_note, 'Music', 'Listen together', null),
          row(CupertinoIcons.play_rectangle, 'Watch Together',
              'Make time for a shared screen', null),
          const SizedBox(height: AppSpace.sm),
          row(
              CupertinoIcons.map,
              'Our Map',
              'Where you are, where you’ve been and where you’re going.',
              Routes.ourMap),
        ]);
  }
}

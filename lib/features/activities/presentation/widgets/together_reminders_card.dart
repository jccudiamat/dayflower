import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../home/domain/home_moments.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../reminders/data/reminder_repository.dart';
import '../../../us/domain/couple_dates.dart';
import 'together_card.dart';

/// Reminders: the next few nudges either of you has set, whoever they are
/// for, in the slot the mockup gave Shared Goals.
///
/// ⚠️ Shared goals are not here on purpose. They live in each month's
/// chapter, and a second copy of them on this tab would be a second place
/// to keep in step; Reminders had no other way in once the old list went.
///
/// The whole pair's open reminders, not just mine — the same set the
/// scheduler rings for — because "remind her to take her vitamins" is the
/// feature, and hiding the ones I set for her would hide half of it.
class TogetherRemindersCard extends ConsumerWidget {
  const TogetherRemindersCard({super.key});

  static const _shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(pairOpenRemindersProvider);
    final due = ref.watch(dueReminderCountProvider);
    final loading = ref.watch(remindersProvider).isLoading;
    final now = ref.watch(homeClockProvider).valueOrNull ?? DateTime.now();
    final me = ref.watch(currentUserIdProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final partnerName = partner?.petName ?? partner?.displayName ?? 'them';
    void openAll() => context.push(Routes.reminders);

    return TogetherCard(
      tint: TogetherTint.lavender,
      padding: const EdgeInsets.all(TogetherStyle.padTight),
      onTap: openAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TogetherCardHeader(
            icon: CupertinoIcons.bell_fill,
            iconColor: TogetherStyle.iconReminders,
            title: 'Reminders',
            subtitle: loading
                ? null
                : due > 0
                    ? '$due waiting on you'
                    : open.isEmpty
                        ? 'Nothing pending'
                        : '${open.length} open',
            trailing: TogetherSeeAll(onTap: openAll),
          ),
          const SizedBox(height: AppSpace.compact - 2),
          if (loading)
            const TogetherSkeleton(lines: 3)
          else if (open.isEmpty)
            Text('Set a nudge for each other: a call, a pill, a date.',
                style: TogetherStyle.tagline())
          else ...[
            for (final reminder in open.take(_shown))
              _ReminderLine(
                reminder: reminder,
                now: now,
                // Only said when it is for them: "for you" is the usual
                // case, and it cost the time its ending in a half card.
                forWhom: reminder.isFor(me) ? null : partnerName,
              ),
            if (open.length > _shown)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+${open.length - _shown} more',
                    style: TogetherStyle.listMeta()),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReminderLine extends StatelessWidget {
  const _ReminderLine({
    required this.reminder,
    required this.now,
    required this.forWhom,
  });

  final Reminder reminder;
  final DateTime now;

  /// Whose it is, when it is not yours.
  final String? forWhom;

  @override
  Widget build(BuildContext context) {
    final overdue = reminder.remindAt.isBefore(now);
    final meta = TogetherStyle.listMeta();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TogetherStyle.rowBubble,
            shape: BoxShape.circle,
          ),
          child: Text(reminder.emoji,
              textScaler: TextScaler.noScaling, style: TogetherStyle.emoji()),
        ),
        const SizedBox(width: AppSpace.compact - 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reminder.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TogetherStyle.listTitle()
                      .copyWith(fontWeight: FontWeight.w600)),
              Text.rich(
                TextSpan(children: [
                  if (forWhom != null) TextSpan(text: '$forWhom · '),
                  TextSpan(
                    text: whenLabel(reminder.remindAt, now),
                    style: overdue
                        ? meta.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600)
                        : null,
                  ),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: meta,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// "Overdue", "Today, 8 PM", "Tomorrow, 7:30 AM", "Thu, 9 AM", "3 Oct".
///
/// Calendar days, not 24-hour blocks, so 11pm tonight to 1am is "Tomorrow".
/// On the hour, the minutes go: a half card has room for "Today, 9 PM"
/// and not for "Today, 9:00 PM".
String whenLabel(DateTime at, DateTime now) {
  if (at.isBefore(now)) return 'Overdue';
  final days = daysBetween(now, at);
  final time = (at.minute == 0 ? DateFormat.j() : DateFormat.jm()).format(at);
  if (days == 0) return 'Today, $time';
  if (days == 1) return 'Tomorrow, $time';
  if (days < 7) return '${DateFormat.E().format(at)}, $time';
  return DateFormat('d MMM').format(at);
}

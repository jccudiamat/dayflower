import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/ios_back_button.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/reminder_repository.dart';

/// Reminders you set for each other. Sub-route of the Activities hub.
///
/// The list is one timeline for the couple rather than two — a reminder
/// you set for your partner has to be visible to you, or you can't tell
/// whether you already set it.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final remindersAsync = ref.watch(remindersProvider);

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IosBackButton(onTap: () => context.go(Routes.activities)),
                  const SizedBox(width: AppSpace.xs),
                  const Expanded(
                    child: FeatureScreenHeader(
                      title: 'Reminders',
                      subtitle: 'Nudge them, or ask to be nudged',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: AppSegmented<bool>(
                options: const {false: 'Upcoming', true: 'Done'},
                value: _showDone,
                onChanged: (v) => setState(() => _showDone = v),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Expanded(
              child: remindersAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, _) => _ErrorState(message: '$e'),
                data: (all) {
                  final list = all.where((r) => r.isDone == _showDone).toList();
                  // Done reminders read best newest-first: the last thing
                  // you ticked off is the one you're looking for.
                  if (_showDone) {
                    list.sort((a, b) => b.doneAt!.compareTo(a.doneAt!));
                  }
                  if (list.isEmpty) {
                    return _EmptyState(
                      done: _showDone,
                      onAdd: () => _openEditor(partner: partner),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.sm, 0, AppSpace.sm, AppSpace.xl + AppSpace.md),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpace.xs),
                    itemBuilder: (_, i) {
                      final reminder = list[i];
                      return _ReminderCard(
                        reminder: reminder,
                        isMine: reminder.isFor(userId),
                        partnerName: partner?.displayName ?? 'them',
                        onToggle: () => _toggle(reminder),
                        onTap: () => _openEditor(
                          partner: partner,
                          existing: reminder,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(partner: partner),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        child: const Icon(CupertinoIcons.add),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  Future<void> _toggle(Reminder reminder) async {
    final repo = ref.read(reminderRepositoryProvider);
    try {
      if (reminder.isDone) {
        await repo.reopen(reminder.id);
      } else {
        await repo.markDone(reminder);
        if (mounted && reminder.repeats) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Done — back again ${reminder.repeat.label
                  .toLowerCase()}.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  Future<void> _openEditor({
    UserProfile? partner,
    Reminder? existing,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    final pair = ref.read(currentPairProvider).valueOrNull;
    if (userId == null || pair == null || !pair.isLinked) return;
    final partnerId = pair.partnerIdFor(userId);
    if (partnerId == null) return;

    final result = await showModalBottomSheet<_EditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReminderEditor(
        existing: existing,
        myId: userId,
        partnerId: partnerId,
        partnerName: partner?.displayName ?? 'Partner',
      ),
    );
    if (result == null || !mounted) return;

    final repo = ref.read(reminderRepositoryProvider);
    try {
      switch (result) {
        case _DeleteReminder():
          final ok = await showConfirmDialog(
            context,
            title: 'Delete reminder?',
            message: 'It disappears for both of you.',
            confirmLabel: 'Delete',
          );
          if (ok) await repo.delete(existing!.id);
        case _SaveReminder(:final draft):
          if (existing == null) {
            await repo.create(
              pairId: pair.id,
              createdBy: userId,
              forUser: draft.forUser,
              title: draft.title,
              note: draft.note,
              emoji: draft.emoji,
              remindAt: draft.remindAt,
              repeat: draft.repeat,
              alarm: draft.alarm,
            );
          } else {
            await repo.update(
              existing.id,
              forUser: draft.forUser,
              title: draft.title,
              note: draft.note,
              emoji: draft.emoji,
              remindAt: draft.remindAt,
              repeat: draft.repeat,
              alarm: draft.alarm,
            );
          }
      }
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not save that: $error')),
  );
}

// ── The list ────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.isMine,
    required this.partnerName,
    required this.onToggle,
    required this.onTap,
  });

  final Reminder reminder;
  final bool isMine;
  final String partnerName;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = reminder.isOverdue;
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
            border: Border.all(
              color: overdue ? AppColors.brandLight : AppColors.border,
            ),
            boxShadow: AppElevation.card,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TickCircle(done: reminder.isDone, onTap: onToggle),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(reminder.emoji,
                            style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reminder.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(AppColors.ink).copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: reminder.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: reminder.isDone
                                  ? AppColors.muted
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (reminder.note != null &&
                        reminder.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(reminder.note!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption()),
                    ],
                    const SizedBox(height: AppSpace.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Chip(
                          label: _friendlyWhen(reminder.remindAt),
                          color: overdue ? AppColors.danger : AppColors.body,
                          icon: CupertinoIcons.clock,
                        ),
                        if (reminder.repeats)
                          _Chip(
                            label: reminder.repeat.label,
                            color: AppColors.secondary,
                            icon: CupertinoIcons.repeat,
                          ),
                        _Chip(
                          label: isMine ? 'For you' : 'For $partnerName',
                          color: isMine ? AppColors.brand : AppColors.muted,
                          icon: CupertinoIcons.person,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TickCircle extends StatelessWidget {
  const _TickCircle({required this.done, required this.onTap});
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 2, right: 2),
        child: AnimatedContainer(
          duration: AppMotion.micro,
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: done ? AppGradients.cta : null,
            border: done
                ? null
                : Border.all(color: AppColors.blushMid, width: 1.5),
          ),
          child: done
              ? const Icon(Icons.done_rounded, size: 15, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label, style: AppText.label(color)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.done, required this.onAdd});
  final bool done;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(done ? '🧺' : '⏰', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: AppSpace.sm),
            Text(
              done ? 'Nothing ticked off yet' : 'No reminders yet',
              style: AppText.title(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              done
                  ? 'Finished reminders collect here.'
                  : 'Take your meds. Call your mum. Sleep.\nSet one for them, or for yourself.',
              style: AppText.caption(),
              textAlign: TextAlign.center,
            ),
            if (!done) ...[
              const SizedBox(height: AppSpace.md),
              SizedBox(
                width: 200,
                child: GradientButton(label: 'Set a reminder', onPressed: onAdd),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reminders could not load', style: AppText.title()),
            const SizedBox(height: AppSpace.xxs),
            Text(message, style: AppText.caption(), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── The editor ──────────────────────────────────────

/// What the sheet hands back. A sealed pair rather than a nullable tuple so
/// "delete" can never be mistaken for "saved with empty fields".
sealed class _EditorResult {
  const _EditorResult();
}

class _DeleteReminder extends _EditorResult {
  const _DeleteReminder();
}

class _SaveReminder extends _EditorResult {
  const _SaveReminder(this.draft);
  final _Draft draft;
}

class _Draft {
  const _Draft({
    required this.forUser,
    required this.title,
    required this.note,
    required this.emoji,
    required this.remindAt,
    required this.repeat,
    required this.alarm,
  });
  final String forUser;
  final String title;
  final String? note;
  final String emoji;
  final DateTime remindAt;
  final ReminderRepeat repeat;
  final bool alarm;
}

class _ReminderEditor extends StatefulWidget {
  const _ReminderEditor({
    required this.existing,
    required this.myId,
    required this.partnerId,
    required this.partnerName,
  });

  final Reminder? existing;
  final String myId;
  final String partnerId;
  final String partnerName;

  @override
  State<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<_ReminderEditor> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _emoji;
  late String _forUser;
  late DateTime _when;
  late ReminderRepeat _repeat;
  late bool _alarm;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
    _emoji = TextEditingController(text: existing?.emoji ?? '⏰');
    // A new reminder defaults to the partner — setting one for *them* is
    // what this screen is for; reminding yourself is the special case.
    _forUser = existing?.forUser ?? widget.partnerId;
    _when = existing?.remindAt ?? _defaultWhen();
    _repeat = existing?.repeat ?? ReminderRepeat.none;
    // Defaults to ringing. "Remind me" almost always means "make sure I
    // notice", and a reminder slept through did nothing — Notify is the
    // deliberate opt-out for the ones that don't deserve a fire drill.
    _alarm = existing?.alarm ?? true;
  }

  /// The next round half-hour, at least ten minutes out — near enough to
  /// be useful, far enough that saving instantly doesn't fire instantly.
  static DateTime _defaultWhen() {
    final now = DateTime.now().add(const Duration(minutes: 10));
    final minute = now.minute < 30 ? 30 : 60;
    return DateTime(now.year, now.month, now.day, now.hour).add(
      Duration(minutes: minute),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    setState(() => _when =
        DateTime(picked.year, picked.month, picked.day, _when.hour, _when.minute));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (picked == null) return;
    setState(() => _when = DateTime(
        _when.year, _when.month, _when.day, picked.hour, picked.minute));
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the reminder a name first.')),
      );
      return;
    }
    final emoji = _emoji.text.trim();
    Navigator.pop(
      context,
      _SaveReminder(_Draft(
        forUser: _forUser,
        title: title,
        note: _note.text,
        emoji: emoji.isEmpty ? '⏰' : emoji,
        remindAt: _when,
        repeat: _repeat,
        alarm: _alarm,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return AppBottomSheet(
      title: isNew ? 'Set a reminder' : 'Edit reminder',
      subtitle: isNew
          ? 'It rings on their phone, not yours'
          : 'Changing the time puts it back on the list',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppFieldLabel('Who is it for'),
          AppSegmented<String>(
            options: {
              widget.partnerId: widget.partnerName,
              widget.myId: 'Me',
            },
            value: _forUser,
            onChanged: (v) => setState(() => _forUser = v),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppFieldLabel('Icon'),
                    AppSheetField(
                      controller: _emoji,
                      maxLength: 2,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppFieldLabel('Reminder'),
                    AppSheetField(
                      controller: _title,
                      hint: 'Take your vitamins',
                      autofocus: isNew,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('When'),
          Row(
            children: [
              Expanded(
                child: _PickerField(
                  icon: CupertinoIcons.calendar,
                  label: DateFormat('EEE d MMM').format(_when),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: _PickerField(
                  icon: CupertinoIcons.clock,
                  label: DateFormat('h:mm a').format(_when),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.xxs,
            children: [
              _QuickTime(
                label: 'In an hour',
                onTap: () => setState(
                    () => _when = DateTime.now().add(const Duration(hours: 1))),
              ),
              _QuickTime(
                label: 'Tonight 8pm',
                onTap: () => setState(() {
                  final now = DateTime.now();
                  _when = DateTime(now.year, now.month, now.day, 20);
                }),
              ),
              _QuickTime(
                label: 'Tomorrow 9am',
                onTap: () => setState(() {
                  final t = DateTime.now().add(const Duration(days: 1));
                  _when = DateTime(t.year, t.month, t.day, 9);
                }),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('How it arrives'),
          AppSegmented<bool>(
            options: const {true: '⏰  Ring', false: '🔔  Notify'},
            value: _alarm,
            onChanged: (v) => setState(() => _alarm = v),
          ),
          const SizedBox(height: AppSpace.xxs),
          Text(
            _alarm
                ? 'Rings at alarm volume and takes over their screen, even on '
                    'silent. Snooze or Done to stop it.'
                : 'An ordinary notification. Quiet, and easy to miss.',
            style: AppText.caption(),
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('Repeat'),
          AppSegmented<ReminderRepeat>(
            options: {
              for (final r in ReminderRepeat.values) r: r.label,
            },
            value: _repeat,
            onChanged: (v) => setState(() => _repeat = v),
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('Note (optional)'),
          AppSheetField(
            controller: _note,
            hint: 'The blue ones, after breakfast',
            maxLines: 3,
          ),
          const SizedBox(height: AppSpace.md),
          GradientButton(
            label: isNew ? 'Set reminder' : 'Save changes',
            onPressed: _save,
          ),
          if (!isNew) ...[
            const SizedBox(height: AppSpace.xs),
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.pop(context, const _DeleteReminder()),
                child: Text('Delete reminder',
                    style: AppText.caption(AppColors.danger)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.brand),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(AppColors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTime extends StatelessWidget {
  const _QuickTime({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.blush,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label, style: AppText.label(AppColors.brandDark)),
      ),
    );
  }
}

/// "Today 8:00 PM" / "Tomorrow 9:00 AM" / "Fri 12 Sep, 9:00 AM".
///
/// Shared with nothing else on purpose — the Messages inbox has its own
/// ladder tuned for a chat, where "yesterday" matters and next month does
/// not. Here it's the reverse.
String _friendlyWhen(DateTime when) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  final diff = day.difference(today).inDays;
  final time = DateFormat('h:mm a').format(when);
  if (diff == 0) return 'Today $time';
  if (diff == 1) return 'Tomorrow $time';
  if (diff == -1) return 'Yesterday $time';
  if (diff > 1 && diff < 7) return '${DateFormat('EEEE').format(when)} $time';
  if (when.year == now.year) {
    return '${DateFormat('d MMM').format(when)}, $time';
  }
  return '${DateFormat('d MMM yyyy').format(when)}, $time';
}

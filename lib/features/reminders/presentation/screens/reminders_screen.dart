import 'package:dayflower/core/widgets/app_icon.dart';
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
import '../../data/sticky_note_pinner.dart';
import '../../domain/sticky_note.dart';
import '../widgets/sticky_note_card.dart';

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
                  return _NoteWall(
                    notes: list,
                    userId: userId,
                    partnerName: partner?.displayName ?? 'them',
                    onToggle: _toggle,
                    onOpen: (r) =>
                        _openEditor(partner: partner, existing: r),
                    onMore: (r) => _showNoteActions(r, partner),
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
        child: const AppIcon(CupertinoIcons.add),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  /// Reminders nudged recently, and when — so the button can go quiet
  /// instead of firing again. In memory only: a cooldown that survived a
  /// restart would need storage, and the failure it guards against (a
  /// flurry of taps) happens in one sitting.
  final _nudgedAt = <String, DateTime>{};

  bool _isSpent(Reminder reminder) {
    final at = _nudgedAt[reminder.id];
    return at != null && DateTime.now().difference(at) < kNudgeCooldown;
  }

  Future<void> _nudge(Reminder reminder) async {
    if (_isSpent(reminder)) return;
    final myId = ref.read(currentUserIdProvider);
    if (myId == null) return;

    setState(() => _nudgedAt[reminder.id] = DateTime.now());
    try {
      await ref.read(reminderRepositoryProvider).nudge(
            reminder: reminder,
            senderId: myId,
            now: DateTime.now(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nudged — it is on their phone now.')),
        );
      }
    } catch (e) {
      // ⚠️ The cooldown is released again on failure. Leaving the button
      // spent after a nudge that never sent is the one outcome worse than
      // sending twice.
      if (mounted) {
        setState(() => _nudgedAt.remove(reminder.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send that nudge.')),
        );
      }
    }
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

  /// What a note cannot show on its face.
  ///
  /// Long-press rather than controls on the note: sticking something on a
  /// home screen and reaching into somebody else's pocket are both
  /// deliberate acts, and a wall of notes has no room to make either of them
  /// a button without becoming a list of rows again.
  Future<void> _showNoteActions(Reminder reminder, UserProfile? partner) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final name = partner?.displayName ?? 'them';
    // Nudging yourself does nothing, and nudging about something already
    // ticked off is noise — the same rule the old inline button followed.
    final canNudge = !reminder.isFor(userId) && !reminder.isDone;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _NoteActionSheet(
        reminder: reminder,
        partnerName: name,
        canNudge: canNudge,
        nudgeSpent: _isSpent(reminder),
        onNudge: () {
          Navigator.of(sheetContext).pop();
          _nudge(reminder);
        },
        onPin: () {
          Navigator.of(sheetContext).pop();
          _pin(reminder);
        },
      ),
    );
  }

  /// Sticks this one note on the home screen.
  Future<void> _pin(Reminder reminder) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final asked = await StickyNotePinner.pin(reminder);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            asked
                // The launcher owns the last step, so this cannot promise
                // the note landed — only that it was offered.
                ? 'Drag it where you want it.'
                : 'This launcher cannot pin widgets. Add it from the '
                    'widget tray instead.',
          ),
        ),
      );
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

/// The wall.
///
/// Two columns of notes, not one, because a note is roughly as tall as it is
/// wide — a full-width tilted rectangle is a card with a rotation.
///
/// ⚠️ **Masonry by alternating index, not by measured height.** Measuring
/// would need a layout pass per note and would reshuffle the wall whenever a
/// title wrapped. Alternating keeps a note in the same place from one open
/// to the next, which matters more here than perfectly level columns: people
/// remember where they stuck something.
///
/// Not lazily built. A couple has tens of reminders, not thousands, and the
/// tilt means a note can paint slightly outside its own box — which a
/// viewport-clipped lazy list would cut off at the edges.
class _NoteWall extends StatelessWidget {
  const _NoteWall({
    required this.notes,
    required this.userId,
    required this.partnerName,
    required this.onToggle,
    required this.onOpen,
    required this.onMore,
  });

  final List<Reminder> notes;

  /// Nullable, matching `Reminder.isFor` — a signed-out reader has no
  /// reminders "for you", which is a real state rather than one to assert
  /// away with a bang.
  final String? userId;
  final String partnerName;
  final void Function(Reminder) onToggle;
  final void Function(Reminder) onOpen;
  final void Function(Reminder) onMore;

  @override
  Widget build(BuildContext context) {
    final left = <Reminder>[];
    final right = <Reminder>[];
    for (var i = 0; i < notes.length; i++) {
      (i.isEven ? left : right).add(notes[i]);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.sm, AppSpace.xxs, AppSpace.sm, AppSpace.xl + AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _column(left)),
          const SizedBox(width: AppSpace.xs),
          Expanded(child: _column(right)),
        ],
      ),
    );
  }

  Widget _column(List<Reminder> column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final reminder in column)
          Padding(
            // Generous, because the tilt needs somewhere to go: two notes
            // leaning towards each other with 8pt between them overlap.
            padding: const EdgeInsets.only(bottom: 14),
            child: StickyNoteCard(
              reminder: reminder,
              isMine: reminder.isFor(userId),
              partnerName: partnerName,
              onToggle: () => onToggle(reminder),
              onTap: () => onOpen(reminder),
              onMore: () => onMore(reminder),
            ),
          ),
      ],
    );
  }
}

/// What long-pressing a note offers.
class _NoteActionSheet extends StatelessWidget {
  const _NoteActionSheet({
    required this.reminder,
    required this.partnerName,
    required this.canNudge,
    required this.nudgeSpent,
    required this.onNudge,
    required this.onPin,
  });

  final Reminder reminder;
  final String partnerName;
  final bool canNudge;
  final bool nudgeSpent;
  final VoidCallback onNudge;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    final paper = stickyNotePaperFor(reminder.id);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpace.sm),
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // The note's own paper, so the sheet is visibly about *this*
                // note and not about reminders in general.
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: paper.fill,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: paper.edge),
                  ),
                  alignment: Alignment.center,
                  child: Text(reminder.emoji,
                      style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: Text(
                    reminder.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.subtitle().copyWith(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            if (StickyNotePinner.supported)
              _SheetAction(
                icon: CupertinoIcons.pin_fill,
                label: 'Stick on home screen',
                detail: 'Keeps this note where you will see it.',
                onTap: onPin,
              ),
            if (canNudge) ...[
              const SizedBox(height: AppSpace.xs),
              _NudgeButton(
                name: partnerName,
                spent: nudgeSpent,
                onTap: onNudge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xs + 2),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.secondary),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: AppText.body(AppColors.ink)
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text(detail, style: AppText.caption()),
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

/// "Remind Sheena now" — the manual nudge.
///
/// Sends the reminder to their phone this second, rather than waiting for
/// the next beat of the countdown. Deliberately a full-width, labelled
/// control rather than a small icon: it reaches into somebody else's pocket,
/// so it should be hard to press by accident and obvious once pressed.
class _NudgeButton extends StatelessWidget {
  const _NudgeButton({
    required this.name,
    required this.spent,
    required this.onTap,
  });

  final String name;
  final bool spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: spent ? AppColors.surfaceSubtle : AppColors.blush,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: spent ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(
                  spent
                      ? CupertinoIcons.checkmark_alt
                      : CupertinoIcons.bell_fill,
                  size: 15,
                  color: spent ? AppColors.muted : AppColors.brand,
                ),
                const SizedBox(width: 6),
                Text(
                  spent ? 'Nudged' : 'Remind $name now',
                  style: AppText.caption(
                    spent ? AppColors.muted : AppColors.brand,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
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
            AppIcon(icon, size: 15, color: AppColors.brand),
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


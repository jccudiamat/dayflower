import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_error_notice.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/ios_back_button.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/chapter_repository.dart';

/// One month, in full: the goals you set at the start, the moments that
/// happened along the way, and the review you write at the end.
///
/// The three sections are the chapter's three sittings, in the order they
/// happen, and the screen leans on whichever one is due — goals while the
/// month is running, the review once it's over.
class ChapterDetailScreen extends ConsumerWidget {
  const ChapterDetailScreen({
    super.key,
    required this.year,
    required this.month,
  });

  final int year;
  final int month;

  ChapterKey get _key => ChapterKey(year, month);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final partnerName = partner?.displayName ?? 'Them';

    final goalsAsync = ref.watch(monthlyGoalsProvider);
    final momentsAsync = ref.watch(chapterMomentsProvider);
    final chaptersAsync = ref.watch(monthlyChaptersProvider);
    final goals = (goalsAsync.valueOrNull ?? const <MonthlyGoal>[])
        .where((g) => g.key == _key)
        .toList();
    final moments = (momentsAsync.valueOrNull ?? const <ChapterMoment>[])
        .where((m) => m.key == _key)
        .toList();
    final chapter = (chaptersAsync.valueOrNull ?? const <MonthlyChapter>[])
        .firstWhereOrNull((c) => c.key == _key);
    // Without this an unreachable table renders as a month you simply
    // didn't write anything in — see [AppErrorNotice].
    final loadError =
        goalsAsync.error ?? momentsAsync.error ?? chaptersAsync.error;

    final done = goals.where((g) => g.isDone).length;

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
                  IosBackButton(onTap: () => context.go(Routes.chapters)),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('MMMM yyyy').format(_key.firstDay),
                            style: AppText.hero()),
                        const SizedBox(height: AppSpace.xxs),
                        Text(
                          chapter?.title?.trim().isNotEmpty == true
                              ? chapter!.title!
                              : _statusLine(_key, goals.length, done),
                          style: chapter?.title?.trim().isNotEmpty == true
                              ? AppText.note(AppColors.body)
                              : AppText.body(AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.sm, 0, AppSpace.sm, AppSpace.md),
                children: [
                  if (loadError != null)
                    AppErrorNotice(
                      message: 'This chapter could not load',
                      detail: loadError,
                    ),
                  // ── Goals ──
                  _SectionHeader(
                    label: 'Goals for the month',
                    onAdd: () => _openGoalSheet(
                      context,
                      ref,
                      partnerName: partnerName,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  if (goals.isEmpty)
                    const _EmptyHint(
                      emoji: '🎯',
                      title: 'No goals set',
                      body: 'List what you each want out of this month, and '
                          'what you want out of it together.',
                    )
                  else ...[
                    _GoalProgress(done: done, total: goals.length),
                    const SizedBox(height: AppSpace.xs),
                    ...goals.map((goal) {
                      // Only the owner may write a solo goal — RLS enforces
                      // it, so the UI matches rather than offering a tap
                      // that comes back 42501.
                      final editable =
                          goal.isShared || (userId != null && goal.ownerId == userId);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.xxs),
                        child: _GoalRow(
                          goal: goal,
                          scopeLabel: _scopeLabel(goal.ownerId, userId, partnerName),
                          editable: editable,
                          onToggle: () => _guard(
                            context,
                            () => ref
                                .read(chapterRepositoryProvider)
                                .toggleGoal(goal),
                          ),
                          onTap: () => _openGoalSheet(
                            context,
                            ref,
                            partnerName: partnerName,
                            existing: goal,
                          ),
                        ),
                      );
                    }),
                  ],

                  // ── Moments ──
                  const SizedBox(height: AppSpace.md),
                  _SectionHeader(
                    label: 'What happened',
                    onAdd: () => _openMomentSheet(context, ref),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  if (moments.isEmpty)
                    const _EmptyHint(
                      emoji: '✨',
                      title: 'Nothing logged yet',
                      body: 'Add the things worth remembering as they happen '
                          '— the review writes itself later.',
                    )
                  else
                    ...moments.map((moment) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.xxs),
                          child: _MomentRow(
                            moment: moment,
                            onTap: () => _openMomentSheet(
                              context,
                              ref,
                              existing: moment,
                            ),
                          ),
                        )),

                  // ── Review ──
                  const SizedBox(height: AppSpace.md),
                  Text('THE REVIEW', style: AppText.label()),
                  const SizedBox(height: AppSpace.xs),
                  _ReviewCard(
                    chapterKey: _key,
                    chapter: chapter,
                    goalsDone: done,
                    goalsTotal: goals.length,
                    momentCount: moments.length,
                    onWrite: () => _openReviewSheet(context, ref, chapter),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  static String _statusLine(ChapterKey key, int total, int done) {
    if (key.isFuture) return 'Not started yet';
    if (key.isCurrent) {
      return total == 0 ? 'Set the goals for this month' : '$done of $total done';
    }
    return total == 0 ? 'A month with nothing written down' : '$done of $total done';
  }

  static String _scopeLabel(String? ownerId, String? userId, String partnerName) {
    if (ownerId == null) return 'Ours';
    if (ownerId == userId) return 'Mine';
    return partnerName;
  }

  /// Every write in this screen is one call that can only fail for reasons
  /// the user can't act on (offline, RLS), so they all report the same way.
  static Future<void> _guard(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save that: $e')),
        );
      }
    }
  }

  // ── Sheets ──────────────────────────────────────

  Future<void> _openGoalSheet(
    BuildContext context,
    WidgetRef ref, {
    required String partnerName,
    MonthlyGoal? existing,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    final pair = ref.read(currentPairProvider).valueOrNull;
    if (userId == null || pair == null) return;

    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalSheet(
        existing: existing,
        monthLabel: DateFormat('MMMM').format(_key.firstDay),
      ),
    );
    if (result == null || !context.mounted) return;

    final repo = ref.read(chapterRepositoryProvider);
    switch (result) {
      case _Deleted():
        final ok = await showConfirmDialog(
          context,
          title: 'Delete this goal?',
          message: "It leaves the month's list for both of you.",
          confirmLabel: 'Delete',
        );
        if (ok && context.mounted) {
          await _guard(context, () => repo.deleteGoal(existing!.id));
        }
      case _GoalSaved(:final draft):
        await _guard(
          context,
          () => repo.saveGoal(
            id: existing?.id,
            pairId: pair.id,
            // Editing never moves a goal between owners — that would
            // silently hand your partner's goal to yourself.
            ownerId: existing != null
                ? existing.ownerId
                : (draft.shared ? null : userId),
            key: _key,
            title: draft.title,
            note: draft.note,
            emoji: draft.emoji,
            userId: userId,
          ),
        );
      case _MomentSaved():
      case _ReviewSaved():
        break; // not reachable from this sheet
    }
  }

  Future<void> _openMomentSheet(
    BuildContext context,
    WidgetRef ref, {
    ChapterMoment? existing,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    final pair = ref.read(currentPairProvider).valueOrNull;
    if (userId == null || pair == null) return;

    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MomentSheet(existing: existing, chapterKey: _key),
    );
    if (result == null || !context.mounted) return;

    final repo = ref.read(chapterRepositoryProvider);
    switch (result) {
      case _Deleted():
        final ok = await showConfirmDialog(
          context,
          title: 'Delete this moment?',
          message: 'It disappears from the chapter for both of you.',
          confirmLabel: 'Delete',
        );
        if (ok && context.mounted) {
          await _guard(context, () => repo.deleteMoment(existing!.id));
        }
      case _MomentSaved(:final draft):
        await _guard(
          context,
          () => repo.saveMoment(
            id: existing?.id,
            pairId: pair.id,
            key: _key,
            title: draft.title,
            note: draft.note,
            emoji: draft.emoji,
            happenedOn: draft.happenedOn,
            userId: userId,
          ),
        );
      case _GoalSaved():
      case _ReviewSaved():
        break; // not reachable from this sheet
    }
  }

  Future<void> _openReviewSheet(
    BuildContext context,
    WidgetRef ref,
    MonthlyChapter? chapter,
  ) async {
    final userId = ref.read(currentUserIdProvider);
    final pair = ref.read(currentPairProvider).valueOrNull;
    if (userId == null || pair == null) return;

    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        chapter: chapter,
        monthLabel: DateFormat('MMMM yyyy').format(_key.firstDay),
      ),
    );
    if (result == null || !context.mounted) return;

    if (result case _ReviewSaved(:final draft)) {
      await _guard(
        context,
        () => ref.read(chapterRepositoryProvider).saveReview(
              pairId: pair.id,
              key: _key,
              title: draft.title,
              review: draft.review,
              rating: draft.rating,
              closed: draft.closed,
              userId: userId,
            ),
      );
    }
  }
}

// ── Sections ────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.onAdd});
  final String label;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label.toUpperCase(), style: AppText.label())),
        GestureDetector(
          onTap: onAdd,
          child: Row(
            children: [
              const Icon(CupertinoIcons.add, size: 13, color: AppColors.brand),
              const SizedBox(width: 3),
              Text('Add', style: AppText.label(AppColors.brand)),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalProgress extends StatelessWidget {
  const _GoalProgress({required this.done, required this.total});
  final int done, total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Stack(
            children: [
              Container(height: 8, color: AppColors.surfaceSubtle),
              LayoutBuilder(builder: (context, box) {
                return AnimatedContainer(
                  duration: AppMotion.standard,
                  curve: AppMotion.easeOut,
                  height: 8,
                  width: box.maxWidth * fraction,
                  decoration: const BoxDecoration(gradient: AppGradients.cta),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xxs),
        Text('$done of $total done', style: AppText.caption()),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.scopeLabel,
    required this.editable,
    required this.onToggle,
    required this.onTap,
  });

  final MonthlyGoal goal;
  final String scopeLabel;
  final bool editable;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: editable ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.xs + 3),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: editable ? onToggle : null,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppMotion.micro,
                  margin: const EdgeInsets.only(top: 1, right: AppSpace.xs),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: goal.isDone ? AppGradients.cta : null,
                    border: goal.isDone
                        ? null
                        : Border.all(color: AppColors.blushMid, width: 1.5),
                  ),
                  child: goal.isDone
                      ? const Icon(Icons.done_rounded,
                          size: 14, color: Colors.white)
                      : null,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(goal.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            goal.title,
                            style: AppText.body(
                              goal.isDone ? AppColors.muted : AppColors.ink,
                            ).copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: goal.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: goal.isShared
                                ? AppColors.blush
                                : AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(scopeLabel,
                              style: AppText.label(goal.isShared
                                  ? AppColors.brandDark
                                  : AppColors.body)),
                        ),
                      ],
                    ),
                    if (goal.note != null && goal.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(goal.note!, style: AppText.caption()),
                    ],
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

class _MomentRow extends StatelessWidget {
  const _MomentRow({required this.moment, required this.onTap});
  final ChapterMoment moment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.xs + 3),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.blush,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(moment.emoji, style: const TextStyle(fontSize: 17)),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(moment.title,
                        style: AppText.body(AppColors.ink)
                            .copyWith(fontWeight: FontWeight.w600)),
                    if (moment.note != null &&
                        moment.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(moment.note!, style: AppText.caption()),
                    ],
                    if (moment.happenedOn != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('EEEE d').format(moment.happenedOn!),
                        style: AppText.label(),
                      ),
                    ],
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.chapterKey,
    required this.chapter,
    required this.goalsDone,
    required this.goalsTotal,
    required this.momentCount,
    required this.onWrite,
  });

  final ChapterKey chapterKey;
  final MonthlyChapter? chapter;
  final int goalsDone, goalsTotal, momentCount;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final written = chapter?.hasReview ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
            color: written ? AppColors.blushMid : AppColors.border),
        boxShadow: AppElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (written) ...[
            if (chapter!.rating != null) ...[
              _Hearts(rating: chapter!.rating!),
              const SizedBox(height: AppSpace.xs),
            ],
            Text(chapter!.review!, style: AppText.note()),
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Icon(
                  chapter!.isClosed
                      ? CupertinoIcons.checkmark_seal_fill
                      : CupertinoIcons.pencil,
                  size: 13,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    chapter!.isClosed
                        ? 'Chapter closed'
                        : 'Still open — keep adding to it',
                    style: AppText.caption(),
                  ),
                ),
                GestureDetector(
                  onTap: onWrite,
                  child: Text('Edit',
                      style: AppText.label(AppColors.brand)),
                ),
              ],
            ),
          ] else ...[
            Text(
              chapterKey.isPast
                  ? 'How was ${DateFormat('MMMM').format(chapterKey.firstDay)}?'
                  : 'The review comes at the end',
              style: AppText.title(),
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              chapterKey.isPast
                  ? 'You finished $goalsDone of $goalsTotal goals and logged '
                      '$momentCount moment${momentCount == 1 ? '' : 's'}. '
                      'Write what this month was actually about.'
                  : 'Come back when the month is over and turn the goals and '
                      'moments into a chapter you can read next year.',
              style: AppText.body(),
            ),
            const SizedBox(height: AppSpace.md),
            GradientButton(
              label: chapterKey.isPast ? 'Write the review' : 'Start it early',
              onPressed: onWrite,
            ),
          ],
        ],
      ),
    );
  }
}

class _Hearts extends StatelessWidget {
  const _Hearts({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (i) => Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Icon(
            i < rating
                ? CupertinoIcons.heart_fill
                : CupertinoIcons.heart,
            size: 15,
            color: i < rating ? AppColors.brand : AppColors.blushMid,
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.emoji,
    required this.title,
    required this.body,
  });
  final String emoji, title, body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: AppSpace.xs),
          Text(title, style: AppText.subtitle(), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(body, style: AppText.caption(), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Sheet results ───────────────────────────────────

sealed class _SheetResult {
  const _SheetResult();
}

class _Deleted extends _SheetResult {
  const _Deleted();
}

class _GoalSaved extends _SheetResult {
  const _GoalSaved(this.draft);
  final _GoalDraft draft;
}

class _MomentSaved extends _SheetResult {
  const _MomentSaved(this.draft);
  final _MomentDraft draft;
}

class _ReviewSaved extends _SheetResult {
  const _ReviewSaved(this.draft);
  final _ReviewDraft draft;
}

class _GoalDraft {
  const _GoalDraft({
    required this.shared,
    required this.title,
    required this.note,
    required this.emoji,
  });
  final bool shared;
  final String title;
  final String? note;
  final String emoji;
}

class _MomentDraft {
  const _MomentDraft({
    required this.title,
    required this.note,
    required this.emoji,
    required this.happenedOn,
  });
  final String title;
  final String? note;
  final String emoji;
  final DateTime? happenedOn;
}

class _ReviewDraft {
  const _ReviewDraft({
    required this.title,
    required this.review,
    required this.rating,
    required this.closed,
  });
  final String? title;
  final String? review;
  final int? rating;
  final bool closed;
}

// ── Goal sheet ──────────────────────────────────────

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.existing, required this.monthLabel});
  final MonthlyGoal? existing;
  final String monthLabel;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _emoji;
  late bool _shared;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
    _emoji = TextEditingController(text: existing?.emoji ?? '🎯');
    _shared = existing?.isShared ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _emoji.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the goal a name first.')),
      );
      return;
    }
    final emoji = _emoji.text.trim();
    Navigator.pop(
      context,
      _GoalSaved(_GoalDraft(
        shared: _shared,
        title: title,
        note: _note.text,
        emoji: emoji.isEmpty ? '🎯' : emoji,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return AppBottomSheet(
      title: isNew ? 'Add a goal' : 'Edit goal',
      subtitle: 'For ${widget.monthLabel}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNew) ...[
            const AppFieldLabel('Whose goal'),
            AppSegmented<bool>(
              options: const {true: 'Ours', false: 'Mine'},
              value: _shared,
              onChanged: (v) => setState(() => _shared = v),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
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
                    const AppFieldLabel('Goal'),
                    AppSheetField(
                      controller: _title,
                      hint: 'Save for the flight',
                      autofocus: isNew,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('Why / how (optional)'),
          AppSheetField(
            controller: _note,
            hint: 'Put aside a bit every payday',
            maxLines: 3,
          ),
          const SizedBox(height: AppSpace.md),
          GradientButton(
            label: isNew ? 'Add goal' : 'Save changes',
            onPressed: _save,
          ),
          if (!isNew) ...[
            const SizedBox(height: AppSpace.xs),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, const _Deleted()),
                child:
                    Text('Delete goal', style: AppText.caption(AppColors.danger)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Moment sheet ────────────────────────────────────

class _MomentSheet extends StatefulWidget {
  const _MomentSheet({required this.existing, required this.chapterKey});
  final ChapterMoment? existing;
  final ChapterKey chapterKey;

  @override
  State<_MomentSheet> createState() => _MomentSheetState();
}

class _MomentSheetState extends State<_MomentSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _emoji;
  DateTime? _happenedOn;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
    _emoji = TextEditingController(text: existing?.emoji ?? '✨');
    _happenedOn = existing?.happenedOn;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    // Bounded to the chapter's own month — a moment that happened in June
    // belongs in June's chapter, not this one.
    final picked = await showDatePicker(
      context: context,
      initialDate: _happenedOn ?? _initialDate(),
      firstDate: widget.chapterKey.firstDay,
      lastDate: widget.chapterKey.lastDay,
    );
    if (picked != null) setState(() => _happenedOn = picked);
  }

  DateTime _initialDate() {
    final now = DateTime.now();
    if (widget.chapterKey.isCurrent) return now;
    return widget.chapterKey.firstDay;
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('What happened? Give it a name.')),
      );
      return;
    }
    final emoji = _emoji.text.trim();
    Navigator.pop(
      context,
      _MomentSaved(_MomentDraft(
        title: title,
        note: _note.text,
        emoji: emoji.isEmpty ? '✨' : emoji,
        happenedOn: _happenedOn,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return AppBottomSheet(
      title: isNew ? 'Add a moment' : 'Edit moment',
      subtitle: 'Something worth remembering',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    const AppFieldLabel('What happened'),
                    AppSheetField(
                      controller: _title,
                      hint: 'We finally met at the airport',
                      autofocus: isNew,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('When (optional)'),
          GestureDetector(
            onTap: _pickDate,
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
                  const Icon(CupertinoIcons.calendar,
                      size: 15, color: AppColors.brand),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      _happenedOn == null
                          ? 'Sometime this month'
                          : DateFormat('EEEE d MMMM').format(_happenedOn!),
                      style: AppText.body(_happenedOn == null
                          ? AppColors.muted
                          : AppColors.ink),
                    ),
                  ),
                  if (_happenedOn != null)
                    GestureDetector(
                      onTap: () => setState(() => _happenedOn = null),
                      child: const Icon(CupertinoIcons.clear_circled,
                          size: 16, color: AppColors.muted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('Note (optional)'),
          AppSheetField(
            controller: _note,
            hint: 'I cried in arrivals and I am not sorry',
            maxLines: 3,
          ),
          const SizedBox(height: AppSpace.md),
          GradientButton(
            label: isNew ? 'Add moment' : 'Save changes',
            onPressed: _save,
          ),
          if (!isNew) ...[
            const SizedBox(height: AppSpace.xs),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, const _Deleted()),
                child: Text('Delete moment',
                    style: AppText.caption(AppColors.danger)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Review sheet ────────────────────────────────────

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.chapter, required this.monthLabel});
  final MonthlyChapter? chapter;
  final String monthLabel;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final TextEditingController _title;
  late final TextEditingController _review;
  late int _rating;
  late bool _closed;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.chapter?.title ?? '');
    _review = TextEditingController(text: widget.chapter?.review ?? '');
    _rating = widget.chapter?.rating ?? 0;
    _closed = widget.chapter?.isClosed ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _review.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      _ReviewSaved(_ReviewDraft(
        title: _title.text,
        review: _review.text,
        // 0 means "not rated", which the column stores as null — the check
        // constraint only allows 1–5.
        rating: _rating == 0 ? null : _rating,
        closed: _closed,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Review ${widget.monthLabel}',
      subtitle: 'What this month was actually about',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppFieldLabel('Call it something'),
          AppSheetField(
            controller: _title,
            hint: 'The month we finally met',
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('How was it'),
          Row(
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return GestureDetector(
                // Tapping the current rating clears it — otherwise a
                // misplaced tap can never be undone.
                onTap: () =>
                    setState(() => _rating = _rating == i + 1 ? 0 : i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpace.xxs),
                  child: Icon(
                    filled ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    size: 28,
                    color: filled ? AppColors.brand : AppColors.blushMid,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpace.sm),
          const AppFieldLabel('The review'),
          AppSheetField(
            controller: _review,
            hint: 'What you did, what you learned, what you want to keep.',
            maxLines: 7,
            serif: true,
          ),
          const SizedBox(height: AppSpace.sm),
          GestureDetector(
            onTap: () => setState(() => _closed = !_closed),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  _closed
                      ? CupertinoIcons.checkmark_seal_fill
                      : CupertinoIcons.circle,
                  size: 20,
                  color: _closed ? AppColors.brand : AppColors.muted,
                ),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: Text(
                    'Close this chapter',
                    style: AppText.body(AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text('Closing is a milestone, not a lock — you can still edit it.',
              style: AppText.caption()),
          const SizedBox(height: AppSpace.md),
          GradientButton(label: 'Save review', onPressed: _save),
        ],
      ),
    );
  }
}

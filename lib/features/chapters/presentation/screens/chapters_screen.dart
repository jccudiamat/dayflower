import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_error_notice.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../../core/widgets/ios_back_button.dart';
import '../../data/chapter_repository.dart';

/// The year at a glance: twelve chapters, one per month.
///
/// A chapter is written in two sittings — goals at the start of the month,
/// a review at the end — so this screen's job is to make it obvious which
/// sitting is due. The current month gets the hero; a finished month with
/// no review gets a nudge above the grid.
class ChaptersScreen extends ConsumerStatefulWidget {
  const ChaptersScreen({super.key});

  @override
  ConsumerState<ChaptersScreen> createState() => _ChaptersScreenState();
}

class _ChaptersScreenState extends ConsumerState<ChaptersScreen> {
  late int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(monthlyGoalsProvider);
    final momentsAsync = ref.watch(chapterMomentsProvider);
    final chaptersAsync = ref.watch(monthlyChaptersProvider);
    final goals = goalsAsync.valueOrNull ?? const <MonthlyGoal>[];
    final moments = momentsAsync.valueOrNull ?? const <ChapterMoment>[];
    final chapters = chaptersAsync.valueOrNull ?? const <MonthlyChapter>[];
    // An empty year and a year that failed to load look identical
    // otherwise — see [AppErrorNotice].
    final loadError =
        goalsAsync.error ?? momentsAsync.error ?? chaptersAsync.error;
    final unwritten = ref.watch(unwrittenChapterProvider);
    final current = ChapterKey.current;

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
                      title: 'Chapters',
                      subtitle: 'Twelve months, twelve stories',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.sm, 0, AppSpace.sm, AppSpace.md),
                children: [
                  if (loadError != null)
                    AppErrorNotice(
                      message: 'Your chapters could not load',
                      detail: loadError,
                    ),
                  _YearBar(
                    year: _year,
                    onShift: (by) => setState(() => _year += by),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  if (_year == current.year) ...[
                    _CurrentChapterCard(
                      chapterKey: current,
                      goals: goals.where((g) => g.key == current).toList(),
                      moments: moments.where((m) => m.key == current).length,
                      onOpen: () => _open(current),
                    ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                  if (unwritten != null) ...[
                    _ReviewNudge(
                      chapter: unwritten,
                      onTap: () => _open(unwritten),
                    ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                  Text('$_year', style: AppText.label()),
                  const SizedBox(height: AppSpace.xs),
                  LayoutBuilder(builder: (context, box) {
                    const gap = AppSpace.xs;
                    final width = (box.maxWidth - gap * 2) / 3;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: List.generate(12, (i) {
                        final key = ChapterKey(_year, i + 1);
                        return SizedBox(
                          width: width,
                          child: _MonthTile(
                            chapterKey: key,
                            goals: goals.where((g) => g.key == key).toList(),
                            moments:
                                moments.where((m) => m.key == key).length,
                            chapter: chapters
                                .firstWhereOrNull((c) => c.key == key),
                            onTap: () => _open(key),
                          ),
                        );
                      }),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  void _open(ChapterKey key) =>
      context.go(Routes.chapterFor(key.year, key.month));
}

// ── Pieces ──────────────────────────────────────────

class _YearBar extends StatelessWidget {
  const _YearBar({required this.year, required this.onShift});
  final int year;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => onShift(-1),
          icon: const Icon(CupertinoIcons.chevron_back,
              size: 16, color: AppColors.body),
          splashRadius: 20,
        ),
        Expanded(
          child: Text('$year',
              textAlign: TextAlign.center, style: AppText.subtitle()),
        ),
        IconButton(
          onPressed: () => onShift(1),
          icon: const Icon(CupertinoIcons.chevron_forward,
              size: 16, color: AppColors.body),
          splashRadius: 20,
        ),
      ],
    );
  }
}

class _CurrentChapterCard extends StatelessWidget {
  const _CurrentChapterCard({
    required this.chapterKey,
    required this.goals,
    required this.moments,
    required this.onOpen,
  });

  final ChapterKey chapterKey;
  final List<MonthlyGoal> goals;
  final int moments;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final done = goals.where((g) => g.isDone).length;
    final daysLeft = chapterKey.lastDay.day - DateTime.now().day;

    return GestureDetector(
      onTap: onOpen,
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
                Expanded(
                  child: Text('THIS CHAPTER',
                      style: AppText.label(AppColors.onDarkMuted)),
                ),
                Text(
                  daysLeft <= 0
                      ? 'Last day'
                      : '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left',
                  style: AppText.label(AppColors.onDarkMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(DateFormat('MMMM').format(chapterKey.firstDay),
                style: AppText.display(AppColors.onDark)),
            const SizedBox(height: AppSpace.xs),
            if (goals.isEmpty)
              Text(
                'Nothing written down yet. Start the month by listing what '
                'the two of you want out of it.',
                style: AppText.note(AppColors.onDarkMuted),
              )
            else ...[
              _Progress(done: done, total: goals.length),
              const SizedBox(height: AppSpace.xs),
              Text(
                '$done of ${goals.length} goals'
                '${moments > 0 ? '  ·  $moments moment${moments == 1 ? '' : 's'} logged' : ''}',
                style: AppText.caption(AppColors.onDarkMuted),
              ),
            ],
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Text(goals.isEmpty ? 'Set this month\'s goals' : 'Open chapter',
                    style: AppText.body(AppColors.onDark)
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                const Icon(CupertinoIcons.chevron_forward,
                    size: 13, color: AppColors.onDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});
  final int done, total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : done / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Stack(
        children: [
          Container(
            height: 8,
            color: Colors.white.withValues(alpha: .12),
          ),
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
    );
  }
}

class _ReviewNudge extends StatelessWidget {
  const _ReviewNudge({required this.chapter, required this.onTap});
  final ChapterKey chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.blush,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.blushMid),
        ),
        child: Row(
          children: [
            const Text('📖', style: TextStyle(fontSize: 22)),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DateFormat('MMMM').format(chapter.firstDay)} is over',
                    style: AppText.body(AppColors.ink)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 1),
                  Text('Write its review while you still remember it.',
                      style: AppText.caption(AppColors.body)),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_forward,
                size: 14, color: AppColors.brand),
          ],
        ),
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.chapterKey,
    required this.goals,
    required this.moments,
    required this.chapter,
    required this.onTap,
  });

  final ChapterKey chapterKey;
  final List<MonthlyGoal> goals;
  final int moments;
  final MonthlyChapter? chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final future = chapterKey.isFuture;
    final current = chapterKey.isCurrent;
    final done = goals.where((g) => g.isDone).length;
    final written = chapter?.hasReview ?? false;
    final closed = chapter?.isClosed ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        // A month that hasn't started is still openable — writing goals
        // ahead is fine — it just shouldn't compete for attention.
        opacity: future ? .5 : 1,
        child: Container(
          height: 96,
          padding: const EdgeInsets.all(AppSpace.xs),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: current ? AppColors.brand : AppColors.border,
              width: current ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('MMM').format(chapterKey.firstDay),
                      style: AppText.subtitle(
                          current ? AppColors.brand : AppColors.ink),
                    ),
                  ),
                  if (closed)
                    const Icon(CupertinoIcons.checkmark_seal_fill,
                        size: 13, color: AppColors.brand)
                  else if (written)
                    const Icon(CupertinoIcons.book,
                        size: 12, color: AppColors.secondary),
                ],
              ),
              const Spacer(),
              if (goals.isEmpty && moments == 0)
                Text(future ? 'Not yet' : 'Empty', style: AppText.label())
              else ...[
                if (goals.isNotEmpty)
                  Text('$done/${goals.length} goals',
                      style: AppText.caption(AppColors.body)),
                if (moments > 0)
                  Text('$moments moment${moments == 1 ? '' : 's'}',
                      style: AppText.label()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

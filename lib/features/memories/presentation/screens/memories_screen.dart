import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../booth/presentation/widgets/booth_visuals.dart';
import '../../../booth/presentation/screens/booth_studio_screen.dart';
import '../widgets/booth_memory_previews.dart';
import '../../../chapters/data/chapter_repository.dart';

import '../widgets/journal_book_preview.dart';

class MemoriesScreen extends ConsumerWidget {
  const MemoriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(monthlyChaptersProvider);
    final unwritten = ref.watch(unwrittenChapterProvider);
    final written = (chapters.valueOrNull ?? <MonthlyChapter>[])
        .where((c) => c.hasReview)
        .toList()
      ..sort((a, b) => b.key.firstDay.compareTo(a.key.firstDay));
    final latest = written.isEmpty ? null : written.first;
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
            const FeatureScreenHeader(
                title: 'Memories', subtitle: 'Little moments. Yours to keep.'),
            const SizedBox(height: 24),
            _heading(context, 'Booth & Strip', 'Step inside', Routes.booth),
            Text('A few poses. A little laughter. A strip of you.',
                style: AppText.body()),
            const SizedBox(height: 8),
            BoothPortal(
                compact: true,
                onEnter: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const BoothStudioScreen()))),
            const SizedBox(height: 32),
            _heading(context, 'Pending strips', 'See pending', Routes.boothPending),
            const PendingStripsPreview(),
            const SizedBox(height: 32),
            _heading(context, 'Booth collection', 'See all', Routes.boothCollection),
            const BoothCollectionPreview(),
            const SizedBox(height: 32),
            _heading(context, 'Journal', 'Open journal', Routes.chapters),
            if (chapters.hasError)
              _retry('Your journal could not load.',
                  () => ref.invalidate(monthlyChaptersProvider)),
            JournalBookPreview(
              latest: latest,
              hasUnwrittenMonth: unwritten != null,
              onTap: () => context.push(Routes.chapters),
            ),
          ])),
    );
  }

  Widget _heading(
          BuildContext context, String title, String action, String path) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                InkWell(
                    onTap: () => context.push(path),
                    child: Text(title, style: AppText.title())),
                TextButton(
                    onPressed: () => context.push(path), child: Text(action))
              ]));
  Widget _retry(String text, VoidCallback retry) =>
      TextButton(onPressed: retry, child: Text('$text Retry'));
}

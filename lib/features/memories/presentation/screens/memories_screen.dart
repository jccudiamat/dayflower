import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../booth/presentation/widgets/booth_visuals.dart';
import '../../../booth/presentation/screens/booth_studio_screen.dart';
import '../../../booth/data/strip_repository.dart';
import '../../../chapters/data/chapter_repository.dart';
import '../../../tulip/data/flower_repository.dart';

class MemoriesScreen extends ConsumerWidget {
  const MemoriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(flowerMessagesProvider);
    final waiting = ref.watch(openStripsProvider).valueOrNull ?? [];
    final photos = (messages.valueOrNull ?? <FlowerMessage>[])
        .where((m) => m.isPhoto)
        .toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    final days = photos.where((p) => p.toWidget).toList();
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
            if (waiting.isNotEmpty)
              TextButton.icon(
                  onPressed: () => context.push(Routes.booth),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Open your waiting strips')),
            const SizedBox(height: 36),
            _heading(context, 'Shared photos', 'See all', Routes.photos),
            if (messages.isLoading) const LinearProgressIndicator(),
            if (messages.hasError)
              _retry('Your photos could not load.',
                  () => ref.invalidate(flowerMessagesProvider)),
            InkWell(
                onTap: () => context.push(Routes.photos),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 22),
                    decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(20)),
                    child: Column(children: [
                      SizedBox(
                          height: 145,
                          child: Row(children: [
                            for (var i = 0; i < 3; i++)
                              Expanded(
                                child: Transform.rotate(
                                    angle: i == 1 ? .055 : -.05,
                                    child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        padding: const EdgeInsets.fromLTRB(
                                            5, 5, 5, 18),
                                        decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            boxShadow: AppElevation.card),
                                        child: _PhotoPreview(
                                            photo: i < photos.length
                                                ? photos[i]
                                                : null,
                                            icon: i == 1
                                                ? Icons.favorite_border
                                                : Icons.photo_outlined))),
                              ),
                          ])),
                      const SizedBox(height: 18),
                      Text(
                          photos.isEmpty
                              ? 'The photos you share will gather here.'
                              : 'Your latest moments, together.',
                          style: AppText.caption(),
                          textAlign: TextAlign.center),
                    ]))),
            const SizedBox(height: 32),
            _heading(context, 'My Day photos', 'Revisit', Routes.myDays),
            InkWell(
                onTap: () => context.push(Routes.myDays),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Ordinary days,\nworth keeping.',
                                style: AppText.title()),
                            const SizedBox(height: 12),
                            Text('The little glimpses you send each other.',
                                style: AppText.body()),
                          ])),
                      const SizedBox(width: 16),
                      SizedBox(
                          width: 145,
                          height: 172,
                          child: Stack(children: [
                            Positioned(
                                right: 3,
                                top: 17,
                                width: 102,
                                height: 145,
                                child: Transform.rotate(
                                    angle: .12,
                                    child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(60),
                                                bottom: Radius.circular(16)),
                                        child: _PhotoPreview(
                                            photo: days.length > 1
                                                ? days[1]
                                                : null,
                                            icon: Icons.wb_sunny_outlined)))),
                            Positioned(
                                left: 0,
                                top: 0,
                                width: 105,
                                height: 150,
                                child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(60),
                                        bottom: Radius.circular(16)),
                                    child: _PhotoPreview(
                                        photo: days.isEmpty ? null : days.first,
                                        icon: Icons.camera_alt_outlined))),
                          ])),
                    ]))),
            const SizedBox(height: 32),
            _heading(context, 'Chapters', 'Open journal', Routes.chapters),
            if (chapters.hasError)
              _retry('Your chapters could not load.',
                  () => ref.invalidate(monthlyChaptersProvider)),
            InkWell(
                onTap: () => context.push(Routes.chapters),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [AppColors.blush, AppColors.surface]),
                        borderRadius: BorderRadius.circular(16),
                        border: const Border(
                            left:
                                BorderSide(color: AppColors.brand, width: 7))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.auto_stories_outlined,
                                color: AppColors.brand),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(
                                    latest == null
                                        ? DateFormat('MMMM yyyy')
                                            .format(DateTime.now())
                                        : DateFormat('MMMM yyyy')
                                            .format(latest.key.firstDay),
                                    style: AppText.label()))
                          ]),
                          const SizedBox(height: 20),
                          Text(latest?.title ?? 'Our story, month by month',
                              style: AppText.title()),
                          const SizedBox(height: 12),
                          Text(
                              latest?.review ??
                                  'The moments you remember. The things you are looking forward to.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body()),
                          const SizedBox(height: 22),
                          Text(
                              unwritten == null
                                  ? 'Reflections & shared goals'
                                  : 'A chapter is waiting for your reflection',
                              style: AppText.caption(AppColors.brand)),
                        ]))),
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

class _PhotoPreview extends ConsumerWidget {
  const _PhotoPreview({this.photo, required this.icon});
  final FlowerMessage? photo;
  final IconData icon;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = photo?.imagePath;
    Widget empty() => ColoredBox(
        color: AppColors.blush,
        child: Center(
            child: Icon(icon,
                color: AppColors.brand.withValues(alpha: .5), size: 28)));
    if (path == null) return empty();
    return ref.watch(dayPhotoUrlProvider(path)).when(
          loading: empty,
          error: (_, __) =>
              const Center(child: Icon(Icons.broken_image_outlined)),
          data: (url) => url == null
              ? empty()
              : Image.network(url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image_outlined))),
        );
  }
}

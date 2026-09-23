import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../booth/data/strip_repository.dart';
import '../../../booth/domain/booth_design.dart';
import '../../../booth/presentation/screens/booth_studio_screen.dart';
import '../../../tulip/data/flower_repository.dart';
import '../../../tulip/presentation/widgets/media_viewer.dart';
import '../../../../core/widgets/storage_image.dart';

class PendingStripsPreview extends ConsumerWidget {
  const PendingStripsPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(openStripsProvider);
    final user = ref.watch(currentUserIdProvider);
    return pending.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => TextButton(
          onPressed: () => ref.invalidate(openStripsProvider),
          child: const Text('Could not load pending strips. Retry')),
      data: (strips) {
        if (strips.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.brand, size: 30),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('All caught up', style: AppText.subtitle()),
                    const SizedBox(height: 6),
                    Text(
                        'When one of you starts a couple strip, finish it together here.',
                        style: AppText.body()),
                  ])),
            ]),
          );
        }
        // Put something I can act on before a strip waiting on my partner.
        final ordered = [...strips]..sort((a, b) {
            int priority(PhotoStrip s) => s.isFullButUnposted
                ? 0
                : s.aUser != user
                    ? 1
                    : 2;
            final actionOrder = priority(a).compareTo(priority(b));
            return actionOrder != 0
                ? actionOrder
                : b.createdAt.compareTo(a.createdAt);
          });
        final strip = ordered.first;
        final mine = strip.aUser == user;
        final ready = strip.isFullButUnposted;
        final label = ready
            ? 'Finish sharing'
            : mine
                ? 'View pending strip'
                : 'Join this strip';
        void open() {
          if (!ready && !mine && BoothDesign.parse(strip.template) != null) {
            Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => BoothStudioScreen(joining: strip)));
          } else {
            context.push(Routes.boothPending);
          }
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: open,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                  height: 174,
                  child: Row(children: [
                    Expanded(child: BoothStoredPhoto(path: strip.aPath)),
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.favorite_border,
                            color: AppColors.brand, size: 20)),
                    Expanded(
                        child: strip.bPath != null
                            ? BoothStoredPhoto(path: strip.bPath!)
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.brand
                                            .withValues(alpha: .25))),
                                child: const Center(
                                    child: Icon(Icons.add_a_photo_outlined,
                                        color: AppColors.brand, size: 34)))),
                  ])),
            ),
          ),
          const SizedBox(height: 12),
          Text(
              ready
                  ? 'Your photos are ready to share'
                  : mine
                      ? 'A little space for your partner'
                      : 'Your partner saved you a spot',
              style: AppText.subtitle()),
          const SizedBox(height: 6),
          Text(
              ready
                  ? 'Both halves are saved. Finish your strip.'
                  : mine
                      ? 'Your photos are saved. Waiting for their half.'
                      : 'Add your photos to finish the strip together.',
              style: AppText.body()),
          const SizedBox(height: 8),
          Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(onPressed: open, child: Text(label)),
                if (strips.length > 1)
                  TextButton(
                      onPressed: () => context.push(Routes.boothPending),
                      child: Text('View all ${strips.length} pending')),
              ]),
        ]);
      },
    );
  }
}

class BoothCollectionPreview extends ConsumerWidget {
  const BoothCollectionPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(boothCollectionProvider).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => TextButton(
              onPressed: () => ref.invalidate(flowerMessagesProvider),
              child: const Text('Could not load your booth collection. Retry')),
          data: (photos) => Column(children: [
            SizedBox(
                height: 232,
                child: Stack(children: [
                  Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Divider(
                          color: AppColors.muted.withValues(alpha: .4))),
                  Positioned.fill(
                      top: 12,
                      child: Row(children: [
                        for (var i = 0; i < 3; i++)
                          Expanded(
                              child: _HangingPrint(
                                  photo: i < photos.length ? photos[i] : null,
                                  index: i)),
                      ])),
                ])),
            const SizedBox(height: 14),
            Text(
                photos.isEmpty
                    ? 'Your booth keepsakes start here'
                    : 'Fresh from the booth',
                style: AppText.subtitle(),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
                photos.isEmpty
                    ? 'Strips and photos you save to Memories will collect here.'
                    : 'Tap a print to open it, or see your whole collection.',
                style: AppText.body(),
                textAlign: TextAlign.center),
          ]),
        );
  }
}

class _HangingPrint extends StatelessWidget {
  const _HangingPrint({required this.photo, required this.index});
  final FlowerMessage? photo;
  final int index;

  double get aspect {
    for (final look in BoothLook.values) {
      for (final layout in BoothLayout.values) {
        final design = BoothDesign(look: look, layout: layout);
        if (photo?.note == design.title) return layout.aspect;
      }
    }
    return .48;
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 204),
            child: AspectRatio(
              aspectRatio: aspect,
              child: Transform.rotate(
                angle: index == 1 ? .055 : -.045,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                      child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: AppColors.surface, boxShadow: AppElevation.card),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          final item = photo;
                          if (item == null) {
                            context.push(Routes.boothCollection);
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => MediaViewer(
                                    title: item.note ?? 'Booth photo',
                                    subtitle:
                                        DateFormat.yMMMd().format(item.sentAt),
                                    imagePath: item.imagePath!,
                                    fileName: 'dayflower-strip-${item.id}.jpg',
                                  )));
                        },
                        child: photo != null
                            ? BoothStoredPhoto(path: photo!.imagePath!)
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(5, 8, 5, 14),
                                child: Column(children: [
                                  for (var n = 0; n < 3; n++)
                                    Expanded(
                                        child: Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 4),
                                      color: AppColors.surfaceSubtle,
                                      child: Icon(
                                          n == 1
                                              ? Icons.favorite_border
                                              : Icons.photo_outlined,
                                          color: AppColors.muted
                                              .withValues(alpha: .45),
                                          size: 20),
                                    )),
                                ])),
                      ),
                    ),
                  )),
                  Positioned(
                      top: -8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                            width: 9,
                            height: 22,
                            decoration: BoxDecoration(
                                color: const Color(0xFFC4A178),
                                borderRadius: BorderRadius.circular(2))),
                      )),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Preserve the whole exported frame, including captions and paper borders.
class BoothStoredPhoto extends ConsumerWidget {
  const BoothStoredPhoto({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) => StorageImage.dayPhoto(
        path,
        fit: BoxFit.contain,
        placeholder: const Center(child: CircularProgressIndicator()),
        error: (retry) => IconButton(
            tooltip: 'Retry photo',
            onPressed: retry,
            icon: const Icon(Icons.refresh)),
      );
}

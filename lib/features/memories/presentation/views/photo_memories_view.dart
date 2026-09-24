import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/storage_image.dart';
import '../../../../core/widgets/story_components.dart';
import '../../../tulip/data/flower_repository.dart';
import '../../../tulip/presentation/widgets/media_viewer.dart';
import '../../data/memory_views.dart';
import '../widgets/memory_category_tabs.dart';

/// Photos: a wall of pictures, month by month, like a scrapbook.
///
/// Never timeline rows. Each month is a mosaic of controlled shapes (see
/// [mosaicBlocks]); a month with more than fits opens the full library
/// from "View all".
class PhotoMemoryGrid extends StatelessWidget {
  const PhotoMemoryGrid({
    super.key,
    required this.photos,
    required this.isStrip,
  });

  /// Newest first.
  final List<FlowerMessage> photos;
  final bool Function(FlowerMessage) isStrip;

  /// How many a month shows before "View all" takes over.
  static const perMonth = 10;

  @override
  Widget build(BuildContext context) {
    final months = byMonth(photos, (m) => m.sentAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (months.isEmpty)
          MemoryEmpty(title: MemoryCategory.photos.emptyTitle)
        else
          for (final (i, (month, items)) in months.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpace.md),
            MemorySectionHeader(
              title: DateFormat('MMMM y').format(month),
              meta: '${items.length} moment${items.length == 1 ? '' : 's'}',
              action: items.length > perMonth ? 'View all' : null,
              onAction: () => context.push(Routes.photos),
            ),
            const SizedBox(height: AppSpace.compact),
            PhotoMosaic(
                blocks: mosaicBlocks(items.take(perMonth).toList(), isStrip)),
          ],
        const SizedBox(height: AppSpace.md),
        // The one way in to the prints you kept: they are photos, so they
        // live with the photos.
        UtilityRow(
          icon: CupertinoIcons.film,
          title: 'Prints',
          subtitle: 'The strips you kept',
          onTap: () => context.push(Routes.boothCollection),
        ),
      ],
    );
  }
}

/// The blocks of one month, sized to the width they are given.
class PhotoMosaic extends StatelessWidget {
  const PhotoMosaic({super.key, required this.blocks});

  final List<MosaicBlock> blocks;

  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth;
        // Three columns, and a unit a little shorter than wide: landscape
        // leaning, the way most pictures are taken.
        final w = (width - 2 * _gap) / 3;
        final u = w * .92;
        return Column(children: [
          for (final (i, block) in blocks.indexed) ...[
            if (i > 0) const SizedBox(height: _gap),
            switch (block) {
              HeroBlock(:final big, :final small, :final mirror) => Row(
                  children: [
                    for (final part in mirror
                        ? [_stack(small, w, u), _big(big, w, u)]
                        : [_big(big, w, u), _stack(small, w, u)])
                      part,
                  ].expand((part) => [part, const SizedBox(width: _gap)])
                      .toList()
                    ..removeLast(),
                ),
              StripBlock(:final strip, :final others) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (others.isNotEmpty) ...[
                      SizedBox(
                        width: 2 * w + _gap,
                        child: Wrap(
                          spacing: _gap,
                          runSpacing: _gap,
                          // Always the strip's full height, never a hole
                          // beside it: one fills it, two stack wide, the
                          // third of three spans both columns.
                          children: [
                            for (final (i, m) in others.indexed)
                              switch (others.length) {
                                1 => PhotoTile(m, 2 * w + _gap, 2 * u + _gap),
                                2 => PhotoTile(m, 2 * w + _gap, u),
                                3 when i == 2 =>
                                  PhotoTile(m, 2 * w + _gap, u),
                                _ => PhotoTile(m, w, u),
                              },
                          ],
                        ),
                      ),
                      const SizedBox(width: _gap),
                    ],
                    PhotoTile(strip, w, 2 * u + _gap),
                  ],
                ),
              RowBlock(:final photos) => Row(
                  children: [
                    for (final (j, m) in photos.indexed) ...[
                      if (j > 0) const SizedBox(width: _gap),
                      switch (photos.length) {
                        1 => PhotoTile(m, width, width * .56),
                        2 => PhotoTile(m, (width - _gap) / 2, u * 1.1),
                        _ => PhotoTile(m, w, u),
                      },
                    ],
                  ],
                ),
            },
          ],
        ]);
      });

  static Widget _big(FlowerMessage m, double w, double u) =>
      PhotoTile(m, 2 * w + _gap, 2 * u + _gap);

  static Widget _stack(List<FlowerMessage> small, double w, double u) =>
      Column(children: [
        for (final (i, m) in small.indexed) ...[
          if (i > 0) const SizedBox(height: _gap),
          PhotoTile(m, w, u),
        ],
      ]);
}

/// One picture on the wall. No words on it: the picture is the point.
class PhotoTile extends ConsumerWidget {
  const PhotoTile(this.message, this.width, this.height, {super.key});

  final FlowerMessage message;
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = (message.note ?? '').trim();
    return GestureDetector(
      onTap: () => showPhotoMessage(context, ref, message),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MemoriesStyle.photoRadius),
        child: StorageImage.dayPhoto(
          message.imagePath!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          decodeWidth: width,
          semanticLabel: note.isEmpty ? 'Photo' : note,
          error: (retry) => GestureDetector(
            onTap: retry,
            child: Container(
              width: width,
              height: height,
              color: AppColors.surfaceSubtle,
              alignment: Alignment.center,
              child: AppIcon(CupertinoIcons.photo,
                  size: 20, color: AppColors.muted),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/storage_image.dart';
import '../../../tulip/data/flower_repository.dart';
import '../../../tulip/domain/photo_shape.dart';
import '../../../tulip/presentation/widgets/media_viewer.dart';
import '../../data/memory_views.dart';
import '../widgets/memory_category_tabs.dart';

/// Cards: a box of saved letters and postcards.
///
/// Each card is shown as the thing that was sent, its own artwork in a thin
/// paper edge, at its own shape, stacked masonry style so tall notes and
/// wide postcards sit together without cropping either. The date goes
/// underneath, the way you would write it on the back.
class CardMemoryGrid extends StatelessWidget {
  const CardMemoryGrid({super.key, required this.cards});

  /// Newest first.
  final List<FlowerMessage> cards;

  /// A card from before shapes were recorded: a portrait card's usual shape.
  static const _defaultAspect = 4 / 5;

  /// The date line under each card, and the space above it.
  static const _dateLine = 22.0;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return MemoryEmpty(title: MemoryCategory.cards.emptyTitle);
    }
    return LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth >= 330 ? 3 : 2;
      const gap = MemoriesStyle.gap;
      final width = (box.maxWidth - gap * (columns - 1)) / columns;
      final aspects = [
        for (final c in cards) photoAspectOf(c.imagePath!) ?? _defaultAspect,
      ];
      final placed = masonryColumns(
          [for (final a in aspects) width / a + _dateLine + gap], columns);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (c, column) in placed.indexed) ...[
            if (c > 0) const SizedBox(width: gap),
            SizedBox(
              width: width,
              child: Column(children: [
                for (final i in column)
                  Padding(
                    padding: const EdgeInsets.only(bottom: gap),
                    child: CardMemoryTile(
                        card: cards[i],
                        width: width,
                        height: width / aspects[i]),
                  ),
              ]),
            ),
          ],
        ],
      );
    });
  }
}

/// One saved card: its artwork on a paper edge, and the date under it.
class CardMemoryTile extends ConsumerWidget {
  const CardMemoryTile({
    super.key,
    required this.card,
    required this.width,
    required this.height,
  });

  final FlowerMessage card;
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occasion = (card.note ?? '')
        .split('\n')
        .first
        .replaceFirst('Dayflower card · ', '')
        .trim();
    return GestureDetector(
      onTap: () => showPhotoMessage(context, ref, card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: width,
            height: height,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: AppElevation.card,
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: StorageImage.dayPhoto(
                card.imagePath!,
                width: width - 6,
                height: height - 6,
                fit: BoxFit.cover,
                decodeWidth: width,
                semanticLabel: occasion.isEmpty ? 'A card' : occasion,
                error: (retry) => GestureDetector(
                  onTap: retry,
                  child: Container(
                    color: MemoriesStyle.givenTint,
                    alignment: Alignment.center,
                    child: const AppIcon(CupertinoIcons.envelope,
                        size: 22, color: AppColors.brand),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(DateFormat('d MMM y').format(card.sentAt),
              maxLines: 1, style: MemoriesStyle.tileMeta()),
        ],
      ),
    );
  }
}

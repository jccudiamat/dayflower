import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../gifts/data/gift_favorites_repository.dart';
import '../../data/together_assets.dart';
import 'together_art.dart';
import 'together_card.dart';

/// Gifts: how many ideas you have saved, and the way back to them.
///
/// The count is the hearts you have tapped on the Gifts page — the same
/// saved set that page shows — so it is yours, not the couple's: the whole
/// point of a saved gift idea is that the other one does not see it.
class TogetherGiftsCard extends ConsumerWidget {
  const TogetherGiftsCard({super.key});

  /// The gift is drawn this wide, on the right beside the tagline, as the
  /// mockup has it — above the button rather than under it.
  static const _artWidth = 74.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(giftFavoritesProvider);
    final count = saved.valueOrNull?.length;
    void open() => context.push(Routes.gifts);

    return TogetherCard(
      tint: TogetherTint.blush,
      padding: const EdgeInsets.all(TogetherStyle.padTight),
      onTap: open,
      // ⚠️ Expand, so the card's full height is the Stack's — the pill sits
      // on the bottom edge however tall Events makes the row.
      child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
        const Positioned(
          right: -6,
          bottom: 30,
          width: _artWidth,
          height: _artWidth * 319 / 360,
          child: TogetherArt(
            TogetherAssets.gift,
            fallbackIcon: CupertinoIcons.gift,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TogetherCardHeader(
              icon: CupertinoIcons.gift,
              iconColor: TogetherStyle.iconGifts,
              title: 'Gifts',
              subtitle: switch (count) {
                null => saved.hasError ? 'Ideas for every occasion' : null,
                0 => 'No ideas saved yet',
                1 => '1 idea saved',
                final n => '$n ideas saved',
              },
            ),
            const SizedBox(height: AppSpace.compact - 2),
            // Kept left of the gift: the words wrap to a third line
            // rather than run under the picture.
            Padding(
              padding: const EdgeInsets.only(right: _artWidth * .5),
              child: Text('Thoughtful surprises for special moments.',
                  style: TogetherStyle.tagline()),
            ),
            const Spacer(),
            const SizedBox(height: AppSpace.compact),
            TogetherPill(
              label: 'View ideas',
              style: TogetherPillStyle.plain,
              small: true,
              onTap: open,
            ),
          ],
        ),
      ]),
    );
  }
}

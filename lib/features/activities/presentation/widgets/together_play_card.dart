import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/together_mock_data.dart';
import 'together_art.dart';
import 'together_card.dart';

/// Play Together: games, music and a watch party.
///
/// 🔴 **Mock, all of it** — see together_mock_data.dart. There is nothing
/// behind these tiles yet, so a tap says "coming soon" rather than opening
/// an empty screen or doing nothing at all.
class TogetherPlayCard extends StatelessWidget {
  const TogetherPlayCard({super.key});

  static void _soon(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    // At large text three tiles across would break "Together" in half, so
    // they become a list, each tile a row.
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    final tiles = [
      for (final tile in playTogetherTiles)
        _Tile(
          tile: tile,
          row: large,
          onTap: () => _soon(context, tile.title),
        ),
    ];
    return TogetherCard(
      onTap: () => _soon(context, 'Play Together'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TogetherCardHeader(
            icon: Icons.sports_esports_rounded,
            iconColor: TogetherStyle.iconPlay,
            title: 'Play Together',
            subtitle: playTogetherSubtitle,
            trailing:
                TogetherSeeAll(onTap: () => _soon(context, 'Play Together')),
          ),
          const SizedBox(height: AppSpace.compact),
          if (large)
            for (final (i, tile) in tiles.indexed) ...[
              if (i > 0) const SizedBox(height: AppSpace.xs),
              tile,
            ]
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, tile) in tiles.indexed) ...[
                    if (i > 0) const SizedBox(width: AppSpace.xs),
                    Expanded(child: tile),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile, required this.onTap, this.row = false});

  final PlayTile tile;
  final VoidCallback onTap;

  /// Art beside the words rather than above them.
  final bool row;

  @override
  Widget build(BuildContext context) {
    final art = TogetherArt(
      tile.asset,
      fallbackIcon: tile.fallbackIcon,
      height: row ? 44 : 58,
      width: row ? 56 : double.infinity,
      alignment: row ? Alignment.center : Alignment.centerLeft,
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tile.title, maxLines: 2, style: TogetherStyle.tileTitle()),
        const SizedBox(height: 2),
        Text(tile.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TogetherStyle.listMeta()),
      ],
    );
    final chevron =
        Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted);

    return Semantics(
      container: true,
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: TogetherStyle.tileFill(tile.tint),
          borderRadius: BorderRadius.circular(TogetherStyle.tileRadius),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(TogetherStyle.tileRadius),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: row
                  ? Row(children: [
                      art,
                      const SizedBox(width: AppSpace.compact),
                      Expanded(child: words),
                      chevron,
                    ])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        art,
                        const SizedBox(height: AppSpace.xs),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: words),
                            chevron,
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

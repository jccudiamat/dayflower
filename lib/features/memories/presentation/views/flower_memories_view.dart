import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/flower_image.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../tulip/domain/flower_catalog.dart';
import '../../data/memories_assets.dart';
import '../../data/memory_views.dart';
import '../../data/relationship_memory.dart';
import '../widgets/memory_category_tabs.dart';
import '../widgets/memory_tile.dart';

/// Flowers: your garden. Every flower either of you sent, grown together.
///
/// A painted garden across the top, then the collection itself: each
/// flower as a small botanical card, showing the flower that was actually
/// sent, never as a row in a list.
class FlowerMemoriesView extends StatefulWidget {
  const FlowerMemoriesView({super.key, required this.flowers});

  /// Newest first. Each carries its message.
  final List<RelationshipMemory> flowers;

  @override
  State<FlowerMemoriesView> createState() => _FlowerMemoriesViewState();
}

class _FlowerMemoriesViewState extends State<FlowerMemoriesView> {
  /// The family being shown; null for all of them.
  String? _family;

  /// How many families get a chip of their own before "More".
  static const _shown = 3;

  @override
  Widget build(BuildContext context) {
    final flowers = widget.flowers;
    final families = flowerFamilies([for (final f in flowers) f.message!]);
    final visible = _family == null
        ? flowers
        : [
            for (final f in flowers)
              if (flowerFamily(f.message!) == _family) f,
          ];
    final rest = families.skip(_shown).toList();
    final inRest = rest.any((f) => f.$1 == _family);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MemorySectionHeader(
          title: 'Our Garden',
          meta: '${flowers.length} flower${flowers.length == 1 ? '' : 's'} '
              'grown together',
          action: 'See all',
          onAction: () => context.push(Routes.blooms),
        ),
        const SizedBox(height: AppSpace.compact),
        const GardenHero(),
        if (flowers.isEmpty)
          MemoryEmpty(title: MemoryCategory.flowers.emptyTitle)
        else ...[
          const SizedBox(height: AppSpace.compact),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _TypeChip(
                label: 'All (${flowers.length})',
                selected: _family == null,
                onTap: () => setState(() => _family = null),
              ),
              for (final (family, count) in families.take(_shown))
                _TypeChip(
                  label: '$family ($count)',
                  selected: _family == family,
                  onTap: () => setState(() => _family = family),
                ),
              if (rest.isNotEmpty)
                Builder(
                  builder: (chipContext) => _TypeChip(
                    // Once one of the rest is picked, the chip names it.
                    label: inRest
                        ? '$_family (${rest.firstWhere((f) => f.$1 == _family).$2})'
                        : 'More',
                    selected: inRest,
                    trailing: CupertinoIcons.chevron_down,
                    onTap: () => _pickMore(chipContext, rest),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: AppSpace.compact),
          FlowerMemoryGrid(flowers: visible),
        ],
      ],
    );
  }

  Future<void> _pickMore(
      BuildContext chipContext, List<(String, int)> rest) async {
    final box = chipContext.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(chipContext).context.findRenderObject()! as RenderBox;
    final at = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    final picked = await showMenu<String>(
      context: chipContext,
      position: RelativeRect.fromLTRB(
          at.dx, at.dy + 4, overlay.size.width - at.dx, 0),
      color: AppColors.surface,
      items: [
        for (final (family, count) in rest)
          PopupMenuItem(
            value: family,
            child: Text('$family ($count)', style: AppText.body(AppColors.ink)),
          ),
      ],
    );
    if (picked != null && mounted) setState(() => _family = picked);
  }
}

/// A flower-type filter: smaller than the categories above it, because it
/// answers to them.
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: selected ? AppColors.brand : AppColors.surface,
            shape: StadiumBorder(
              side: BorderSide(
                  color: selected ? AppColors.brand : AppColors.border),
            ),
            child: InkWell(
              onTap: onTap,
              customBorder: const StadiumBorder(),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(label,
                      style: AppText.caption(
                              selected ? Colors.white : AppColors.body)
                          .copyWith(fontWeight: FontWeight.w600)),
                  if (trailing != null) ...[
                    const SizedBox(width: 3),
                    AppIcon(trailing!,
                        size: 11,
                        color: selected ? Colors.white : AppColors.body),
                  ],
                ]),
              ),
            ),
          ),
        ),
      );
}

/// The garden across the top of Flowers, with the sign saying whose it is.
///
/// Drawn at the painting's own proportions, so the sign is never cropped.
/// If the painting cannot be read, a pastel wash holds its place.
class GardenHero extends StatelessWidget {
  const GardenHero({super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: MemoriesAssets.gardenAspect,
          child: Image.asset(
            MemoriesAssets.gardenHero,
            fit: BoxFit.cover,
            semanticLabel: 'A garden of our love',
            errorBuilder: (_, __, ___) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFBE4EC), Color(0xFFD5EACB)],
                ),
              ),
            ),
          ),
        ),
      );
}

/// The collection: a botanical card for each flower, three across where
/// there is room, two on a narrow phone.
class FlowerMemoryGrid extends ConsumerWidget {
  const FlowerMemoryGrid({super.key, required this.flowers});

  final List<RelationshipMemory> flowers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserIdProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final them = partner?.petName ?? partner?.displayName ?? 'your partner';
    return LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth >= 330 ? 3 : 2;
      const gap = MemoriesStyle.gap;
      final tile = (box.maxWidth - gap * (columns - 1)) / columns;
      final rows = <List<RelationshipMemory>>[
        for (var i = 0; i < flowers.length; i += columns)
          flowers.sublist(i, math.min(i + columns, flowers.length)),
      ];
      return Column(children: [
        for (final (r, row) in rows.indexed) ...[
          if (r > 0) const SizedBox(height: gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, memory) in row.indexed) ...[
                if (i > 0) const SizedBox(width: gap),
                SizedBox(
                  width: tile,
                  child: FlowerMemoryTile(
                    memory: memory,
                    from: memory.message!.senderId == me ? 'You' : them,
                    width: tile,
                  ),
                ),
              ],
            ],
          ),
        ],
      ]);
    });
  }
}

/// One flower, as a small botanical card.
class FlowerMemoryTile extends StatelessWidget {
  const FlowerMemoryTile({
    super.key,
    required this.memory,
    required this.from,
    required this.width,
  });

  final RelationshipMemory memory;
  final String from;
  final double width;

  @override
  Widget build(BuildContext context) {
    final m = memory.message!;
    // A website bouquet has no catalogue flower; it is drawn as one.
    final flower = m.flower ?? FlowerCatalog.byId('bouquet');
    final note = (m.note ?? '').trim();
    final scale = MediaQuery.textScalerOf(context);
    // Two lines kept for the note on every card, written or not, so a row
    // of cards ends level.
    final noteHeight = scale.scale(11.5) * 1.3 * 2 + 2;
    final art = width - 16;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(MemoriesStyle.tileRadius),
      child: InkWell(
        onTap: () => openMemory(context, memory),
        borderRadius: BorderRadius.circular(MemoriesStyle.tileRadius),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MemoriesStyle.tileRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: art,
                height: art,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: flower.color.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FlowerImage(
                    flower: flower, size: flower.cutout ? art * .92 : art,
                    radius: 10),
              ),
              const SizedBox(height: 7),
              Text(m.isBouquet ? 'Bouquet' : flower.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MemoriesStyle.tileTitle()),
              Text('From $from',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MemoriesStyle.tileMeta()),
              Text(DateFormat('d MMM y').format(m.sentAt),
                  maxLines: 1, style: MemoriesStyle.tileMeta()),
              const SizedBox(height: 4),
              SizedBox(
                height: noteHeight,
                child: note.isEmpty
                    ? null
                    : Text('“$note”',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MemoriesStyle.tileNote()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

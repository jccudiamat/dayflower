import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/flower_image.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../data/memories_assets.dart';
import '../../data/relationship_memory.dart';
import '../../../../core/widgets/storage_image.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MemoryArtwork extends ConsumerWidget {
  const MemoryArtwork({super.key, required this.memory, required this.size});
  final RelationshipMemory memory;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = memory.message;
    if (m?.flower != null) return FlowerImage(flower: m!.flower!, size: size);
    final path = m?.imagePath;
    // A bouquet card is a public page on the website; everything else with
    // a picture is a private object, drawn through the path cache.
    final url = path == null ? m?.bouquetCardUrl : null;
    final icon = switch (memory.kind) {
      MemoryKind.photos || MemoryKind.booth => CupertinoIcons.photo,
      MemoryKind.flowers => CupertinoIcons.gift,
      MemoryKind.cards => CupertinoIcons.envelope,
      MemoryKind.journal => CupertinoIcons.book,
      MemoryKind.places => CupertinoIcons.map,
      MemoryKind.events => CupertinoIcons.calendar,
    };
    final iconTile = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: AppColors.blush,
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: AppIcon(icon, color: AppColors.brand, size: size * .4));
    // A picture for what has none of its own: a journal entry, a card whose
    // image cannot be read, a bouquet from the website before its card
    // loads. Only kinds with nothing better to show; a place or an event
    // keeps its icon rather than borrowing somebody else's picture.
    final art = switch (memory.kind) {
      MemoryKind.journal => MemoriesAssets.timelineJournal,
      MemoryKind.cards => MemoriesAssets.timelineCard,
      MemoryKind.flowers => MemoriesAssets.timelineBouquet,
      _ => null,
    };
    final fallback = art == null
        ? iconTile
        : ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.asset(art,
                width: size,
                height: size,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => iconTile));
    final fit = size > 120 ? BoxFit.contain : BoxFit.cover;
    if (path != null) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: StorageImage.dayPhoto(path,
              width: size,
              height: size,
              fit: fit,
              decodeWidth: size,
              semanticLabel: memory.title,
              error: (_) => fallback));
    }
    if (url == null) return fallback;
    return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: CachedNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: fit,
            errorWidget: (_, __, ___) => fallback));
  }
}

void openMemory(BuildContext context, RelationshipMemory memory) {
  Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _MemoryDetail(memory: memory)));
}

class _MemoryDetail extends ConsumerWidget {
  const _MemoryDetail({required this.memory});
  final RelationshipMemory memory;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = memory.message;
    final mine = m?.senderId == ref.watch(currentUserIdProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    return Scaffold(
        appBar: AppBar(title: Text(memory.title)),
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.all(AppSpace.screenInset),
                children: [
              Center(
                  child: MemoryArtwork(
                      memory: memory,
                      size: (MediaQuery.sizeOf(context).width - 40)
                          .clamp(160, 420))),
              const SizedBox(height: AppSpace.md),
              Text(memory.title, style: AppText.hero()),
              const SizedBox(height: AppSpace.xs),
              Text(
                  DateFormat(m == null ? 'd MMMM y' : 'd MMMM y · h:mm a')
                      .format(memory.date),
                  style: AppText.caption()),
              if (m != null)
                Text(
                    mine
                        ? 'From you'
                        : 'From ${partner?.petName ?? partner?.displayName ?? 'your partner'}',
                    style: AppText.body()),
              if (m?.flower != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(m!.flower!.meaning, style: AppText.body())
              ],
              const SizedBox(height: AppSpace.md),
              Text(memory.body, style: AppText.note()),
              if (m == null || memory.kind == MemoryKind.places)
                TextButton(
                    onPressed: () => context.push(memory.route),
                    child: Text(memory.kind == MemoryKind.places
                        ? 'Open our map'
                        : memory.kind == MemoryKind.events
                            ? 'Open our events'
                            : 'Open our journal')),
              if (m?.bouquetUrl != null)
                TextButton(
                    onPressed: () async {
                      final opened = await launchUrl(Uri.parse(m!.bouquetUrl!));
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'The bouquet couldn’t open. Please try again.')));
                      }
                    },
                    child: const Text('Open your bouquet')),
            ])));
  }
}

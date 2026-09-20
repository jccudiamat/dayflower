import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_router.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/flower_image.dart';
import '../../../core/widgets/story_components.dart';
import '../../booth/data/strip_repository.dart';
import '../../chapters/data/chapter_repository.dart';
import '../../onboarding/data/user_repository.dart';
import '../../pairing/data/pair_repository.dart';
import '../../tulip/data/flower_repository.dart';
import '../../tulip/domain/flower_catalog.dart';
import '../../tulip/presentation/widgets/flower_catalog_panel.dart';
import '../../memories/presentation/widgets/memory_tile.dart';
import '../../memories/data/relationship_memory.dart';
import 'make_card_screen.dart';

class DayflowerScreen extends ConsumerWidget {
  const DayflowerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final flowers = ref.watch(flowerMessagesProvider);
    final blooms = (flowers.valueOrNull ?? [])
        .where((m) => m.flower != null || m.isBouquet)
        .toList();
    final goals = ref.watch(currentMonthGoalsProvider);
    final awaiting = ref.watch(stripAwaitingMeProvider);
    final review = ref.watch(unwrittenChapterProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final name = partner?.petName ?? partner?.displayName ?? 'Your partner';
    final stem = FlowerCatalog.byId('stem_tulip');
    return StoryScaffold(
        title: 'Dayflower',
        subtitle: 'Make a little something for each other.',
        children: [
          if (awaiting != null) ...[
            UtilityRow(
                icon: CupertinoIcons.camera,
                title: '$name saved you a spot',
                subtitle: 'A photo strip is waiting. Add your photo.',
                onTap: () => context.push(Routes.booth)),
            const SizedBox(height: AppSpace.sm)
          ],
          const StorySection('Today'),
          LayoutBuilder(builder: (context, box) {
            final single = box.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(16) > 24;
            final width =
                single ? box.maxWidth : (box.maxWidth - AppSpace.xs) / 2;
            final actions = <Widget>[
              CreationTile(
                  title: 'Send a flower',
                  subtitle: 'Let them know you’re thinking of them.',
                  art: FlowerImage(flower: stem, size: 72),
                  onTap: () => showDayflowerPicker(context, ref)),
              CreationTile(
                  title: 'Create a bouquet',
                  subtitle: 'Make something special.',
                  art: const AppIcon(CupertinoIcons.gift,
                      size: 56, color: AppColors.brand),
                  onTap: () async {
                    var opened = false;
                    try {
                      opened = await launchUrl(
                          Uri.parse('https://mydayflower.com/bouquet'),
                          mode: LaunchMode.externalApplication);
                    } catch (_) {
                      opened = false;
                    }
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'The flower shop could not open. Please try again.')));
                    }
                  }),
              CreationTile(
                  title: 'Make a card',
                  subtitle: 'Send something from the heart.',
                  art: const AppIcon(CupertinoIcons.envelope,
                      size: 56, color: AppColors.brand),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const MakeCardScreen()))),
              CreationTile(
                  title: 'Photo Booth',
                  subtitle: 'Take photos together.',
                  art: const AppIcon(CupertinoIcons.camera,
                      size: 56, color: AppColors.brand),
                  onTap: () => context.push(Routes.booth)),
            ];
            if (single) {
              return Column(children: [
                for (final action in actions)
                  Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xs),
                      child: SizedBox(width: width, child: action))
              ]);
            }
            return Column(children: [
              for (var i = 0; i < actions.length; i += 2) ...[
                if (i > 0) const SizedBox(height: AppSpace.xs),
                IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Expanded(child: actions[i]),
                      const SizedBox(width: AppSpace.xs),
                      Expanded(child: actions[i + 1]),
                    ])),
              ]
            ]);
          }),
          const StorySection('This month'),
          UtilityRow(
              icon: CupertinoIcons.book,
              title: '${DateFormat.MMMM().format(now)} Journal',
              subtitle: goals.isEmpty
                  ? 'Start this month’s story.'
                  : '${goals.length} goals · ${DateTime(now.year, now.month + 1, 0).day - now.day} days left',
              onTap: () =>
                  context.push(Routes.chapterFor(now.year, now.month))),
          if (review != null) ...[
            const SizedBox(height: AppSpace.xs),
            UtilityRow(
                icon: CupertinoIcons.pencil,
                title:
                    '${DateFormat.MMMM().format(review.firstDay)} is complete',
                subtitle: 'Look back at your month. Write our review.',
                onTap: () =>
                    context.push(Routes.chapterFor(review.year, review.month)))
          ],
          StorySection('Your Garden',
              action: 'See all', onTap: () => context.push(Routes.blooms)),
          if (flowers.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (flowers.hasError)
            Text('Your garden couldn’t load. Please try again.',
                style: AppText.body())
          else if (blooms.isEmpty)
            StoryEmptyState(
                title: 'Your garden starts with one flower.',
                body: 'Send your first Dayflower.',
                action: TextButton(
                    onPressed: () => showDayflowerPicker(context, ref),
                    child: const Text('Send a flower')))
          else ...[
            Text(
                '${blooms.length} ${blooms.length == 1 ? 'flower' : 'flowers'} grown together',
                style: AppText.body()),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
                height: 116,
                child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: blooms.length.clamp(0, 12),
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpace.xs),
                    itemBuilder: (context, i) {
                      final m = blooms[i];
                      return Semantics(
                          label: m.flower?.name ?? 'Bouquet',
                          button: true,
                          child: InkWell(
                              onTap: () => openMemory(
                                  context,
                                  RelationshipMemory(
                                      id: m.id,
                                      kind: MemoryKind.flowers,
                                      date: m.sentAt,
                                      title:
                                          m.flower?.name ?? 'A bouquet for you',
                                      body: m.note ?? '',
                                      route: Routes.chat,
                                      message: m)),
                              child: m.flower == null
                                  ? const AppIcon(CupertinoIcons.gift,
                                      size: 80, color: AppColors.brand)
                                  : FlowerImage(flower: m.flower!, size: 96)));
                    })),
          ],
        ]);
  }
}

Future<void> showDayflowerPicker(BuildContext context, WidgetRef ref) async {
  final flower = await showModalBottomSheet<Flower>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
          child: FlowerCatalogPanel(
              height: MediaQuery.sizeOf(sheetContext).height * .65,
              onPick: (flower) => Navigator.pop(sheetContext, flower))));
  if (flower == null || !context.mounted) return;
  final partner = ref.read(partnerProfileProvider).valueOrNull;
  final result = await showFlowerSendSheet(context,
      flower: flower,
      partnerName: partner?.petName ?? partner?.displayName ?? 'your partner');
  if (result == null || !context.mounted) return;
  final pair = ref.read(currentPairProvider).valueOrNull;
  final user = ref.read(currentUserIdProvider);
  if (pair == null || user == null) return;
  try {
    await ref.read(flowerRepositoryProvider).sendFlower(
        pairId: pair.id,
        senderId: user,
        flowerType: flower.id,
        note: result.note,
        toWidget: result.toWidget);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A little love, sent. Your garden is growing.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Your flower couldn’t send. Please try again.'),
          action: SnackBarAction(
              label: 'Try again',
              onPressed: () => showDayflowerPicker(context, ref))));
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/story_components.dart';
import '../../../memories/data/relationship_memory.dart';
import '../../../memories/presentation/widgets/memory_tile.dart';
import '../../data/flower_repository.dart';

class BloomsScreen extends ConsumerWidget {
  const BloomsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(flowerMessagesProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Your Garden')),
        body: SafeArea(
            child: messages.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => StoryEmptyState(
                    title: 'Your garden couldn’t load.',
                    body: 'Please try again.',
                    action: TextButton(
                        onPressed: () => ref.invalidate(flowerMessagesProvider),
                        child: const Text('Try again'))),
                data: (all) {
                  final flowers = buildRelationshipMemories(
                          messages: all, chapters: [], moments: [], places: [])
                      .where((m) => m.kind == MemoryKind.flowers)
                      .toList();
                  if (flowers.isEmpty) {
                    return StoryEmptyState(
                        title: 'Your garden starts with one flower.',
                        body: 'Send your first Dayflower.',
                        action: TextButton(
                            onPressed: () => context.go(Routes.dayflower),
                            child: const Text('Send a flower')));
                  }
                  final groups = <String, List<RelationshipMemory>>{};
                  for (final flower in flowers) {
                    groups
                        .putIfAbsent(
                            DateFormat('MMMM y').format(flower.date), () => [])
                        .add(flower);
                  }
                  return ListView(
                      padding: const EdgeInsets.all(AppSpace.screenInset),
                      children: [
                        Text(
                            '${flowers.length} ${flowers.length == 1 ? 'flower blooming' : 'flowers blooming'} between you',
                            style: AppText.title()),
                        const SizedBox(height: AppSpace.sm),
                        Text('Small things, growing into our story.',
                            style: AppText.body()),
                        for (final group in groups.entries) ...[
                          StorySection(group.key),
                          Wrap(
                              spacing: AppSpace.xs,
                              runSpacing: AppSpace.sm,
                              children: [
                                for (final m in group.value)
                                  Semantics(
                                      label: m.title,
                                      button: true,
                                      child: InkWell(
                                          onTap: () => openMemory(context, m),
                                          child: SizedBox(
                                              width: 96,
                                              child: Column(children: [
                                                MemoryArtwork(
                                                    memory: m, size: 96),
                                                const SizedBox(
                                                    height: AppSpace.xxs),
                                                Text(
                                                    DateFormat('d MMM')
                                                        .format(m.date),
                                                    style: AppText.caption()),
                                              ])))),
                              ]),
                        ],
                      ]);
                })));
  }
}

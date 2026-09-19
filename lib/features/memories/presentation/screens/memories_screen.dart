import '../../../dates/data/event_repository.dart';
import '../../../tulip/data/flower_repository.dart';
import '../../../chapters/data/chapter_repository.dart';
import '../../../travel/data/map_pin_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/story_components.dart';
import '../../data/relationship_memory.dart';
import '../widgets/memory_tile.dart';

class MemoriesScreen extends ConsumerStatefulWidget {
  const MemoriesScreen({super.key});
  @override
  ConsumerState<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends ConsumerState<MemoriesScreen> {
  MemoryKind? _filter;
  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(relationshipMemoriesProvider);
    return StoryScaffold(
        title: 'Memories',
        subtitle: 'Little moments. Yours to keep.',
        children: [
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final kind in <MemoryKind?>[null, ...MemoryKind.values])
                  Padding(
                      padding: const EdgeInsets.only(right: AppSpace.xs),
                      child: ChoiceChip(
                          label: Text(kind == null
                              ? 'All'
                              : '${kind.name[0].toUpperCase()}${kind.name.substring(1)}'),
                          selected: _filter == kind,
                          onSelected: (_) => setState(() => _filter = kind))),
              ])),
          const SizedBox(height: AppSpace.sm),
          memories.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => StoryEmptyState(
                  title: 'Your story couldn’t load.',
                  body: 'Please check your connection and try again.',
                  action: TextButton(
                      onPressed: () {
                        ref.invalidate(flowerMessagesProvider);
                        ref.invalidate(monthlyChaptersProvider);
                        ref.invalidate(chapterMomentsProvider);
                        ref.invalidate(mapPinsProvider);
                        ref.invalidate(customEventsProvider);
                      },
                      child: const Text('Try again'))),
              data: (all) {
                final filtered = all
                    .where((m) => _filter == null || m.kind == _filter)
                    .toList();
                if (filtered.isEmpty) {
                  return StoryEmptyState(
                      title: 'Your story will grow here.',
                      body:
                          'Photos, flowers and little moments you keep will appear here.',
                      action: TextButton(
                          onPressed: () => context.go(Routes.dayflower),
                          child: const Text('Make a little something')));
                }
                return Column(children: [
                  for (var i = 0; i < filtered.length; i++) ...[
                    if (i == 0 ||
                        filtered[i].date.year != filtered[i - 1].date.year ||
                        filtered[i].date.month != filtered[i - 1].date.month)
                      StorySection(
                          DateFormat('MMMM y').format(filtered[i].date)),
                    MemoryTile(memory: filtered[i]),
                  ]
                ]);
              }),
        ]);
  }
}

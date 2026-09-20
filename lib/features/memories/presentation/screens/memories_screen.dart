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
          _FilterBar(
              selected: _filter,
              onSelected: (kind) => setState(() => _filter = kind)),
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

/// The filter pills.
///
/// ⚠️ There are seven of them and they do not fit on a 390pt screen, so the
/// row scrolls. The naive version clipped the seventh mid-word against the
/// scaffold's inset with nothing to say it could move, which reads as a
/// layout bug rather than as an affordance. This fades the trailing edge
/// while there is more to reach, and drops the fade once you get there.
class _FilterBar extends StatefulWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final MemoryKind? selected;
  final ValueChanged<MemoryKind?> onSelected;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  final _controller = ScrollController();
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sync);
    // The extent is unknown until the first layout, so ask again after it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (!_controller.hasClients) return;
    final more = _controller.offset < _controller.position.maxScrollExtent - 1;
    if (more != _more) setState(() => _more = more);
  }

  @override
  void dispose() {
    _controller.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  static String _label(MemoryKind kind) =>
      '${kind.name[0].toUpperCase()}${kind.name.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final row = SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        // Lets the last pill clear the scaffold inset instead of sitting
        // hard against it.
        padding: const EdgeInsets.only(right: AppSpace.screenInset),
        child: Row(children: [
          for (final kind in <MemoryKind?>[null, ...MemoryKind.values])
            Padding(
                padding: const EdgeInsets.only(right: AppSpace.xs),
                child: ChoiceChip(
                    label: Text(kind == null ? 'All' : _label(kind)),
                    selected: widget.selected == kind,
                    onSelected: (_) => widget.onSelected(kind))),
        ]));

    if (!_more) return row;
    return ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            // Opaque until the last stretch, so only the overflowing pill
            // softens rather than the whole row losing contrast.
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0, 0.88, 1]).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: row);
  }
}

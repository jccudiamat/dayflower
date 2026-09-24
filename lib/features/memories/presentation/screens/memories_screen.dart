import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/story_components.dart';
import '../../../chapters/data/chapter_repository.dart';
import '../../../dates/data/event_repository.dart';
import '../../../travel/data/map_pin_repository.dart';
import '../../../tulip/data/flower_repository.dart';
import '../../data/memory_views.dart';
import '../../data/relationship_memory.dart';
import '../views/all_memories_view.dart';
import '../views/card_memories_view.dart';
import '../views/flower_memories_view.dart';
import '../views/journal_memories_view.dart';
import '../views/photo_memories_view.dart';
import '../views/place_memories_view.dart';
import '../widgets/memory_category_tabs.dart';

/// Memories: the relationship's kept history. Dayflower makes; Memories
/// keeps.
///
/// 🔴 **Six ways of looking, not one list six ways filtered.** It was a
/// single timeline with filter pills, so a photo, a card and a place all
/// read as the same row. Each category now has the view its kind of memory
/// wants: All is a timeline, Photos a photo wall, Flowers a garden, Cards a
/// box of letters, Journal a bookshelf, Places a map. Each is its own
/// widget in `views/`; this screen only chooses.
///
/// ⚠️ Search is All's alone, and the header has no avatar. Both are
/// deliberate departures from the reference the design was drawn from.
class MemoriesScreen extends ConsumerStatefulWidget {
  const MemoriesScreen({super.key});
  @override
  ConsumerState<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends ConsumerState<MemoriesScreen> {
  MemoryCategory _category = MemoryCategory.all;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(relationshipMemoriesProvider);
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(MemoriesStyle.gutter, AppSpace.xs,
              MemoriesStyle.gutter, AppSpace.lg),
          children: [
            _Header(category: _category),
            const SizedBox(height: 14),
            // ⚠️ A slot for search whether it shows or not. Dropping it off
            // the list shifted everything after it by one, and the list
            // rebuilt the category row from scratch, losing its scroll.
            _category == MemoryCategory.all
                ? Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.compact),
                    child: MemorySearchField(
                      controller: _search,
                      onChanged: (q) => setState(() => _query = q),
                    ),
                  )
                : const SizedBox.shrink(),
            MemoryCategoryTabs(
              selected: _category,
              onSelected: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 20),
            memories.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: AppSpace.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
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
                  child: const Text('Try again'),
                ),
              ),
              data: _body,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(List<RelationshipMemory> all) {
    switch (_category) {
      case MemoryCategory.all:
        if (all.isEmpty) {
          return MemoryEmpty(
              title: MemoryCategory.all.emptyTitle,
              body: MemoryCategory.all.emptyBody);
        }
        final shown = [for (final m in all) if (memoryMatches(m, _query)) m];
        if (shown.isEmpty) {
          return MemoryEmpty(
              title: 'Nothing matches “${_query.trim()}”.',
              body: 'Try a flower, a place, a word you wrote, or a month.');
        }
        return AllMemoriesTimeline(
          memories: shown,
          books: {
            for (final b in _books()) 'journal:${b.chapter.id}': b,
          },
        );
      case MemoryCategory.photos:
        final strips = {
          for (final m in all)
            if (m.kind == MemoryKind.booth && m.message != null) m.message!.id,
        };
        return PhotoMemoryGrid(
          photos: photoMemories(all),
          isStrip: (m) => strips.contains(m.id),
        );
      case MemoryCategory.flowers:
        return FlowerMemoriesView(flowers: [
          for (final m in all)
            if (m.kind == MemoryKind.flowers && m.message != null) m,
        ]);
      case MemoryCategory.cards:
        return CardMemoryGrid(cards: cardMemories(all));
      case MemoryCategory.journal:
        return JournalBookGrid(books: _books());
      case MemoryCategory.places:
        return PlaceMemoriesView(
          pins: ref.watch(mapPinsProvider).valueOrNull ?? const [],
          messages: ref.watch(flowerMessagesProvider).valueOrNull ?? const [],
        );
    }
  }

  /// Finished months, with their goal and highlight counts.
  List<JournalBook> _books() => journalBooks(
        ref.watch(monthlyChaptersProvider).valueOrNull ?? const [],
        ref.watch(monthlyGoalsProvider).valueOrNull ?? const [],
        ref.watch(chapterMomentsProvider).valueOrNull ?? const [],
      );
}

/// "Memories", and what the chosen category is for. Nothing on the right:
/// no avatar, no shortcut. The page is about the two of you, not a profile.
class _Header extends StatelessWidget {
  const _Header({required this.category});

  final MemoryCategory category;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shrinks rather than truncates at large text sizes.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('Memories',
                maxLines: 1,
                softWrap: false,
                style: MemoriesStyle.pageTitle()),
          ),
          const SizedBox(height: 3),
          Row(children: [
            Flexible(
              child: Text(category.subtitle,
                  style: MemoriesStyle.pageSubtitle()),
            ),
            const SizedBox(width: 5),
            AppIcon(CupertinoIcons.heart, size: 14, color: AppColors.muted),
          ]),
        ],
      );
}

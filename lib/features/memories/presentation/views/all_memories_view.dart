import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../tulip/presentation/widgets/media_viewer.dart';
import '../../data/memory_views.dart';
import '../../data/relationship_memory.dart';
import '../widgets/memory_tile.dart';

/// All: the relationship's history as one timeline, newest first.
///
/// A date on the left, a thin thread with a small node for each memory,
/// and the memory itself on a soft card. Every kind in one line of time,
/// because that is how it happened: a flower, then a photo, then a card.
class AllMemoriesTimeline extends ConsumerWidget {
  const AllMemoriesTimeline({
    super.key,
    required this.memories,
    this.books = const {},
  });

  final List<RelationshipMemory> memories;

  /// Finished months by their memory id ("journal:<chapter id>"), for a
  /// chapter's goal and highlight counts.
  ///
  /// ⚠️ Not by the memory's date: a chapter is dated the day it was closed,
  /// which is usually the month after the one it is about.
  final Map<String, JournalBook> books;

  /// The date column, and the rail the thread runs down.
  static const _dateWidth = 58.0;
  static const _railWidth = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserIdProvider);
    return Stack(children: [
      // One thread for the whole timeline, behind the nodes.
      Positioned(
        left: _dateWidth + _railWidth / 2 - .75,
        top: 20,
        bottom: 20,
        width: 1.5,
        child: ColoredBox(color: MemoriesStyle.timelineLine),
      ),
      Column(children: [
        for (final memory in memories)
          MemoryTimelineItem(
            memory: memory,
            mine: memory.message != null && memory.message!.senderId == me,
            book: books[memory.id],
          ),
      ]),
    ]);
  }
}

/// One memory on the timeline.
class MemoryTimelineItem extends ConsumerWidget {
  const MemoryTimelineItem({
    super.key,
    required this.memory,
    required this.mine,
    this.book,
  });

  final RelationshipMemory memory;
  final bool mine;

  /// The month's book, when this is a finished chapter.
  final JournalBook? book;

  String get _kind {
    final m = memory.message;
    return switch (memory.kind) {
      MemoryKind.flowers => m != null && m.isBouquet
          ? (mine ? 'You sent a bouquet' : 'You received a bouquet')
          : (mine ? 'You sent a flower' : 'You received a flower'),
      MemoryKind.cards => mine ? 'You sent a card' : 'You received a card',
      MemoryKind.photos => 'Photo',
      MemoryKind.booth => 'Photo strip',
      MemoryKind.journal => 'Journal',
      MemoryKind.places => 'Place',
      MemoryKind.events => 'A day together',
    };
  }

  String get _title {
    final note = (memory.message?.note ?? '').trim();
    // A photo is named by what was written with it.
    if (memory.kind == MemoryKind.photos) {
      return note.isEmpty ? 'A little moment' : note;
    }
    return memory.title;
  }

  /// The line under the title, and whether it is somebody's own words.
  (String, bool) get _subtitle {
    final body = memory.body.trim();
    switch (memory.kind) {
      case MemoryKind.flowers:
        final note = (memory.message?.note ?? '').trim();
        return note.isNotEmpty
            ? ('“$note”', true)
            : (memory.message?.flower?.meaning ?? '', false);
      case MemoryKind.cards:
        return body.isEmpty ? ('', false) : ('“$body”', true);
      case MemoryKind.photos:
      case MemoryKind.booth:
        return ('', false);
      case MemoryKind.journal:
        final b = book;
        if (memory.id.startsWith('journal:') && b != null) {
          return (_counts(b), false);
        }
        return (body, false);
      case MemoryKind.places:
      case MemoryKind.events:
        return (body, false);
    }
  }

  static String _counts(JournalBook b) => [
        '${b.highlights} highlight${b.highlights == 1 ? '' : 's'}',
        '${b.goals} goal${b.goals == 1 ? '' : 's'}',
      ].join(' · ');

  IconData get _icon => switch (memory.kind) {
        MemoryKind.flowers => CupertinoIcons.heart_fill,
        MemoryKind.cards => CupertinoIcons.envelope,
        MemoryKind.photos || MemoryKind.booth => CupertinoIcons.photo,
        MemoryKind.journal => CupertinoIcons.book,
        MemoryKind.places => CupertinoIcons.location,
        MemoryKind.events => CupertinoIcons.calendar,
      };

  Color get _tint => switch (memory.kind) {
        MemoryKind.flowers || MemoryKind.cards => MemoriesStyle.givenTint,
        MemoryKind.journal => MemoriesStyle.journalTint,
        _ => AppColors.surface,
      };

  void _open(BuildContext context, WidgetRef ref) {
    final m = memory.message;
    if (m?.imagePath != null &&
        memory.kind != MemoryKind.flowers) {
      showPhotoMessage(context, ref, m!);
    } else if (memory.kind == MemoryKind.journal) {
      context.push(memory.route);
    } else {
      openMemory(context, memory);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (subtitle, quoted) = _subtitle;
    final given = memory.kind == MemoryKind.flowers ||
        memory.kind == MemoryKind.cards;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AllMemoriesTimeline._dateWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('d').format(memory.date),
                      style: MemoriesStyle.timelineDay()),
                  const SizedBox(height: 2),
                  Text(DateFormat('MMM y').format(memory.date),
                      style: MemoriesStyle.timelineMonth()),
                ],
              ),
            ),
          ),
          SizedBox(
            width: AllMemoriesTimeline._railWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: given
                            ? AppColors.brand.withValues(alpha: .45)
                            : AppColors.secondary.withValues(alpha: .35),
                        width: 1.2),
                  ),
                  child: AppIcon(_icon,
                      size: 11,
                      color: given ? AppColors.brand : AppColors.secondary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Material(
              color: _tint,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _open(context, ref),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_kind, style: MemoriesStyle.itemKind()),
                          const SizedBox(height: 2),
                          Text(_title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: MemoriesStyle.itemTitle()),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: quoted
                                    ? MemoriesStyle.itemNote()
                                    : MemoriesStyle.itemMeta()),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    MemoryArtwork(memory: memory, size: 58),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

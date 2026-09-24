import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../tulip/domain/flower_catalog.dart';
import '../../data/memories_assets.dart';
import '../../data/memory_views.dart';
import '../widgets/memory_category_tabs.dart';

/// Journal: a bookshelf, one book for each month you finished together.
///
/// Only closed chapters: the month still being written belongs to
/// Dayflower, which is where it is made. A book opens that month's review.
/// The covers name the month and not the year, so each year is a shelf of
/// its own under its number.
class JournalBookGrid extends StatelessWidget {
  const JournalBookGrid({super.key, required this.books});

  /// Newest first.
  final List<JournalBook> books;

  @override
  Widget build(BuildContext context) {
    final years = <int, List<JournalBook>>{};
    for (final book in books) {
      years.putIfAbsent(book.chapter.year, () => []).add(book);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MemorySectionHeader(
          title: 'Our Journal',
          action: 'See all',
          onAction: () => context.push(Routes.chapters),
        ),
        const SizedBox(height: AppSpace.compact),
        if (books.isEmpty)
          MemoryEmpty(title: MemoryCategory.journal.emptyTitle)
        else
          LayoutBuilder(builder: (context, box) {
            final columns = box.maxWidth >= 330 ? 3 : 2;
            const gap = 10.0;
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (y, entry) in years.entries.indexed) ...[
                  if (y > 0) const SizedBox(height: AppSpace.md),
                  Text('${entry.key}',
                      style: MemoriesStyle.sectionMeta()
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpace.xs),
                  for (var i = 0; i < entry.value.length; i += columns) ...[
                    if (i > 0) const SizedBox(height: 14),
                    Row(children: [
                      for (final (j, book) in entry.value
                          .sublist(i, math.min(i + columns, entry.value.length))
                          .indexed) ...[
                        if (j > 0) const SizedBox(width: gap),
                        JournalBookCover(book: book, width: width),
                      ],
                    ]),
                  ],
                ],
              ],
            );
          }),
      ],
    );
  }
}

/// A finished month as a book: that month's painted cover, and what was in
/// it written where the cover leaves room for it.
class JournalBookCover extends StatelessWidget {
  const JournalBookCover({super.key, required this.book, required this.width});

  final JournalBook book;
  final double width;

  /// A book's proportions; the painted covers are within a hair of it.
  static const aspect = .70;

  static const _shape = BorderRadius.horizontal(
      left: Radius.circular(3), right: Radius.circular(7));

  String get counts => [
        '${book.goals} goal${book.goals == 1 ? '' : 's'}',
        '${book.highlights} highlight${book.highlights == 1 ? '' : 's'}',
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final height = width / aspect;
    final month = DateFormat.MMMM().format(book.month);
    final (labelAt, ink) = MemoriesAssets.coverLabel(book.chapter.month);
    return Semantics(
      button: true,
      label: '$month ${book.chapter.year}, $counts',
      child: GestureDetector(
        onTap: () => context.push(
            Routes.chapterFor(book.chapter.year, book.chapter.month)),
        child: ExcludeSemantics(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: _shape,
              boxShadow: AppElevation.card,
            ),
            child: ClipRRect(
              borderRadius: _shape,
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(
                  MemoriesAssets.cover(book.chapter.month),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _PaintedCover(month: book.chapter.month),
                ),
                // Where the painted "goals · highlights" was, in its ink,
                // with a soft glow so it reads over snow and water too.
                Positioned(
                  left: 6,
                  right: 6,
                  top: height * labelAt - 8,
                  height: 16,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      counts,
                      maxLines: 1,
                      softWrap: false,
                      style: MemoriesStyle.coverMeta(ink).copyWith(
                        fontSize: 10,
                        shadows: [
                          Shadow(
                              color: Colors.white.withValues(alpha: .85),
                              blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A cover drawn, for the moment a painted one cannot be read: its
/// season's colour, the month, and its birth flower.
class _PaintedCover extends StatelessWidget {
  const _PaintedCover({required this.month});

  final int month;

  /// Each month's cover and the ink written on it.
  static const _palette = [
    (Color(0xFFDCE8F5), Color(0xFF3E5873)), // January
    (Color(0xFFF6D9E4), Color(0xFF7A3E5A)), // February
    (Color(0xFFDDEFE0), Color(0xFF3E6A4A)), // March
    (Color(0xFFF8DDE6), Color(0xFF7C4460)), // April
    (Color(0xFFE3EDD8), Color(0xFF4F6A3D)), // May
    (Color(0xFFDCEAF7), Color(0xFF3D5C7E)), // June
    (Color(0xFFE4DDF6), Color(0xFF5A4A8A)), // July
    (Color(0xFFFBE3D6), Color(0xFF8A5238)), // August
    (Color(0xFFD6E9EA), Color(0xFF3D6468)), // September
    (Color(0xFFF6E3C9), Color(0xFF7E5A2E)), // October
    (Color(0xFFEDDDE0), Color(0xFF6E4652)), // November
    (Color(0xFFDCDDF2), Color(0xFF474C7E)), // December
  ];

  @override
  Widget build(BuildContext context) {
    final (cover, ink) = _palette[(month - 1).clamp(0, 11)];
    final flower = FlowerCatalog.byId(birthFlowerId(month));
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cover, Color.lerp(cover, ink, .12)!],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 28),
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(DateFormat.MMMM().format(DateTime(2000, month)),
                maxLines: 1,
                softWrap: false,
                style: MemoriesStyle.coverMonth(ink)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Image.asset(flower.asset,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ),
        ]),
      ),
    );
  }
}

import 'package:intl/intl.dart';

import '../../chapters/data/chapter_repository.dart';
import '../../travel/data/map_pin_repository.dart';
import '../../tulip/data/flower_repository.dart';
import '../../tulip/domain/flower_catalog.dart';
import 'relationship_memory.dart';

/// The six ways of looking back, and what the page says for each.
///
/// ⚠️ Not [MemoryKind]. Kinds are what a record is (a strip, an event);
/// categories are how Memories shows them. Strips are photos here, and
/// events appear only in All's timeline.
enum MemoryCategory {
  all('All', 'Little moments. Yours to keep.', 'Your story will grow here.',
      'Photos, flowers and little moments you keep will appear here.'),
  photos('Photos', 'The little moments you caught.',
      'Your captured moments will live here.', ''),
  flowers('Flowers', 'Every bloom you’ve grown together.',
      'Your garden starts with one flower.', ''),
  cards('Cards', 'Words worth keeping.',
      'Words worth keeping will appear here.', ''),
  journal('Journal', 'Your story, month by month.',
      'Completed chapters of your story will appear here.', ''),
  places('Places', 'Everywhere your story has been.',
      'The places you’ve shared will grow into your map.', '');

  const MemoryCategory(this.label, this.subtitle, this.emptyTitle,
      this.emptyBody);

  final String label;
  final String subtitle;
  final String emptyTitle;
  final String emptyBody;
}

// ── All: search ───────────────────────────────────────────────

/// Whether [memory] answers [query]: its title, what was written with it,
/// the flower's name, the place, and its date said a few ways ("19 Sep",
/// "September 2026").
///
/// Plain matching on what is already stored. Nothing here guesses meaning.
bool memoryMatches(RelationshipMemory memory, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final m = memory.message;
  final haystack = [
    memory.title,
    memory.body,
    m?.note,
    m?.flower?.name,
    DateFormat('d MMMM y').format(memory.date),
    DateFormat('d MMM y').format(memory.date),
    DateFormat('MMMM y').format(memory.date),
  ].whereType<String>().join('\n').toLowerCase();
  return q.split(RegExp(r'\s+')).every(haystack.contains);
}

// ── Photos ────────────────────────────────────────────────────

/// Every kept picture, newest first: day photos, photos sent in the chat,
/// and booth strips. Cards are pictures too, but they have their own box.
List<FlowerMessage> photoMemories(List<RelationshipMemory> memories) => [
      for (final m in memories)
        if ((m.kind == MemoryKind.photos || m.kind == MemoryKind.booth) &&
            m.message?.imagePath != null)
          m.message!,
    ];

/// [items] in month groups, newest month first, each newest first.
List<(DateTime, List<T>)> byMonth<T>(
    List<T> items, DateTime Function(T) dateOf) {
  final groups = <DateTime, List<T>>{};
  for (final item in items) {
    final d = dateOf(item).toLocal();
    groups.putIfAbsent(DateTime(d.year, d.month), () => []).add(item);
  }
  final months = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final month in months)
      (
        month,
        groups[month]!
          ..sort((a, b) => dateOf(b).compareTo(dateOf(a))),
      ),
  ];
}

/// One piece of the photo wall.
sealed class MosaicBlock {
  const MosaicBlock();
}

/// A wide picture two rows tall beside two small ones, stacked. [mirror]
/// puts the big one on the right, so consecutive blocks alternate.
class HeroBlock extends MosaicBlock {
  const HeroBlock(this.big, this.small, {this.mirror = false});
  final FlowerMessage big;
  final List<FlowerMessage> small;
  final bool mirror;
}

/// A booth strip standing tall on the right, up to four pictures beside it.
class StripBlock extends MosaicBlock {
  const StripBlock(this.strip, this.others);
  final FlowerMessage strip;
  final List<FlowerMessage> others;
}

/// One to three pictures side by side.
class RowBlock extends MosaicBlock {
  const RowBlock(this.photos);
  final List<FlowerMessage> photos;
}

/// Lays [photos] out as the wall's blocks, in order.
///
/// A hero leads, then the rhythm alternates: a strip block while strips
/// remain (a strip is tall and narrow, and cropped square it is just two
/// faces), otherwise a row, then another hero, mirrored. Controlled shapes,
/// never a grid of identical squares, never a single long column.
List<MosaicBlock> mosaicBlocks(
    List<FlowerMessage> photos, bool Function(FlowerMessage) isStrip) {
  final strips = [for (final p in photos) if (isStrip(p)) p];
  final others = [for (final p in photos) if (!isStrip(p)) p];
  final blocks = <MosaicBlock>[];
  var heroNext = true;
  var mirror = false;
  List<FlowerMessage> take(int n) {
    final taken = others.take(n).toList();
    others.removeRange(0, taken.length);
    return taken;
  }

  while (others.isNotEmpty || strips.isNotEmpty) {
    if (heroNext && others.length >= 3) {
      final three = take(3);
      blocks.add(HeroBlock(three.first, three.sublist(1), mirror: mirror));
      mirror = !mirror;
      heroNext = false;
    } else if (strips.isNotEmpty) {
      blocks.add(StripBlock(strips.removeAt(0), take(4)));
      heroNext = true;
    } else {
      blocks.add(RowBlock(take(3)));
      heroNext = true;
    }
  }
  return blocks;
}

// ── Flowers ───────────────────────────────────────────────────

/// The family a flower belongs to, for the garden's filters: "Tulips",
/// "Roses", "Sunflowers". Scenes with no one flower in them are "Scenes";
/// website bouquets are "Bouquets".
///
/// ⚠️ Read from the flower's id, which is stable, not its display name,
/// which is copy. The first family named wins, so "roses_and_tulips" is a
/// tulip and "lavender_roses" a rose.
String flowerFamily(FlowerMessage message) {
  final flower = message.flower;
  if (flower == null) return 'Bouquets';
  const families = [
    'sunflower', 'tulip', 'rose', 'lily', 'lilies', 'daisy', 'peony',
    'orchid', 'hydrangea', 'poppies', 'poppy', 'lavender', 'carnation',
    'dahlia', 'iris', 'anemone', 'ranunculus', 'camellia', 'daffodil',
  ];
  final id = flower.id;
  for (final family in families) {
    if (id.contains(family)) return _plural(family);
  }
  if (id.startsWith('stem_')) return _plural(id.substring(5));
  return flower.category == FlowerCategory.scene ? 'Scenes' : 'Flowers';
}

String _plural(String word) {
  final spaced = word.replaceAll('_', ' ');
  final name = spaced[0].toUpperCase() + spaced.substring(1);
  const same = {'Lavender', 'Babys breath', 'Scenes', 'Lilies', 'Poppies'};
  if (same.contains(name) || name.contains(' of ')) return name;
  if (name == 'Iris') return 'Irises';
  if (name.endsWith('y') && !'aeiou'.contains(name[name.length - 2])) {
    return '${name.substring(0, name.length - 1)}ies';
  }
  if (name.endsWith('s')) return name;
  return '${name}s';
}

/// Each family and how many of your flowers are in it, most first.
List<(String, int)> flowerFamilies(List<FlowerMessage> flowers) {
  final counts = <String, int>{};
  for (final f in flowers) {
    counts.update(flowerFamily(f), (n) => n + 1, ifAbsent: () => 1);
  }
  final list = counts.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) {
      final byCount = b.$2.compareTo(a.$2);
      return byCount != 0 ? byCount : a.$1.compareTo(b.$1);
    });
  return list;
}

// ── Cards ─────────────────────────────────────────────────────

/// Every card either of you made, newest first.
List<FlowerMessage> cardMemories(List<RelationshipMemory> memories) => [
      for (final m in memories)
        if (m.kind == MemoryKind.cards && m.message?.imagePath != null)
          m.message!,
    ];

/// Which column each item goes in, masonry style: each into whichever
/// column is shortest so far, so the bottoms stay close to level.
List<List<int>> masonryColumns(List<double> heights, int columns) {
  final result = [for (var i = 0; i < columns; i++) <int>[]];
  final tops = List<double>.filled(columns, 0);
  for (var i = 0; i < heights.length; i++) {
    var shortest = 0;
    for (var c = 1; c < columns; c++) {
      if (tops[c] < tops[shortest] - .5) shortest = c;
    }
    result[shortest].add(i);
    tops[shortest] += heights[i];
  }
  return result;
}

// ── Journal ───────────────────────────────────────────────────

/// A finished month, as a book on the shelf.
class JournalBook {
  const JournalBook(this.chapter, {required this.goals, required this.highlights});
  final MonthlyChapter chapter;
  final int goals;
  final int highlights;

  DateTime get month => DateTime(chapter.year, chapter.month);
}

/// Closed chapters only, newest first. The month still being written is
/// Dayflower's; Memories keeps the ones that are done.
List<JournalBook> journalBooks(List<MonthlyChapter> chapters,
    List<MonthlyGoal> goals, List<ChapterMoment> moments) {
  final closed = chapters.where((c) => c.isClosed).toList()
    ..sort((a, b) =>
        DateTime(b.year, b.month).compareTo(DateTime(a.year, a.month)));
  return [
    for (final c in closed)
      JournalBook(
        c,
        goals: goals.where((g) => g.year == c.year && g.month == c.month).length,
        highlights:
            moments.where((m) => m.year == c.year && m.month == c.month).length,
      ),
  ];
}

/// Each month's birth flower, from the stems in the bundle: the small
/// drawing on that month's cover.
String birthFlowerId(int month) => const [
      'stem_carnation', // January
      'stem_iris', // February (violet)
      'stem_daffodil', // March
      'stem_daisy', // April
      'stem_lily', // May (lily of the valley)
      'stem_rose', // June
      'stem_delphinium', // July (larkspur)
      'stem_poppy', // August
      'stem_aster', // September
      'stem_marigold', // October
      'stem_chrysanthemum', // November
      'stem_camellia', // December
    ][(month - 1).clamp(0, 11)];

// ── Places ────────────────────────────────────────────────────

/// Somewhere you have been, with everything you kept there.
class PlaceMemory {
  PlaceMemory(this.pins);

  /// Newest first.
  final List<MapPin> pins;

  /// "Palawan, Philippines" as the city picker wrote it.
  String get place => pins.first.place;

  /// The first part: the town or city.
  String get name {
    final parts = place.split(',');
    return parts.first.trim().isEmpty ? pins.first.label : parts.first.trim();
  }

  /// The last part, when there is more than one: the country.
  String get region {
    final parts = place.split(',');
    return parts.length > 1 ? parts.last.trim() : '';
  }

  DateTime get latest => pins.first.createdAt;

  /// Pins that carry a photo.
  int get photos => pins.where((p) => p.messageId != null).length;

  /// The newest photo taken there, for the row's picture.
  String? get photoMessageId =>
      pins.where((p) => p.messageId != null).firstOrNull?.messageId;
}

/// How the places list can be ordered.
enum PlaceSort {
  recent('Most recent'),
  name('A to Z'),
  most('Most memories');

  const PlaceSort(this.label);
  final String label;
}

/// Places you have been (visited pins only: a pin you mean to go to is a
/// plan, and plans are Together's), one per place, in [sort] order.
List<PlaceMemory> placeMemories(List<MapPin> pins,
    {PlaceSort sort = PlaceSort.recent}) {
  final groups = <String, List<MapPin>>{};
  for (final pin in pins.where((p) => p.visited)) {
    final key = pin.place.trim().isEmpty
        ? pin.label.trim().toLowerCase()
        : pin.place.trim().toLowerCase();
    groups.putIfAbsent(key, () => []).add(pin);
  }
  final places = [
    for (final group in groups.values)
      PlaceMemory(group..sort((a, b) => b.createdAt.compareTo(a.createdAt))),
  ];
  places.sort(switch (sort) {
    PlaceSort.recent => (a, b) => b.latest.compareTo(a.latest),
    PlaceSort.name => (a, b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    PlaceSort.most => (a, b) {
        final byCount = b.pins.length.compareTo(a.pins.length);
        return byCount != 0 ? byCount : b.latest.compareTo(a.latest);
      },
  });
  return places;
}

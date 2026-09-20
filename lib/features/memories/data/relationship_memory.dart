import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../tulip/data/flower_repository.dart';
import '../../chapters/data/chapter_repository.dart';
import '../../travel/data/map_pin_repository.dart';
import '../../booth/domain/strip_templates.dart';
import '../../dates/data/event_repository.dart';
import '../../../app_router.dart';
import 'package:intl/intl.dart';

enum MemoryKind { photos, flowers, cards, booth, journal, places, events }

/// A read-only projection of existing records, never a second source of truth.
class RelationshipMemory {
  const RelationshipMemory(
      {required this.id,
      required this.kind,
      required this.date,
      required this.title,
      required this.body,
      required this.route,
      this.message});
  final String id, title, body, route;
  final MemoryKind kind;
  final DateTime date;
  final FlowerMessage? message;
}

List<RelationshipMemory> buildRelationshipMemories({
  required List<FlowerMessage> messages,
  required List<MonthlyChapter> chapters,
  required List<ChapterMoment> moments,
  required List<MapPin> places,
  List<Map<String, dynamic>> events = const [],
  DateTime? now,
}) {
  final result = <RelationshipMemory>[];
  for (final m in messages) {
    if (!m.isPhoto && m.flower == null && !m.isBouquet) continue;
    // Older booth exports carry their template name as the caption.
    final card =
        m.isPhoto && (m.imagePath!.split('/').last.startsWith('card-'));
    final booth = m.isPhoto &&
        (m.imagePath!.split('/').last.startsWith('booth-') ||
            StripTemplate.all.any((s) => s.name == m.note));
    result.add(RelationshipMemory(
        id: 'message:${m.id}',
        kind: card
            ? MemoryKind.cards
            : booth
                ? MemoryKind.booth
                : m.isPhoto
                    ? MemoryKind.photos
                    : MemoryKind.flowers,
        date: m.sentAt,
        title: card
            ? (m.note
                    ?.split('\n')
                    .first
                    .replaceFirst('Dayflower card · ', '') ??
                'A card for you')
            : booth
                ? 'Our Photo Strip'
                : m.isPhoto
                    ? 'Daily Moment'
                    : m.flower?.name ?? 'A bouquet for you',
        body: card
            ? (m.note?.split('\n').skip(1).join('\n') ?? '')
            : m.note ?? m.flower?.meaning ?? '',
        route: Routes.chat,
        message: m));
  }
  for (final c in chapters.where((c) => c.isClosed)) {
    result.add(RelationshipMemory(
        id: 'journal:${c.id}',
        kind: MemoryKind.journal,
        date: c.closedAt!,
        title: c.title ??
            '${DateFormat.MMMM().format(DateTime(c.year, c.month))} Review',
        body: c.review ?? 'Our month together',
        route: Routes.chapterFor(c.year, c.month)));
  }
  for (final m in moments) {
    result.add(RelationshipMemory(
        id: 'moment:${m.id}',
        kind: MemoryKind.journal,
        date: m.happenedOn ?? DateTime(m.year, m.month),
        title: m.title,
        body: m.note ?? 'A moment from our journal',
        route: Routes.chapterFor(m.year, m.month)));
  }
  for (final p in places.where((p) => p.visited)) {
    result.add(RelationshipMemory(
        id: 'place:${p.id}',
        kind: MemoryKind.places,
        date: p.createdAt,
        title: p.label,
        body: p.place,
        route: '${Routes.ourMap}?tab=places',
        message: messages.where((m) => m.id == p.messageId).firstOrNull));
  }
  final today = now ?? DateTime.now();
  for (final event in events) {
    final date = DateTime.tryParse('${event['date']}');
    if (date == null ||
        !date.isBefore(DateTime(today.year, today.month, today.day))) {
      continue;
    }
    result.add(RelationshipMemory(
        id: 'event:${event['id']}',
        kind: MemoryKind.events,
        date: date,
        title: event['title'] as String? ?? 'A day together',
        body: [event['location'], event['note']]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' · '),
        route: Routes.events));
  }
  result.sort((a, b) {
    final date = b.date.compareTo(a.date);
    return date == 0 ? a.id.compareTo(b.id) : date;
  });
  return result;
}

final relationshipMemoriesProvider =
    Provider.autoDispose<AsyncValue<List<RelationshipMemory>>>((ref) {
  final messages = ref.watch(flowerMessagesProvider);
  final chapters = ref.watch(monthlyChaptersProvider);
  final moments = ref.watch(chapterMomentsProvider);
  final places = ref.watch(mapPinsProvider);
  final events = ref.watch(customEventsProvider);
  final sources = <AsyncValue<dynamic>>[
    messages,
    chapters,
    moments,
    places,
    events
  ];
  for (final source in sources) {
    if (source.hasError) {
      return AsyncError(source.error!, source.stackTrace ?? StackTrace.current);
    }
  }
  if (sources.any((s) => !s.hasValue)) return const AsyncLoading();
  return AsyncData(buildRelationshipMemories(
      messages: messages.requireValue,
      chapters: chapters.requireValue,
      moments: moments.requireValue,
      places: places.requireValue,
      events: events.requireValue));
});

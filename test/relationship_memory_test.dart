import 'package:dayflower/features/memories/data/relationship_memory.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/chapters/data/chapter_repository.dart';
import 'package:dayflower/features/travel/data/map_pin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FlowerMessage message(String id,
          {String? flower, String? path, String? note, int day = 19}) =>
      FlowerMessage(
          id: id,
          pairId: 'pair',
          senderId: 'partner',
          flowerType: flower,
          imagePath: path,
          note: note,
          sentAt: DateTime(2026, 9, day));
  test(
      'Preserves expired photos, flowers, cards and strips, without ordinary chats',
      () {
    final items = buildRelationshipMemories(messages: [
      message('photo', path: 'pair/photo.jpg', day: 1),
      message('flower', flower: 'tulip'),
      message('chat', note: 'hello'),
      message('card',
          path: 'pair/card-1.png',
          note: 'Dayflower card · Just because\nThinking of you'),
      message('strip', path: 'pair/booth-1.jpg'),
    ], chapters: [], moments: [], places: []);
    expect(items.length, 4);
    expect(items.last.id, 'message:photo');
    expect(
        items.map((m) => m.kind),
        containsAll([
          MemoryKind.photos,
          MemoryKind.cards,
          MemoryKind.flowers,
          MemoryKind.booth
        ]));
    expect(items.firstWhere((m) => m.kind == MemoryKind.cards).body,
        'Thinking of you');
    expect(items.map((m) => m.id).toSet().length, items.length);
  });
  test('Only closed journals and visited places enter the preserved timeline',
      () {
    final items = buildRelationshipMemories(messages: [], chapters: [
      const MonthlyChapter(
          id: 'draft',
          pairId: 'pair',
          year: 2026,
          month: 9,
          review: 'In progress'),
      MonthlyChapter(
          id: 'closed',
          pairId: 'pair',
          year: 2026,
          month: 8,
          review: 'A lovely month',
          closedAt: DateTime(2026, 9, 1)),
    ], moments: [], places: [
      for (final visited in [true, false])
        MapPin(
            id: '$visited',
            pairId: 'pair',
            createdBy: 'me',
            label: 'Our place',
            place: 'Manila',
            lat: 14,
            lon: 120,
            visited: visited,
            createdAt: DateTime(2026, 8, 10)),
    ]);
    expect(items.map((m) => m.id), ['journal:closed', 'place:true']);
    expect(items.first.title, 'August Review');
  });
  test('Only past dated events are preserved', () {
    final items = buildRelationshipMemories(
        messages: [],
        chapters: [],
        moments: [],
        places: [],
        now: DateTime(2026, 9, 19),
        events: [
          {'id': 1, 'title': 'Beach day', 'date': '2026-09-18'},
          {'id': 2, 'title': 'Next trip', 'date': '2026-10-01'},
          {'id': 3, 'title': 'No date', 'date': 'invalid'},
        ]);
    expect(items.single.title, 'Beach day');
    expect(items.single.kind, MemoryKind.events);
  });
}

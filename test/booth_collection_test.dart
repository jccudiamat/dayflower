import 'package:dayflower/features/booth/data/strip_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'Booth collection keeps old and new booth prints, excludes everyday photos, and sorts newest first',
      () {
    FlowerMessage photo(String id, String? note, int day,
            {bool image = true}) =>
        FlowerMessage(
            id: id,
            pairId: 'pair',
            senderId: 'me',
            imagePath: image ? '$id.jpg' : null,
            note: note,
            sentAt: DateTime(2026, 9, day));
    final result = boothCollection([
      photo('legacy', 'Classic Polaroid', 1),
      photo('my-day', 'Morning walk', 17),
      photo('chat', null, 18),
      photo('text', 'Classic Polaroid', 19, image: false),
      photo('studio', 'Dayflower booth · Rose room · 4 cut', 16),
    ]);
    expect(result.map((m) => m.id), ['studio', 'legacy']);
  });
}

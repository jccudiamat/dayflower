import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/tulip/domain/day_reactions.dart';
import 'package:dayflower/features/widget/widget_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The home-screen widget's heart: lit for what I have hearted, which is a
/// "❤️" reply to it, the same thing the day viewer's ❤️ sends.
void main() {
  FlowerMessage msg(String id, String sender,
          {String? note, String? replyTo, String? image}) =>
      FlowerMessage(
        id: id,
        pairId: 'p',
        senderId: sender,
        note: note,
        replyTo: replyTo,
        imagePath: image,
        sentAt: DateTime.now(),
        toWidget: image != null,
      );

  test('my hearts are my ❤️ replies, by what they answer', () async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      flowerMessagesProvider.overrideWith((ref) => Stream.value([
            msg('day-1', 'them', image: 'a.jpg'),
            msg('day-2', 'them', image: 'b.jpg'),
            msg('flower-1', 'them'),
            msg('h1', 'me', note: heartNote, replyTo: 'day-1'),
            msg('h2', 'me', note: heartNote, replyTo: 'flower-1'),
            // Theirs, not mine: their heart on my day lights nothing here.
            msg('h3', 'them', note: heartNote, replyTo: 'day-2'),
            // Another reaction is not a heart.
            msg('r1', 'me', note: '😂', replyTo: 'day-2'),
            // A heart that answers nothing is just a message.
            msg('m1', 'me', note: heartNote),
          ])),
    ]);
    addTearDown(container.dispose);
    final keep = container.listen(myHeartsProvider, (_, __) {});
    addTearDown(keep.close);
    await container.read(flowerMessagesProvider.future);
    expect(container.read(myHeartsProvider), {'day-1', 'flower-1'});
  });

  test('the widget heart and the viewer ❤️ are one and the same', () {
    // Either one must light the other, so they have to send the same note.
    expect(heartNote, DayReaction.heart.emoji);
  });

  test('the widget and the receiver agree on their keys', () {
    // DayLikeReceiver.KEY_HEARTED and the like action's host, in Kotlin.
    expect(DayflowerWidgets.keyHearted, 'liked_ids');
    expect(Uri.parse('${DayflowerWidgets.likeAction}?id=x&on=1').host, 'like');
  });
}

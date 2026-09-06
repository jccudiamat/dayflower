import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/features/calls/domain/call_notifier.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';

/// A call that rings out has to read as "no answer", not as a conversation
/// of however long it rang. The row carries no `answered_at`, so the marker
/// is an end **equal to the start** — see migration 0029.
///
/// ⚠️ That is a convention shared between a SQL function and a Dart getter,
/// which is exactly the kind of agreement that rots silently. These pin it.

FlowerMessage _call({
  required DateTime sentAt,
  DateTime? endedAt,
  String mode = 'voice',
}) =>
    FlowerMessage(
      id: 'm1',
      pairId: 'p1',
      senderId: 'u1',
      sentAt: sentAt,
      callMode: mode,
      callRoom: 'room',
      callEndedAt: endedAt,
    );

void main() {
  final start = DateTime(2026, 9, 6, 12);

  group('what counts as missed', () {
    test('an end equal to the start is a call nobody answered', () {
      expect(_call(sentAt: start, endedAt: start).wasMissed, isTrue);
    });

    test('a call with real seconds in it is not', () {
      expect(
        _call(sentAt: start, endedAt: start.add(const Duration(seconds: 3)))
            .wasMissed,
        isFalse,
      );
    });

    test('a call still running is not missed — it is not over', () {
      // No end at all. The thread reads this as live, or as abandoned once
      // it goes stale; either way `wasMissed` must not claim it.
      expect(_call(sentAt: start).wasMissed, isFalse);
    });

    test('an end *before* the start still reads as missed', () {
      // Clock skew between the phone and Postgres. The sentinel is "no
      // time passed", and a negative duration is not a shorter call.
      expect(
        _call(sentAt: start, endedAt: start.subtract(const Duration(seconds: 2)))
            .wasMissed,
        isTrue,
      );
    });

    test('a message that is not a call is never missed', () {
      final text = FlowerMessage(
        id: 'm2',
        pairId: 'p1',
        senderId: 'u1',
        sentAt: start,
        note: 'hello',
      );
      expect(text.wasMissed, isFalse);
      expect(text.callDuration, isNull);
    });
  });

  group('the ring-out window', () {
    test('is a minute, matching the notification it rings alongside', () {
      // ⚠️ CallAlerts sets `timeoutAfter: 60000` on the incoming-call
      // notification. If these drift apart, one of them outlives the other:
      // either a notification for a call that is already over, or a call
      // still ringing with nothing on screen saying so.
      expect(CallNotifier.noAnswerAfter, const Duration(seconds: 60));
    });
  });
}

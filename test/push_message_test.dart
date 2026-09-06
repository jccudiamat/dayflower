import 'package:dayflower/features/push/domain/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parsing a push payload is the one piece of the notification path that can
/// be checked without a Firebase project, a second phone, or a closed app —
/// and it is the piece that decides whether something rings.

void main() {
  group('what arrived', () {
    test('a video call is actionable and interrupts', () {
      final push = PushMessage.parse({
        'kind': 'call',
        'callMode': 'video',
        'messageId': 'm1',
        'pairId': 'p1',
        'title': 'Sheena',
        'body': 'is video calling you',
      })!;

      expect(push.kind, PushKind.call);
      expect(push.kind.interrupts, isTrue);
      expect(push.isVideoCall, isTrue);
      expect(push.isActionableCall, isTrue);
    });

    test('nothing but a call takes over the screen', () {
      for (final kind in ['message', 'flower', 'photo']) {
        final push = PushMessage.parse({'kind': kind, 'title': 'a', 'body': 'b'})!;
        expect(push.kind.interrupts, isFalse, reason: '$kind must not ring');
      }
    });

    test('a call with no row to answer is not rung', () {
      // Tapping it could only open a call screen with nothing behind it.
      final push = PushMessage.parse({
        'kind': 'call',
        'callMode': 'voice',
        'messageId': '',
        'title': 'Sheena',
        'body': 'is calling you',
      })!;
      expect(push.kind.interrupts, isTrue);
      expect(push.isActionableCall, isFalse);
    });
  });

  group('payloads from elsewhere', () {
    test('an unknown kind lands as a quiet message, not silence', () {
      // A newer build sending something this one has never heard of. The
      // event still happened; saying so beats dropping it.
      final push = PushMessage.parse({'kind': 'hologram', 'title': 'x', 'body': 'y'})!;
      expect(push.kind, PushKind.message);
      expect(push.kind.interrupts, isFalse);
    });

    test('no kind at all is dropped', () {
      expect(PushMessage.parse({'title': 'x'}), isNull);
    });

    test('blank title and body fall back rather than refusing', () {
      // Losing the whole event over a formatting problem would be worse
      // than a generic banner.
      final push = PushMessage.parse({'kind': 'message', 'title': '', 'body': '  '})!;
      expect(push.title, 'Dayflower');
      expect(push.body, isNotEmpty);
    });
  });
}

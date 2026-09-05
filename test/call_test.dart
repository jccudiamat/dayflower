import 'package:dayflower/features/calls/domain/call.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The call rules that are worth pinning down without a phone, a partner and
/// a media server in the room — which is all of them that can be got wrong
/// quietly.

FlowerMessage _call({
  required Duration ago,
  String mode = 'voice',
  Duration? ranFor,
}) {
  final sentAt = DateTime.now().subtract(ago);
  return FlowerMessage(
    id: 'm1',
    pairId: 'p1',
    senderId: 'u1',
    sentAt: sentAt,
    callMode: mode,
    callRoom: 'dayflower-v1-p1',
    callEndedAt: ranFor == null ? null : sentAt.add(ranFor),
  );
}

void main() {
  group('a call is a message', () {
    test('a call row is not read as text', () {
      // 🔴 The bug this exists to prevent. `isText` was "no flower and no
      // photo", which a call satisfies — so every call would have rendered
      // as an empty text bubble, and the composer's alert line would have
      // announced it as a message with no words in it.
      final call = _call(ago: const Duration(minutes: 1));
      expect(call.isCall, isTrue);
      expect(call.isText, isFalse);
      expect(call.isPhoto, isFalse);
    });

    test('an unknown call mode degrades to an ordinary message', () {
      // A call placed by a newer build must not crash this one's thread.
      final future = FlowerMessage(
        id: 'm2',
        pairId: 'p1',
        senderId: 'u1',
        sentAt: DateTime.now(),
        note: 'hi',
        callMode: 'hologram',
      );
      expect(future.call, isNull);
      expect(future.isCall, isFalse);
      expect(future.isText, isTrue);
    });
  });

  group('when a call counts as live', () {
    test('just started and not hung up', () {
      expect(_call(ago: const Duration(minutes: 2)).isLiveCall, isTrue);
    });

    test('hung up', () {
      final ended = _call(
        ago: const Duration(minutes: 30),
        ranFor: const Duration(minutes: 4),
      );
      expect(ended.isLiveCall, isFalse);
      expect(ended.callDuration, const Duration(minutes: 4));
    });

    test('abandoned calls stop advertising themselves', () {
      // Both apps killed mid-call, or a hang-up that never reached the
      // server: the row stays open forever. Without the time box the header
      // would offer to join an empty room for the rest of the year.
      expect(_call(ago: const Duration(hours: 3)).isLiveCall, isFalse);
      expect(_call(ago: const Duration(minutes: 119)).isLiveCall, isTrue);
    });
  });

  group('durations', () {
    test('the in-call clock', () {
      expect(formatCallDuration(const Duration(seconds: 9)), '0:09');
      expect(formatCallDuration(const Duration(minutes: 4, seconds: 12)),
          '4:12');
      // Past the hour the minutes pad, so the string stops jumping width.
      expect(
        formatCallDuration(const Duration(hours: 1, minutes: 4, seconds: 2)),
        '1:04:02',
      );
      // A clock that has run backwards is a clock bug, not a negative call.
      expect(formatCallDuration(const Duration(seconds: -5)), '0:00');
    });

    test('the line a finished call leaves in the thread', () {
      expect(describeCallDuration(const Duration(seconds: 42)), '42 sec');
      expect(describeCallDuration(const Duration(minutes: 4, seconds: 12)),
          '4 min 12 sec');
      // Round numbers do not carry a trailing zero unit.
      expect(describeCallDuration(const Duration(minutes: 5)), '5 min');
      expect(describeCallDuration(const Duration(hours: 2)), '2 hr');
      expect(
        describeCallDuration(const Duration(hours: 1, minutes: 20)),
        '1 hr 20 min',
      );
    });
  });

  group('session', () {
    const session = CallSession(
      messageId: 'm1',
      room: 'dayflower-v1-p1',
      mode: CallMode.voice,
      status: CallStatus.connecting,
      isCaller: true,
    );

    test('no timer until media is up', () {
      // A clock sitting at 00:00 reads as a call that connected and went
      // silent, which is the opposite of what is happening.
      expect(session.elapsed, isNull);
    });

    test('a status change clears the last failure', () {
      final failed = session.copyWith(
        status: CallStatus.failed,
        failure: CallFailure.unreachable,
      );
      expect(failed.failure, CallFailure.unreachable);

      // Retrying must not keep rendering the error it is retrying past.
      final retried = failed.copyWith(status: CallStatus.connecting);
      expect(retried.failure, isNull);
    });

    test('terminal states are the ones that end the screen', () {
      expect(CallStatus.ended.isTerminal, isTrue);
      expect(CallStatus.failed.isTerminal, isTrue);
      expect(CallStatus.ringing.isTerminal, isFalse);
      expect(CallStatus.live.isTerminal, isFalse);
    });
  });
}

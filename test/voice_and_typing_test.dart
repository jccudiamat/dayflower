import 'dart:async';

import 'package:dayflower/features/calls/data/call_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/tulip/data/voice_notes.dart';
import 'package:flutter_test/flutter_test.dart';

FlowerMessage _voice({int ms = 7000, String sender = 'them'}) => FlowerMessage(
      id: 'v1',
      pairId: 'pair',
      senderId: sender,
      audioPath: 'pair/abc.m4a',
      audioMs: ms,
      sentAt: DateTime(2026, 9, 25, 9, 41),
    );

void main() {
  group('a voice note is a message', () {
    test('it is not text, not a photo, and knows how long it runs', () {
      final m = _voice();
      expect(m.isVoice, isTrue);
      expect(m.isText, isFalse, reason: 'an empty bubble otherwise');
      expect(m.isPhoto, isFalse);
      expect(m.isCall, isFalse);
      expect(m.audioLength, const Duration(seconds: 7));
    });

    test('the alert and the list line both say what it is', () {
      final m = _voice(ms: 62000);
      expect(m.alertLine, 'Sent a voice message 🎤 · 1:02');
      expect(m.previewFor(mine: false), '🎤  1:02');
      expect(m.previewFor(mine: true), 'You: 🎤  1:02');
    });

    test('lengths read the way a player writes them', () {
      expect(voiceLength(Duration.zero), '0:00');
      expect(voiceLength(const Duration(seconds: 7)), '0:07');
      expect(voiceLength(const Duration(seconds: 70)), '1:10');
      expect(voiceLength(VoiceNotes.maxDuration), '2:00');
    });

    test('two minutes is the ceiling, and a tap is not a message', () {
      expect(VoiceNotes.maxDuration, const Duration(minutes: 2));
      expect(VoiceNotes.minDuration.inMilliseconds, lessThan(1000));
      // The column refuses anything past 130s (migration 0051), so the
      // app's own ceiling has to sit under it.
      expect(VoiceNotes.maxDuration.inMilliseconds, lessThan(130000));
    });

    test('an ordinary message is unaffected', () {
      final text = FlowerMessage(
          id: 't', pairId: 'p', senderId: 'me', note: 'hi',
          sentAt: DateTime(2026, 9, 25));
      expect(text.isVoice, isFalse);
      expect(text.isText, isTrue);
      expect(text.audioLength, Duration.zero);
    });
  });

  group('a room names its pair, and only its own', () {
    test('there and back again', () {
      const pair = '0f3f7069-bdca-47f5-900b-f3651401212d';
      final room = CallRepository.roomFor(pair);
      expect(CallRepository.pairOf(room), pair);
    });

    test('anything else is refused rather than guessed at', () {
      // 🔴 The peer transport meets the other phone on a channel named from
      // this. A room it cannot parse must yield nothing, not a channel name
      // built out of rubbish.
      expect(CallRepository.pairOf('dayflower-v1-not-a-uuid'), isNull);
      expect(CallRepository.pairOf('room-1'), isNull);
      expect(CallRepository.pairOf(''), isNull);
      expect(
          CallRepository.pairOf(
              'dayflower-v2-0f3f7069-bdca-47f5-900b-f3651401212d'),
          isNull);
    });
  });
}

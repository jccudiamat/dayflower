import 'package:dayflower/features/calls/data/call_usage.dart';
import 'package:dayflower/features/calls/domain/call.dart';
import 'package:flutter_test/flutter_test.dart';

/// The quota rules. All of these decide whether something appears on screen
/// or whether a call is refused, and none of them can be checked by looking
/// at the app until the month it matters.

// LiveKit's free tier, roughly: 5,000 participant-minutes is 2,500
// whole-call minutes shared between both kinds, and the 50 GB cap stops
// video at about 2,000 of them.
const _allowance = CallAllowance(totalMinutes: 2500, videoMinutes: 2000);

CallUsage _used({int voiceMin = 0, int videoMin = 0, CallAllowance? plan}) =>
    CallUsage(
      voice: Duration(minutes: voiceMin),
      video: Duration(minutes: videoMin),
      allowance: plan ?? _allowance,
    );

void main() {
  group('unmetered builds', () {
    // Self-hosting is the case that must disappear rather than read zero.
    const free = CallUsage();

    test('a build with no allowance is never metered', () {
      expect(free.isMetered, isFalse);
      expect(free.shouldShow, isFalse);
      expect(free.shouldWarn, isFalse);
      expect(free.isExhausted, isFalse);
    });

    test('an allowance of zero minutes means unlimited, not spent', () {
      // 🔴 Caught a real bug. `int.tryParse('') ?? 0` is how an unset .env
      // parses, so a zero-zero allowance is an ordinary self-hosted build.
      // `isMetered` was `allowance != null`, which made that build report
      // itself exhausted and refuse to place any call at all.
      const zeroed = CallUsage(
        allowance: CallAllowance(totalMinutes: 0, videoMinutes: 0),
        voice: Duration(hours: 40),
      );
      expect(zeroed.isMetered, isFalse);
      expect(zeroed.fraction, 0);
      expect(zeroed.isExhausted, isFalse);
      expect(zeroed.shouldShow, isFalse);
      expect(zeroed.isSpent(CallMode.voice), isFalse);
    });

    test('an uncapped ceiling reports null left, not zero', () {
      // The distinction the nullable exists for: "unlimited" and "none
      // left" must never render as the same thing.
      const dataOnly = CallUsage(
        allowance: CallAllowance(totalMinutes: 0, videoMinutes: 2000),
      );
      expect(dataOnly.isMetered, isTrue);
      // No minute pool, so voice answers to nothing at all.
      expect(dataOnly.voiceLeft, isNull);
      expect(dataOnly.isSpent(CallMode.voice), isFalse);
      expect(dataOnly.videoLeft, const Duration(minutes: 2000));
    });
  });

  group('minutes are one shared pool', () {
    test('video spends the same pool voice does', () {
      // 🔴 The model bug this group exists for. Treating the two as
      // independent budgets reported "1,000 video minutes left" while the
      // shared pool held 500 — an overstatement of up to double, which is
      // precisely the surprise this feature exists to prevent.
      final usage = _used(voiceMin: 1000, videoMin: 1000);
      expect(usage.total, const Duration(minutes: 2000));
      expect(usage.totalFraction, closeTo(0.8, 0.001));
      expect(usage.voiceLeft, const Duration(minutes: 500));
      // Video's own ceiling has 1,000 left, but the pool only has 500.
      expect(usage.videoLeft, const Duration(minutes: 500));
    });

    test('video takes whichever ceiling is tighter', () {
      // Heavy video, light total: now the data cap binds instead.
      final usage = _used(videoMin: 1900);
      expect(usage.totalLeft, const Duration(minutes: 600));
      expect(usage.videoLeft, const Duration(minutes: 100));
    });

    test('the ring reads the nearer ceiling, not an average', () {
      // An average would show 85% while video sat at 95%, and the first
      // the user heard of the limit would be a call that failed.
      final usage = _used(videoMin: 1900);
      expect(usage.videoFraction, closeTo(0.95, 0.001));
      expect(usage.totalFraction, closeTo(0.76, 0.001));
      expect(usage.fraction, closeTo(0.95, 0.001));
    });
  });

  group('the thresholds that put things on screen', () {
    test('silent below 70%', () {
      final usage = _used(videoMin: 1375); // 68.75% of the video ceiling
      expect(usage.shouldShow, isFalse);
      expect(usage.shouldWarn, isFalse);
    });

    test('the Us card appears at 70%', () {
      final usage = _used(videoMin: 1400);
      expect(usage.fraction, closeTo(0.7, 0.001));
      expect(usage.shouldShow, isTrue);
      // Still not on the thread — that is a separate, later threshold.
      expect(usage.shouldWarn, isFalse);
    });

    test('the thread line starts at 90%', () {
      final usage = _used(videoMin: 1800);
      expect(usage.shouldWarn, isTrue);
      expect(usage.shouldShow, isTrue);
    });
  });

  group('what is left', () {
    test('subtracts what was spent', () {
      final usage = _used(voiceMin: 300, videoMin: 200);
      expect(usage.totalLeft, const Duration(minutes: 2000));
      expect(usage.voiceLeft, const Duration(minutes: 2000));
      expect(usage.videoLeft, const Duration(minutes: 1800));
    });

    test('never goes negative', () {
      // Usage can overshoot: the count is a few percent light, and a call
      // in progress is not counted until it ends. "−12 min left" would be
      // a number no reader could act on.
      final usage = _used(videoMin: 2400);
      expect(usage.videoLeft, Duration.zero);
      expect(usage.fraction, greaterThan(1));
    });

    test('the data cap stops video but not voice', () {
      // The realistic shape of a month: video hits its own ceiling long
      // before the shared pool empties. Refusing a voice call there would
      // be refusing the cheap thing because the expensive one ran out.
      final usage = _used(videoMin: 2000);
      expect(usage.videoLeft, Duration.zero);
      expect(usage.isSpent(CallMode.video), isTrue);
      expect(usage.voiceLeft, const Duration(minutes: 500));
      expect(usage.isSpent(CallMode.voice), isFalse);
      expect(usage.isExhausted, isFalse);
    });

    test('an empty pool stops both', () {
      final usage = _used(voiceMin: 2500);
      expect(usage.isSpent(CallMode.voice), isTrue);
      expect(usage.isSpent(CallMode.video), isTrue);
      expect(usage.isExhausted, isTrue);
    });
  });

  group('the hard stop', () {
    test('has its own failure, distinct from a network one', () {
      // Nothing about the network is wrong here, and telling someone to
      // check their connection would be false.
      expect(CallFailure.quotaExhausted.title, isNotEmpty);
      expect(CallFailure.quotaExhausted, isNot(CallFailure.unreachable));
    });

    test('the reset date is the first of next month', () {
      final reset = CallUsage.resetsOn;
      final now = DateTime.now();
      expect(reset.day, 1);
      expect(reset.isAfter(now), isTrue);
      // Rolls the year rather than producing a thirteenth month.
      expect(reset.month, now.month == 12 ? 1 : now.month + 1);
      if (now.month == 12) expect(reset.year, now.year + 1);
    });
  });
}

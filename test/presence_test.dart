import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/features/presence/domain/presence.dart';

/// The chat header makes a claim about where somebody is. Getting it wrong
/// is not a cosmetic bug — "Active now" on a partner who is asleep, or
/// silence on one who is reading, both say something untrue about a person
/// to the one person who cares most.

void main() {
  // A fixed clock, so "yesterday" cannot mean something different depending
  // on what time the suite happens to run.
  final now = DateTime(2026, 9, 13, 14, 30);
  String? labelAt(Duration ago) =>
      activeLabel(now.subtract(ago), now: now);

  group('activeLabel', () {
    test('never heard from them at all says nothing', () {
      // Not "Active a while ago". We do not know, and a header must not
      // turn an absence of data into a statement about someone.
      expect(activeLabel(null, now: now), isNull);
    });

    test('a beat inside the window is now', () {
      expect(labelAt(Duration.zero), 'Active now');
      expect(labelAt(const Duration(seconds: 90)), 'Active now');
    });

    test('a clock that runs ahead still reads as now', () {
      // Two phones, two clocks. A partner whose device is a minute fast
      // must not be reported as active in the future.
      expect(activeLabel(now.add(const Duration(minutes: 3)), now: now),
          'Active now');
    });

    test('minutes, with the singular spelled out', () {
      expect(labelAt(const Duration(minutes: 2)), 'Active 2 minutes ago');
      expect(labelAt(const Duration(minutes: 59)), 'Active 59 minutes ago');
    });

    test('past an hour it gives a time, not a countdown', () {
      // "Active 4 hours and 12 minutes ago" is a log entry about a person.
      expect(labelAt(const Duration(hours: 4)), 'Active at 10:30 AM');
    });

    test('yesterday is named, not counted', () {
      expect(activeLabel(DateTime(2026, 9, 12, 22, 15), now: now),
          'Active yesterday at 10:15 PM');
    });

    test('earlier in the week is the weekday', () {
      expect(activeLabel(DateTime(2026, 9, 10, 9, 0), now: now),
          'Active Thursday');
    });

    test('beyond a week is a date', () {
      expect(activeLabel(DateTime(2026, 8, 30, 9, 0), now: now),
          'Active 30 Aug');
    });

    test('midnight does not turn an hour ago into yesterday', () {
      // 00:20, last seen 23:50. Half an hour, and the "minutes" branch has
      // to win before the calendar day is ever consulted.
      final justAfterMidnight = DateTime(2026, 9, 13, 0, 20);
      expect(
        activeLabel(DateTime(2026, 9, 12, 23, 50), now: justAfterMidnight),
        'Active 30 minutes ago',
      );
    });
  });

  test('the beat is well inside the window it has to keep alive', () {
    // 🔴 If these ever cross, a phone that is plainly in use blinks offline
    // between beats. The window must leave room for one missed beat.
    expect(pingEvery * 2, lessThanOrEqualTo(activeWindow));
  });

  /// What a beat is allowed to mean.
  ///
  /// 🔴 The rule this pins was missing entirely, and the header lied in two
  /// directions because of it. Both cases below are things that actually
  /// happened, not hypotheticals — see [shouldClaimPresence].
  group('shouldClaimPresence', () {
    bool claim({bool signedIn = true, bool onWeb = false, bool awake = true}) =>
        shouldClaimPresence(
            signedIn: signedIn, onWeb: onWeb, deviceAwake: awake);

    test('a phone that is awake and signed in pings', () {
      expect(claim(), isTrue);
    });

    test('a browser tab never pings, however alive it looks', () {
      // 🔴 A dev preview signed in as the test partner reported "Active
      // now" for nineteen hours after its server was stopped: the page
      // was still loaded, and browsers throttle a hidden tab's timers to
      // about once a minute — which is exactly pingEvery, so it never
      // looked idle either.
      expect(claim(onWeb: true), isFalse);
      expect(claim(onWeb: true, awake: true, signedIn: true), isFalse);
    });

    test('a locked phone does not become present because it rang', () {
      // 🔴 MainActivity is showWhenLocked, so an incoming call or a
      // ringing reminder launches the app over the lock screen and it used
      // to beat on the way up. Ringing somebody made them look like they
      // had just picked up their phone.
      expect(claim(awake: false), isFalse);
    });

    test('signed out writes nothing', () {
      expect(claim(signedIn: false), isFalse);
    });

    test('every reason to stay quiet outranks every reason to ping', () {
      // The rule is an AND, not a vote: one "no" is the answer.
      expect(claim(signedIn: false, onWeb: true, awake: false), isFalse);
      expect(claim(signedIn: true, onWeb: true, awake: false), isFalse);
    });
  });
}

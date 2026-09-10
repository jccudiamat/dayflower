import 'dart:convert';
import 'dart:io';

import 'package:dayflower/app_router.dart';
import 'package:dayflower/features/reminders/data/reminder_scheduler.dart';
import 'package:dayflower/features/reminders/data/reminder_repository.dart';
import 'package:dayflower/features/reminders/domain/reminder_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

Reminder _reminder({
  required DateTime due,
  String title = 'Take your meds',
  String emoji = '💊',
  String? note = 'the blue one, with food',
  bool alarm = true,
}) =>
    Reminder(
      id: 'r1',
      pairId: 'p1',
      createdBy: 'sheena',
      forUser: 'me',
      title: title,
      note: note,
      emoji: emoji,
      remindAt: due,
      repeat: ReminderRepeat.none,
      alarm: alarm,
    );

void main() {
  final now = DateTime(2026, 9, 10, 20, 0); // 8pm
  final due = DateTime(2026, 9, 11, 8, 0); // 8am tomorrow — 12h away

  group('the schedule', () {
    test('is set, then 3h / 2h / 1h, then the reminder', () {
      final pings =
          countdownPings(_reminder(due: due), now: now, includeJustSet: true);
      expect(
        pings.map((p) => p.kind).toList(),
        [
          ReminderPingKind.justSet,
          ReminderPingKind.hours,
          ReminderPingKind.hours,
          ReminderPingKind.hours,
          ReminderPingKind.due,
        ],
      );
      expect(
        pings
            .where((p) => p.kind == ReminderPingKind.hours)
            .map((p) => p.remaining.inHours)
            .toList(),
        [3, 2, 1],
      );
      // Five notifications per reminder, per phone. That is the whole budget.
      expect(pings.length, 5);
    });

    test('is ordered, and every ping lands before the reminder', () {
      final pings = countdownPings(_reminder(due: due), now: now);
      for (var i = 1; i < pings.length; i++) {
        expect(pings[i].at.isAfter(pings[i - 1].at), isTrue,
            reason: 'ping $i is out of order');
      }
      expect(pings.last.at, due);
      expect(pings.last.kind, ReminderPingKind.due);
    });

    test('drops pings that are already in the past', () {
      // ⚠️ Set for twenty minutes' time: just the reminder. Scheduling three
      // hourly pings that are all overdue the moment they are written is how
      // a phone ends up firing a burst.
      final soon = now.add(const Duration(minutes: 20));
      final pings = countdownPings(_reminder(due: soon), now: now);
      expect(pings.map((p) => p.kind).toList(), [ReminderPingKind.due]);
    });

    test('a reminder inside the window still gets the pings that fit', () {
      // Set for two and a half hours' time: the 2h and 1h pings survive, the
      // 3h one is already gone.
      final soon = now.add(const Duration(hours: 2, minutes: 30));
      final pings = countdownPings(_reminder(due: soon), now: now);
      expect(
        pings
            .where((p) => p.kind == ReminderPingKind.hours)
            .map((p) => p.remaining.inHours)
            .toList(),
        [2, 1],
      );
    });

    test('a reminder already past schedules nothing', () {
      final pings = countdownPings(
          _reminder(due: now.subtract(const Duration(minutes: 1))), now: now);
      expect(pings, isEmpty);
    });

    test('the just-set ping is opt-in and comes first', () {
      final pings =
          countdownPings(_reminder(due: due), now: now, includeJustSet: true);
      expect(pings.first.kind, ReminderPingKind.justSet);
      expect(pings.first.at, now);
    });

    test('a long lead is capped, not unbounded', () {
      // 🔴 The real data has a weekly reminder set 277 hours out. Hourly from
      // creation would be 277 notifications a week, forever, and a channel
      // that behaves like that gets muted — which loses the reminder that
      // mattered. See kCountdownLeadHours.
      final far = now.add(const Duration(hours: 277));
      final pings = countdownPings(_reminder(due: far), now: now);
      expect(pings.where((p) => p.kind == ReminderPingKind.hours).length,
          kCountdownLeadHours);
      expect(pings.length, kCountdownLeadHours + 1);
    });
  });

  group('only the real thing rings', () {
    test('the due ping alarms, for the person it is for', () {
      final pings = countdownPings(_reminder(due: due), now: now);
      for (final p in pings) {
        final rings = p.alarmsFor(isMine: true, reminderWantsAlarm: true);
        expect(rings, p.kind == ReminderPingKind.due,
            reason: '${p.kind} should not take over the screen');
      }
    });

    test('the partner watching gets a banner, never the alarm', () {
      final duePing = countdownPings(_reminder(due: due), now: now).last;
      expect(duePing.alarmsFor(isMine: false, reminderWantsAlarm: true), isFalse);
    });

    test('a reminder set not to ring never rings', () {
      final duePing =
          countdownPings(_reminder(due: due, alarm: false), now: now).last;
      expect(duePing.alarmsFor(isMine: true, reminderWantsAlarm: false), isFalse);
    });
  });

  group('labels', () {
    test('countdown reads naturally, singular and plural', () {
      expect(countdownLabel(const Duration(hours: 12)), '12 hours');
      expect(countdownLabel(const Duration(hours: 1)), '1 hour');
      expect(countdownLabel(const Duration(minutes: 45)), '45 minutes');
      expect(countdownLabel(const Duration(minutes: 5)), '5 minutes');
      expect(countdownLabel(const Duration(minutes: 1)), '1 minute');
    });

    test('when reads as today, tomorrow, or a date', () {
      expect(whenLabel(DateTime(2026, 9, 10, 21, 30), now: now), '9:30 PM');
      expect(whenLabel(due, now: now), 'Tomorrow, 8:00 AM');
      expect(whenLabel(DateTime(2026, 9, 13, 8, 0), now: now), 'Sun, 8:00 AM');
      expect(whenLabel(DateTime(2026, 9, 21, 8, 0), now: now),
          'Mon 21 Sep, 8:00 AM');
    });

    test('midnight and noon are not 0:00', () {
      expect(whenLabel(DateTime(2026, 9, 10, 0, 5), now: now), '12:05 AM');
      expect(whenLabel(DateTime(2026, 9, 10, 12, 0), now: now), '12:00 PM');
    });
  });

  group('copy', () {
    test('says whose reminder it is, both ways round', () {
      final r = _reminder(due: due);
      final ping = countdownPings(r, now: now)
          .firstWhere((p) => p.remaining == const Duration(hours: 2));

      final mine = pingCopy(ping, r,
          isMine: true, partnerName: 'Sheena', now: now);
      final theirs = pingCopy(ping, r,
          isMine: false, partnerName: 'Sheena', now: now);

      expect(mine.subText, 'in 2 hours');
      expect(mine.body, contains('for you'));
      expect(theirs.body, contains('for Sheena'));
      // ⚠️ Both halves of the couple get every ping, so without this a
      // reminder about their medication reads as one about yours.
      expect(mine.body, isNot(equals(theirs.body)));
    });

    test('the countdown is in subText, never crammed into the title', () {
      final r = _reminder(due: due);
      final ping = countdownPings(r, now: now).first;
      final copy =
          pingCopy(ping, r, isMine: true, partnerName: 'Sheena', now: now);
      expect(copy.title, '💊  Take your meds');
      expect(copy.title, isNot(contains('hour')));
      expect(copy.subText, contains('hour'));
    });

    test('the due ping still says whose it is on the partner phone', () {
      // Regression: with a note present the body used to be just the note,
      // so at 8am her phone said "Take your meds / the blue one, with food"
      // with nothing marking it as his.
      final r = _reminder(due: due);
      final duePing = countdownPings(r, now: now).last;
      final hers =
          pingCopy(duePing, r, isMine: false, partnerName: 'Jc', now: now);
      expect(hers.body, contains('for Jc'));
      expect(hers.body, contains('the blue one'));

      final his =
          pingCopy(duePing, r, isMine: true, partnerName: 'Sheena', now: now);
      expect(his.body, 'the blue one, with food');
    });

    test('the due ping with no note still names the owner', () {
      final r = _reminder(due: due, note: null);
      final duePing = countdownPings(r, now: now).last;
      expect(pingCopy(duePing, r, isMine: false, partnerName: 'Jc', now: now).body,
          'for Jc');
      expect(pingCopy(duePing, r, isMine: true, partnerName: 'Sheena', now: now).body,
          'It is time');
    });

    test('a note survives into the body, and its absence is not an empty tail',
        () {
      final r = _reminder(due: due, note: null);
      final ping = countdownPings(r, now: now).first;
      final copy =
          pingCopy(ping, r, isMine: true, partnerName: 'Sheena', now: now);
      expect(copy.body.trim(), isNot(endsWith('·')));
      expect(copy.body, 'Tomorrow, 8:00 AM · for you');
    });
  });

  group('the manual nudge', () {
    test('says what it is, so it does not read as a chat message', () {
      final r = _reminder(due: due);
      final msg = nudgeMessage(r, now: now);
      expect(msg, '⏰ Reminder: Take your meds · in 12 hours');
      expect(msg, startsWith('⏰'));
    });

    test('an overdue reminder nudges as "now", not as negative time', () {
      final r = _reminder(due: now.subtract(const Duration(hours: 3)));
      expect(nudgeMessage(r, now: now), '⏰ Reminder: Take your meds · now');
    });

    test('has a cooldown, so the button cannot be leaned on', () {
      // ⚠️ A control that reaches into somebody's pocket needs a floor under
      // it, or a flurry of taps teaches them to ignore it.
      expect(kNudgeCooldown.inSeconds, greaterThan(0));
    });
  });

  group('wiring', () {
    test('a run-up tap opens the reminders list, not the alarm screen', () {
      // 🔴 The scheduler spells this route out rather than importing Routes:
      // app_router.dart pulls in every screen, and reminder_scheduler.dart is
      // loaded by the background isolate. This is the guard on that copy.
      expect(ReminderScheduler.remindersRoute, Routes.reminders);
    });

    test('run-up payloads are told apart from the alarm', () {
      expect(ReminderScheduler.isCountdown('dayflower://reminder-soon/abc'),
          isTrue);
      // ⚠️ Must not be read as a ringing alarm — that would put a
      // full-screen Snooze/Done on a reminder still hours away.
      expect(ReminderScheduler.reminderIdOf('dayflower://reminder-soon/abc'),
          isNull);
      expect(ReminderScheduler.reminderIdOf('dayflower://reminder/abc'), 'abc');
      expect(ReminderScheduler.isCountdown('dayflower://reminder/abc'), isFalse);
    });
  });

  // ── Preview data ────────────────────────────────────────────────
  //
  // Dumps the *real* copy for the mockup, so what gets reviewed is what the
  // phone posts rather than something written twice. Skipped unless
  // REMINDER_PREVIEW_OUT names a file.
  test('dump preview data', () {
    final out = Platform.environment['REMINDER_PREVIEW_OUT'];
    if (out == null) return;

    final r = _reminder(due: due);
    final pings =
        countdownPings(r, now: now, includeJustSet: true).where((p) {
      return true;
    }).toList();

    final data = [
      for (final p in pings)
        for (final isMine in [true, false])
          () {
            // ⚠️ The name flips with the phone. On her phone the reminder is
            // for *me*, so "partnerName" there is my name — passing 'Sheena'
            // to both would have previewed her being told it was for herself.
            final c = pingCopy(p, r,
                isMine: isMine,
                partnerName: isMine ? 'Sheena' : 'Jc',
                now: now);
            return {
              'kind': p.kind.name,
              'isMine': isMine,
              'subText': c.subText,
              'title': c.title,
              'body': c.body,
              'alarm':
                  p.alarmsFor(isMine: isMine, reminderWantsAlarm: r.alarm),
              'at': p.at.toIso8601String(),
            };
          }(),
    ];
    File(out).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  });
}

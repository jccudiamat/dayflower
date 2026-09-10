/// The run-up to a reminder: what gets posted, when, and what it says.
///
/// Pure on purpose — no plugin, no clock of its own, no I/O. Everything the
/// phone actually posts is decided here, so the copy can be tested and
/// previewed without a device, and `ReminderScheduler` is left doing nothing
/// but handing the list to the OS.
library;

import '../data/reminder_repository.dart';

/// Which beat of the run-up a ping is.
enum ReminderPingKind {
  /// Posted the moment the reminder is created, to both phones.
  justSet,

  /// The hourly countdown through the final hours.
  hours,

  /// The reminder itself. An alarm for whoever it is for, a plain
  /// notification for the other half of the couple.
  due,
}

/// How long before a reminder the hourly run-up starts, and the one number
/// to change if it should reach further back.
///
/// Three hours: a ping at 3h, 2h and 1h, then the reminder itself. With the
/// "just set" notification that is five in total per reminder, per phone.
///
/// ⚠️ **Taken literally, "every hour until it is due" is unbounded**, and the
/// real data says that is 53 hours for the median reminder in this pair and
/// 277 for the longest — which repeats weekly. That one alone would post 277
/// notifications a week, forever, and a channel that behaves like that gets
/// muted. A muted channel misses the reminder that actually mattered, so the
/// bound is what makes the feature work rather than a compromise on it.
const kCountdownLeadHours = 3;

/// One notification in the run-up.
class ReminderPing {
  const ReminderPing({
    required this.kind,
    required this.at,
    required this.remaining,
  });

  final ReminderPingKind kind;

  /// When to post it.
  final DateTime at;

  /// How long before the reminder this lands. Zero for [ReminderPingKind.due]
  /// and for the "just set" ping, which is about the setting, not the wait.
  final Duration remaining;

  /// Whether this one should ring like an alarm clock rather than arrive as
  /// a banner. Only the real thing does, and only for the person it is for —
  /// twelve full-screen takeovers in an evening is not a countdown, it is a
  /// fault.
  bool alarmsFor({required bool isMine, required bool reminderWantsAlarm}) =>
      kind == ReminderPingKind.due && isMine && reminderWantsAlarm;
}

/// Every notification to post for [reminder], soonest first.
///
/// [now] is passed in rather than read, so this is deterministic and the
/// preview and the tests see exactly what the phone would.
///
/// ⚠️ Pings already in the past are dropped. Setting a reminder for twenty
/// minutes' time should give you the 15/10/5 pings and nothing else, not a
/// burst of twelve that are all overdue the moment they are scheduled.
List<ReminderPing> countdownPings(
  Reminder reminder, {
  required DateTime now,
  bool includeJustSet = false,
  /// The occurrence to count down to, when it is not [Reminder.remindAt] —
  /// a repeating reminder has been rolled forward to its next one by the
  /// time it reaches here.
  DateTime? due,
}) {
  due ??= reminder.remindAt;
  final pings = <ReminderPing>[];

  if (includeJustSet) {
    pings.add(ReminderPing(
      kind: ReminderPingKind.justSet,
      at: now,
      remaining: due.difference(now),
    ));
  }

  for (var h = kCountdownLeadHours; h >= 1; h--) {
    final at = due.subtract(Duration(hours: h));
    if (at.isAfter(now)) {
      pings.add(ReminderPing(
        kind: ReminderPingKind.hours,
        at: at,
        remaining: Duration(hours: h),
      ));
    }
  }

  if (due.isAfter(now)) {
    pings.add(ReminderPing(
      kind: ReminderPingKind.due,
      at: due,
      remaining: Duration.zero,
    ));
  }

  pings.sort((a, b) => a.at.compareTo(b.at));
  return pings;
}

/// "12 hours", "45 minutes", "1 hour".
String countdownLabel(Duration d) {
  if (d.inMinutes >= 60) {
    final h = d.inHours;
    return h == 1 ? '1 hour' : '$h hours';
  }
  final m = d.inMinutes;
  return m == 1 ? '1 minute' : '$m minutes';
}

/// "8:00 AM", "Tomorrow, 8:00 AM", "Thu 12 Sep, 8:00 AM".
String whenLabel(DateTime at, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final days = day.difference(today).inDays;
  final clock = _clock(at);
  if (days == 0) return clock;
  if (days == 1) return 'Tomorrow, $clock';
  if (days > 1 && days < 7) return '${_weekday(at)}, $clock';
  return '${_weekday(at)} ${at.day} ${_month(at)}, $clock';
}

String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _weekday(DateTime t) => _weekdays[t.weekday - 1];
String _month(DateTime t) => _months[t.month - 1];

/// What a manual nudge says when it lands in the conversation — and, because
/// a message *is* how this app moves anything between two phones, what the
/// notification on their phone says too.
///
/// ⚠️ Leads with the clock emoji and the word "Reminder" so it cannot be
/// mistaken for an ordinary message in the thread. It is one, structurally;
/// it is not one to read.
String nudgeMessage(Reminder reminder, {required DateTime now}) {
  final left = reminder.remindAt.isAfter(now)
      ? 'in ${countdownLabel(reminder.remindAt.difference(now))}'
      : 'now';
  return '⏰ Reminder: ${reminder.title} · $left';
}

/// What the notification says.
///
/// ⚠️ The countdown goes in [subText] rather than the title. Android shows
/// subText on the collapsed row beside the app name and never truncates it,
/// while a title long enough to carry both the time left and the reminder
/// gets cut off exactly where the useful half is.
class ReminderPingCopy {
  const ReminderPingCopy({
    required this.subText,
    required this.title,
    required this.body,
    required this.ticker,
  });

  /// Small line beside the app name: "in 15 minutes".
  final String subText;

  /// Bold line: the emoji and the reminder.
  final String title;

  /// Under it: when it is due, whose it is, and any note.
  final String body;

  /// Read aloud by accessibility services when it arrives.
  final String ticker;
}

/// Builds the copy for one ping.
///
/// [isMine] is whether the reminder is *for* the person holding this phone.
/// Both halves of the couple get every ping — that is the point — so the
/// wording has to say whose it is, or a reminder about their medication
/// reads as one about yours.
ReminderPingCopy pingCopy(
  ReminderPing ping,
  Reminder reminder, {
  required bool isMine,
  required String partnerName,
  required DateTime now,
}) {
  final title = '${reminder.emoji}  ${reminder.title}';
  final note = reminder.note?.trim();
  final whose = isMine ? 'for you' : 'for $partnerName';
  final when = whenLabel(reminder.remindAt, now: now);

  switch (ping.kind) {
    case ReminderPingKind.justSet:
      final who = isMine ? '$partnerName set a reminder' : 'Reminder set';
      return ReminderPingCopy(
        subText: 'new reminder',
        title: title,
        body: '$when · $whose${note != null && note.isNotEmpty ? ' · $note' : ''}',
        ticker: '$who: ${reminder.title}, $when',
      );

    case ReminderPingKind.hours:
      final left = countdownLabel(ping.remaining);
      return ReminderPingCopy(
        subText: 'in $left',
        title: title,
        body: '$when · $whose${note != null && note.isNotEmpty ? ' · $note' : ''}',
        ticker: '${reminder.title} in $left, $whose',
      );

    case ReminderPingKind.due:
      // ⚠️ The partner's copy keeps "for <name>" even when there is a note.
      // Dropping it left her phone saying "Take your meds / the blue one,
      // with food" at 8am with nothing to say it was his — which is the one
      // confusion this whole wording exists to prevent.
      final hasNote = note != null && note.isNotEmpty;
      return ReminderPingCopy(
        subText: 'now',
        title: title,
        body: isMine
            ? (hasNote ? note : 'It is time')
            : (hasNote ? '$whose · $note' : whose),
        ticker: '${reminder.title}, now, $whose',
      );
  }
}

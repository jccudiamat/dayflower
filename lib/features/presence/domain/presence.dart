import 'package:intl/intl.dart';

/// How recent a heartbeat has to be to count as "now".
///
/// The app beats once a minute, so anything inside two minutes is someone
/// who is holding their phone. Tighter than that and a missed beat on a bad
/// connection would flicker them offline while they are typing to you.
const activeWindow = Duration(minutes: 2);

/// How often a phone says it is here.
///
/// 🔴 Must stay well inside [activeWindow] — at least twice as often, so one
/// beat lost to a bad connection does not blink somebody offline while they
/// are typing to you. Pinned by a test, because the two numbers live one
/// line apart and will still drift.
const beatEvery = Duration(minutes: 1);

/// The one line under their name in the chat header.
///
/// Null means say nothing at all. That is the honest answer to a partner on
/// a build that has never written a heartbeat, and it is a better header
/// than "Active a long time ago" — which reads as a fact when it is really
/// an absence of one.
///
/// ⚠️ Deliberately coarse past the first hour. A chat header is not a log:
/// "Active at 2:31 PM" is useful, "Active 4 hours and 12 minutes ago" is
/// surveillance, and the difference costs nothing to get right here.
String? activeLabel(DateTime? lastActive, {DateTime? now}) {
  if (lastActive == null) return null;
  // The column is timestamptz and decodes as UTC; everything compared
  // against it here is wall-clock local. A no-op if it is local already.
  final at = lastActive.toLocal();
  final clock = now ?? DateTime.now();
  final gap = clock.difference(at);

  // A clock that disagrees between two phones can put this slightly in the
  // future. "Active now" is the right answer to that, not "in 3 minutes".
  if (gap.isNegative || gap < activeWindow) return 'Active now';
  if (gap < const Duration(hours: 1)) {
    final minutes = gap.inMinutes;
    return 'Active $minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
  }

  final today = DateTime(clock.year, clock.month, clock.day);
  final day = DateTime(at.year, at.month, at.day);
  if (day == today) return 'Active at ${DateFormat('h:mm a').format(at)}';
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Active yesterday at ${DateFormat('h:mm a').format(at)}';
  }
  if (today.difference(day).inDays < 7) {
    return 'Active ${DateFormat('EEEE').format(at)}';
  }
  return 'Active ${DateFormat('d MMM').format(at)}';
}

import 'package:timezone/timezone.dart' as tz;

/// Zone helpers, with no Flutter in them.
///
/// These used to live in `core/widgets/timezone_picker.dart`, which meant
/// anything wanting to know what day it is somewhere had to import a widget
/// file. [UserProfile.freshMood] needs exactly that and is a plain model, so
/// the two pure functions moved here. The picker still exports them, so
/// existing imports are unaffected.

/// Never throws on an unknown or stale zone name — falls back to UTC.
///
/// ⚠️ Also falls back to UTC when the database has not been loaded
/// (`initializeTimeZones()` in main). That is the right failure for a clock
/// face, but it means a test that cares about a real zone has to initialise
/// the database or it will silently be testing UTC.
tz.Location safeLocation(String name) {
  try {
    return tz.getLocation(name);
  } catch (_) {
    return tz.UTC;
  }
}

/// Human-readable city from an IANA zone ("Asia/Manila" → "Manila").
String zoneCity(String zone) => zone.split('/').last.replaceAll('_', ' ');

/// Whether [at] and [now] fall on the same calendar day **in [zone]**.
///
/// Not "within 24 hours". A day is where the mood resets, and the two are
/// different things: 23 hours can span two days, and two moments 30 minutes
/// apart can too. See [UserProfile.freshMood].
bool isSameDayIn(String zone, DateTime at, {DateTime? now}) {
  final where = safeLocation(zone);
  final then = tz.TZDateTime.from(at, where);
  final today = tz.TZDateTime.from(now ?? DateTime.now(), where);
  return then.year == today.year &&
      then.month == today.month &&
      then.day == today.day;
}

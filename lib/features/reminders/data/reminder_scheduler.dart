import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/services/app_notifications.dart';
import 'reminder_repository.dart';

/// How long Snooze pushes a ringing alarm out for.
///
/// Nine minutes because that is what every alarm clock since the 1950s has
/// used and the muscle memory is worth more than a rounder number.
const kSnoozeDuration = Duration(minutes: 9);

/// Turns the reminders aimed at *me* into scheduled OS alarms.
///
/// **This is what makes a reminder your partner set actually go off.** The
/// row lands via realtime while the app is open; the OS then holds the
/// alarm, so it still fires with the app closed — unlike heartbeat alerts,
/// which need a live stream at the moment they arrive.
///
/// ## What makes it an alarm rather than a banner
///
/// Four things together, and dropping any one of them turns it back into a
/// notification you sleep through:
///
///  1. **`AudioAttributesUsage.alarm`** — plays on the *alarm* stream, so it
///     is audible with the ringer silenced and at alarm volume. This is the
///     single most important one: a notification-stream sound on a phone in
///     do-not-disturb makes no noise at all.
///  2. **A 30-second sound** (`res/raw/alarm.wav`, see
///     `tools/generate_alarm_wav.py`). Notification sounds play once and do
///     not loop, so the *file* has to be long enough to wake someone.
///  3. **`fullScreenIntent`** plus `showWhenLocked`/`turnScreenOn` on
///     MainActivity — the alarm takes over the screen instead of sliding in
///     as a strip.
///  4. **`ongoing: true` + `autoCancel: false`** — it cannot be swiped away.
///     Snooze and Done are the only ways out, which is the whole point.
///
/// ## The two limitations worth knowing
///
/// 🔴 **The recipient's app has to open at least once between the reminder
/// being created and the time it should fire.** There is no push backend,
/// so nothing can hand the alarm to their phone while the app is closed.
/// Set one for tonight and they have not opened Dayflower since yesterday,
/// and it never rings. Fixing that needs FCM/APNs plus an edge function.
///
/// ⚠️ **Exact alarms need a permission the user must grant** (Android 12+).
/// Without it `exactAllowWhileIdle` silently degrades to an inexact alarm
/// that can drift by minutes in doze. [ensureAlarmPermissions] asks.
class ReminderScheduler {
  ReminderScheduler._();

  /// Android freezes a channel's sound, importance and vibration at
  /// creation — they can **never** be changed in code afterwards. Bump the
  /// `_v` suffix whenever any of them changes, or the new settings are
  /// invisible on every phone that already ran the app.
  ///
  /// `reminders_v1` was the pre-alarm channel (importance high, default
  /// notification sound). It is deliberately not reused: a phone that had
  /// created it would have kept ringing at notification volume forever.
  static const _alarmChannelId = 'reminders_alarm_v1';
  static const _quietChannelId = 'reminders_quiet_v1';

  /// 30 seconds of beeping. Named only from here, so it must stay listed in
  /// `res/raw/keep.xml` or the release shrinker strips it and the alarm
  /// posts silently.
  static const _alarmSound = 'alarm';

  /// Roughly the duration of the sound, so the phone buzzes for as long as
  /// it rings rather than giving one polite tick.
  /// Android format: [wait, buzz, wait, buzz, …].
  static final _vibrationPattern = Int64List.fromList([
    for (var i = 0; i < 15; i++) ...[500, 1000],
  ]);

  /// Every notification this class owns carries it, which is how [sync]
  /// tells its own pending alarms apart from the heartbeat and nudge ones
  /// and only cancels what it is allowed to.
  static const _payloadPrefix = 'dayflower://reminder/';

  static const actionSnooze = 'reminder_snooze';
  static const actionDone = 'reminder_done';

  static final _plugin = AppNotifications.plugin;
  static bool _initialised = false;

  static bool get supported => AppNotifications.supported;

  /// The reminder id carried by [payload], or null if it isn't ours.
  static String? reminderIdOf(String? payload) =>
      (payload != null && payload.startsWith(_payloadPrefix))
          ? payload.substring(_payloadPrefix.length)
          : null;

  static Future<void> init() async {
    if (!supported || _initialised) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _alarmChannelId,
          'Reminder alarms',
          description:
              'Reminders set to ring. Sounds at alarm volume and takes over '
              'the screen.',
          importance: Importance.max,
          sound: const RawResourceAndroidNotificationSound(_alarmSound),
          // The line that makes this an alarm and not a notification.
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
          vibrationPattern: _vibrationPattern,
          // An alarm the user asked for should still ring in do-not-disturb;
          // that is what they set it for. The quiet channel below is the
          // opt-out.
          bypassDnd: true,
          enableLights: true,
        ),
      );

      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _quietChannelId,
          'Reminder notifications',
          description: 'Reminders set to notify quietly, without ringing.',
          importance: Importance.defaultImportance,
        ),
      );

      _initialised = true;
    } catch (e) {
      debugPrint('reminder scheduler init failed: $e');
    }
  }

  /// Asks for everything an alarm needs. Advisory — each is reported
  /// separately so the caller can tell the user precisely what is missing
  /// instead of a blanket "notifications are off".
  ///
  /// Android only; on iOS the notification permission covers it and the
  /// rest have no equivalent.
  static Future<AlarmPermissions> ensureAlarmPermissions() async {
    if (!supported) return const AlarmPermissions.unsupported();
    await init();
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true, badge: false);
        return AlarmPermissions(
          notifications: granted ?? false,
          exactAlarms: true,
          fullScreen: true,
        );
      }

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      final notifications =
          await android?.requestNotificationsPermission() ?? false;

      // Already-granted returns true without showing anything, so this is
      // safe to call on every launch.
      var exact = await android?.canScheduleExactNotifications() ?? false;
      if (!exact) {
        // Opens the system screen — it cannot be granted in-app.
        exact = await android?.requestExactAlarmsPermission() ?? false;
      }

      final fullScreen =
          await android?.requestFullScreenIntentPermission() ?? false;

      return AlarmPermissions(
        notifications: notifications,
        exactAlarms: exact,
        fullScreen: fullScreen,
      );
    } catch (e) {
      debugPrint('alarm permission request failed: $e');
      return const AlarmPermissions.unsupported();
    }
  }

  /// Makes the phone's pending alarms match [reminders] exactly.
  ///
  /// Cancel-everything-then-reschedule rather than diffing: the source of
  /// truth is a realtime list that can change in any direction at once
  /// (the partner edits a time, deletes one, adds three), and a wrong diff
  /// leaves a silent alarm behind that nothing will ever clean up.
  static Future<void> sync(List<Reminder> reminders) async {
    if (!supported) return;
    await init();

    try {
      await _cancelOurs();

      final now = DateTime.now();
      for (final reminder in reminders) {
        if (reminder.isDone) continue;
        // A one-off whose time has already passed has nothing left to
        // schedule; it stays on the list in-app as overdue. A repeating
        // one is always schedulable — the OS handles the recurrence.
        if (!reminder.repeats && !reminder.remindAt.isAfter(now)) continue;
        await _schedule(reminder);
      }
    } catch (e) {
      debugPrint('reminder sync failed: $e');
    }
  }

  /// Clears every alarm this class owns — used on sign-out, so the next
  /// person to use the phone isn't woken by a stranger's dentist.
  static Future<void> cancelAll() async {
    if (!supported) return;
    try {
      await _cancelOurs();
    } catch (e) {
      debugPrint('reminder cancelAll failed: $e');
    }
  }

  /// Stops one alarm that is currently ringing, without touching the
  /// schedule. Snooze and Done both go through here first so the noise
  /// stops the instant the button is hit, before the database round trip.
  static Future<void> stopRinging(String reminderId) async {
    if (!supported) return;
    try {
      await _plugin.cancel(id: _notificationId(reminderId));
    } catch (e) {
      debugPrint('reminder stopRinging failed: $e');
    }
  }

  /// Puts a single reminder on the phone **without touching any other
  /// pending alarm**.
  ///
  /// [sync] cannot be used for this: it cancels everything this class owns
  /// first, so calling it with one reminder unschedules all the rest. That
  /// matters most in the background isolate, which only knows about the one
  /// reminder whose button was pressed.
  static Future<void> scheduleOne(Reminder reminder) async {
    if (!supported) return;
    await init();
    try {
      await _schedule(reminder);
    } catch (e) {
      debugPrint('reminder scheduleOne failed: $e');
    }
  }

  static Future<void> _cancelOurs() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith(_payloadPrefix) ?? false) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  static Future<void> _schedule(Reminder reminder) async {
    var when = reminder.remindAt;
    if (reminder.repeats) {
      // `matchDateTimeComponents` only matches on time-of-day (or weekday
      // + time), so the date it is given has to already be in the future
      // or the first fire is skipped.
      final now = DateTime.now();
      while (!when.isAfter(now)) {
        when = reminder.repeat.nextAfter(when)!;
      }
    }

    final alarm = reminder.alarm;

    await _plugin.zonedSchedule(
      id: _notificationId(reminder.id),
      title: '${reminder.emoji}  ${reminder.title}',
      body: reminder.note?.trim().isNotEmpty == true
          ? reminder.note!.trim()
          : (alarm ? 'Time to get up' : 'A reminder from Dayflower'),
      // `tz.local` is UTC here — nothing calls `setLocalLocation`, and no
      // package in the project reads the device zone. It doesn't matter:
      // `TZDateTime.from` preserves the *instant*, and the instant is what
      // the OS schedules against. Only `matchDateTimeComponents` reasons
      // about wall-clock fields, and daily/weekly repeats land on the same
      // instant either way.
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          alarm ? _alarmChannelId : _quietChannelId,
          alarm ? 'Reminder alarms' : 'Reminder notifications',
          importance: alarm ? Importance.max : Importance.defaultImportance,
          priority: alarm ? Priority.max : Priority.defaultPriority,
          // `alarm` (not `reminder`) is what tells the OS this may interrupt
          // like a clock; `reminder` is explicitly the gentler class.
          category: alarm
              ? AndroidNotificationCategory.alarm
              : AndroidNotificationCategory.reminder,
          sound: alarm
              ? const RawResourceAndroidNotificationSound(_alarmSound)
              : null,
          audioAttributesUsage: alarm
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
          vibrationPattern: alarm ? _vibrationPattern : null,
          // Takes over the screen instead of arriving as a heads-up strip.
          fullScreenIntent: alarm,
          // An alarm you can swipe away is a notification. Snooze and Done
          // are the only exits.
          ongoing: alarm,
          autoCancel: !alarm,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              actionSnooze,
              'Snooze ${kSnoozeDuration.inMinutes} min',
              // Handled in the background isolate — the app must not have
              // to come to the foreground just to snooze.
              showsUserInterface: false,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              actionDone,
              'Done',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          // ⚠️ iOS gets the DEFAULT sound, not alarm.wav. The file lives in
          // Android's res/raw and would have to be added to the Runner
          // target in Xcode to exist on iOS at all — exactly the same gap
          // as heartbeat.wav. Naming it here without doing that would fall
          // back to the default chime anyway, just less visibly.
          //
          // iOS also has no full-screen intent and no alarm audio stream
          // for local notifications, so timeSensitive (which does pierce
          // Focus modes) is genuinely as close to an alarm as a
          // third-party app gets without a push backend. A real iOS alarm
          // is the system Clock app.
          interruptionLevel: alarm
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
      // Exact alarms survive doze; a reminder that fires an hour late
      // because the phone was idle is a reminder that failed. Silently
      // degrades to inexact without SCHEDULE_EXACT_ALARM — see
      // [ensureAlarmPermissions].
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: _repeatComponents(reminder.repeat),
      payload: '$_payloadPrefix${reminder.id}',
    );
  }

  /// Monthly has no `DateTimeComponents` equivalent, so it schedules as a
  /// single alarm and is rolled forward by
  /// [ReminderRepository.markDone] / the next [sync] instead.
  static DateTimeComponents? _repeatComponents(ReminderRepeat repeat) {
    switch (repeat) {
      case ReminderRepeat.none:
      case ReminderRepeat.monthly:
        return null;
      case ReminderRepeat.daily:
        return DateTimeComponents.time;
      case ReminderRepeat.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
    }
  }

  /// Notification ids are ints and reminder ids are uuids, so the id has to
  /// be derived. `hashCode` is stable within a run and across runs for a
  /// String in the Dart VM; masked to 31 bits because the Android API
  /// takes a signed int.
  static int _notificationId(String reminderId) =>
      reminderId.hashCode & 0x7fffffff;
}

/// What an alarm is actually allowed to do on this device. Reported field
/// by field so the UI can name the one that is missing.
class AlarmPermissions {
  const AlarmPermissions({
    required this.notifications,
    required this.exactAlarms,
    required this.fullScreen,
  });

  /// Web and desktop: nothing to grant, nothing works.
  const AlarmPermissions.unsupported()
      : notifications = false,
        exactAlarms = false,
        fullScreen = false;

  final bool notifications;
  final bool exactAlarms;
  final bool fullScreen;

  /// Everything an alarm needs. Missing [fullScreen] alone still rings — it
  /// just arrives as a heads-up strip rather than taking over the screen —
  /// so it is not part of this.
  bool get canRing => notifications && exactAlarms;
}

/// The reminder whose alarm should be on screen right now, or null.
///
/// A plain notification tap arrives in a callback with no `BuildContext`
/// and no `WidgetRef`, so it cannot navigate. It parks the id here instead
/// and `DayflowerApp` — which has the router — watches this and opens
/// [Routes.alarm]. Cleared by the app once it has navigated, so the same
/// tap can't reopen the screen after the user has left it.
final ValueNotifier<String?> ringingReminderId = ValueNotifier<String?>(null);

/// Handles a notification tap **while the app is alive**.
///
/// Only plain taps reach here. Snooze and Done declare
/// `showsUserInterface: false`, so Android routes them to the background
/// isolate ([reminderActionBackground]) whether or not the app is running —
/// which is the point: snoozing must not require the app to come up.
void handleNotificationTap(NotificationResponse response) {
  final reminderId = ReminderScheduler.reminderIdOf(response.payload);
  if (reminderId == null) return;
  if (response.actionId != null) return; // an action, handled in background
  ringingReminderId.value = reminderId;
}

/// Handles Snooze / Done **when the app is not running**.
///
/// Runs in its own isolate: nothing from the app exists here, so Supabase
/// has to be re-initialised from scratch, exactly like the home-screen
/// widget's background send. Supabase restores the persisted session
/// itself, which is what lets this write as whoever is signed in.
///
/// Must stay a top-level function with the `vm:entry-point` pragma — the
/// tree shaker cannot see that Android calls it, and an anonymous closure
/// cannot be handed across the isolate boundary at all.
@pragma('vm:entry-point')
Future<void> reminderActionBackground(NotificationResponse response) async {
  final reminderId = ReminderScheduler.reminderIdOf(response.payload);
  if (reminderId == null) return;

  final action = response.actionId;
  if (action != ReminderScheduler.actionSnooze &&
      action != ReminderScheduler.actionDone) {
    // A plain tap opens the app, which handles it in the foreground.
    return;
  }

  try {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return; // signed out

    final rows = await client
        .from('reminders')
        .select()
        .eq('id', reminderId)
        .limit(1);
    if (rows.isEmpty) return;
    final reminder = Reminder.fromMap(rows.first);
    final repository = ReminderRepository(client);

    if (action == ReminderScheduler.actionSnooze) {
      final next = DateTime.now().add(kSnoozeDuration);
      await repository.snooze(reminder, kSnoozeDuration);
      // Nothing else will reschedule this until the app next runs a sync,
      // so this isolate has to put the alarm back on the phone itself —
      // otherwise Snooze would quietly mean Dismiss.
      //
      // scheduleOne, never sync: sync cancels every pending reminder alarm
      // first, and this isolate has only loaded one of them.
      await ReminderScheduler.scheduleOne(
        Reminder(
          id: reminder.id,
          pairId: reminder.pairId,
          createdBy: reminder.createdBy,
          forUser: reminder.forUser,
          title: reminder.title,
          note: reminder.note,
          emoji: reminder.emoji,
          remindAt: next,
          // A snoozed alarm fires once at the snoozed time. Keeping the
          // repeat rule here would hand matchDateTimeComponents a new
          // time-of-day and quietly move the whole daily series.
          repeat: ReminderRepeat.none,
          alarm: reminder.alarm,
        ),
      );
    } else {
      await repository.markDone(reminder);
    }
  } catch (e) {
    debugPrint('reminder background action failed: $e');
  }
}

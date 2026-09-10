import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/services/app_notifications.dart';
import '../../calls/data/call_alerts.dart';
import '../domain/reminder_countdown.dart';
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

  /// The run-up: "in 3 hours", "in 5 minutes", and the partner's copy of the
  /// reminder itself.
  ///
  /// ⚠️ Its own channel, at `high` rather than `max`. High peeks as a heads-up
  /// banner with sound and vibration — noticeable, which is the whole point —
  /// but it is dismissible and does not take over the screen. Twelve
  /// full-screen takeovers in an evening is not a countdown, it is a fault,
  /// and it is also what makes somebody turn the whole thing off.
  ///
  /// Separate from the other two so it can be silenced on its own: a person
  /// who wants the alarm but not the countdown has somewhere to go.
  static const _countdownChannelId = 'reminders_countdown_v1';

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

  /// Run-up pings. A separate prefix so a tap on one does **not** open the
  /// ringing-alarm screen for a reminder that is not ringing — and so
  /// [_cancelOurs] still knows they are ours to clear.
  static const _countdownPrefix = 'dayflower://reminder-soon/';

  /// Where a run-up tap lands.
  ///
  /// ⚠️ Spelled out rather than imported from `Routes`: app_router.dart pulls
  /// in every screen in the app, and this file is loaded by the background
  /// isolate. `reminder_countdown_routes_test` asserts the two stay equal.
  static const remindersRoute = '/app/activities/reminders';

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

  /// True when [payload] belongs to a run-up ping rather than the alarm.
  static bool isCountdown(String? payload) =>
      payload != null && payload.startsWith(_countdownPrefix);

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

      // The run-up. High, not max: it peeks as a heads-up banner and makes a
      // noise, and it can be swiped away. See _countdownChannelId.
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _countdownChannelId,
          'Reminder countdown',
          description:
              'The run-up to a reminder — hourly, then every five minutes in '
              'the last hour, on both phones.',
          importance: Importance.high,
          enableVibration: true,
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
  static Future<void> sync(
    List<Reminder> reminders, {
    String? myUserId,
    String partnerName = 'your partner',
  }) async {
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
        await _schedule(
          reminder,
          isMine: myUserId == null || reminder.isFor(myUserId),
          partnerName: partnerName,
        );
      }
    } catch (e) {
      debugPrint('reminder sync failed: $e');
    }
  }

  /// Posts "a reminder was just set", on both phones, for anything created
  /// since this one last looked.
  ///
  /// WARNING: marked by `created_at`, the same shape as PartnerAlerts,
  /// because the realtime list is re-delivered constantly — on reconnect, on
  /// any edit, on every app open — and announcing on sight would fire the
  /// same notification over and over.
  ///
  /// A fresh install takes what is already there as the baseline and says
  /// nothing: arriving on a new phone is no reason to be told about a
  /// reminder set last Tuesday.
  static Future<void> announceNew(
    List<Reminder> reminders, {
    required String? myUserId,
    required String partnerName,
  }) async {
    if (!supported || reminders.isEmpty) return;
    await init();

    try {
      final stamped =
          reminders.where((r) => r.createdAt != null).toList(growable: false);
      if (stamped.isEmpty) return;

      final newest = stamped
          .map((r) => r.createdAt!.millisecondsSinceEpoch)
          .reduce((a, b) => a > b ? a : b);

      final prefs = await SharedPreferences.getInstance();
      const markKey = 'reminder_set_mark';
      final mark = prefs.getInt(markKey);
      if (mark == null) {
        await prefs.setInt(markKey, newest);
        return;
      }
      if (newest <= mark) return;
      await prefs.setInt(markKey, newest);

      final now = DateTime.now();
      for (final reminder in stamped) {
        if (reminder.createdAt!.millisecondsSinceEpoch <= mark) continue;
        if (reminder.isDone) continue;
        if (!reminder.repeats && !reminder.remindAt.isAfter(now)) continue;

        final ping = ReminderPing(
          kind: ReminderPingKind.justSet,
          at: now,
          remaining: reminder.remindAt.difference(now),
        );
        await _post(
          id: _pingId(reminder.id, ping),
          reminder: reminder,
          ping: ping,
          isMine: myUserId == null || reminder.isFor(myUserId),
          partnerName: partnerName,
          // Now, not scheduled.
          at: null,
        );
      }
    } catch (e) {
      debugPrint('reminder announce failed: $e');
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
      // WARNING: the reminder itself and nothing else. This is the snooze
      // path, running in the background isolate: a run-up counting down to
      // a time nine minutes away would post three notifications on top of
      // the alarm somebody has just snoozed.
      final ping = ReminderPing(
        kind: ReminderPingKind.due,
        at: reminder.remindAt,
        remaining: Duration.zero,
      );
      await _post(
        id: _pingId(reminder.id, ping),
        reminder: reminder,
        ping: ping,
        isMine: true,
        partnerName: 'your partner',
        at: reminder.remindAt,
      );
    } catch (e) {
      debugPrint('reminder scheduleOne failed: $e');
    }
  }

  static Future<void> _cancelOurs() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      final payload = request.payload ?? '';
      if (payload.startsWith(_payloadPrefix) ||
          payload.startsWith(_countdownPrefix)) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  /// Everything this reminder should post: the run-up, then the reminder.
  static Future<void> _schedule(
    Reminder reminder, {
    required bool isMine,
    required String partnerName,
  }) async {
    final now = DateTime.now();
    var when = reminder.remindAt;
    if (reminder.repeats) {
      // `matchDateTimeComponents` only matches on time-of-day (or weekday
      // + time), so the date it is given has to already be in the future
      // or the first fire is skipped.
      while (!when.isAfter(now)) {
        when = reminder.repeat.nextAfter(when)!;
      }
    }

    // WARNING: for a repeating reminder the OS re-fires the *due* alarm on
    // its own, but the run-up is one-shot against the next occurrence — the
    // offsets differ per ping, so there is nothing for
    // matchDateTimeComponents to match. The next occurrence's run-up is
    // scheduled by the next [sync], which is the same "the app has to open"
    // limitation this class already has for reminders in general.
    for (final ping in countdownPings(reminder, now: now, due: when)) {
      await _post(
        id: _pingId(reminder.id, ping),
        reminder: reminder,
        ping: ping,
        isMine: isMine,
        partnerName: partnerName,
        at: ping.at,
        due: when,
      );
    }
  }

  /// Posts one notification — scheduled when [at] is given, immediately when
  /// it is not.
  static Future<void> _post({
    required int id,
    required Reminder reminder,
    required ReminderPing ping,
    required bool isMine,
    required String partnerName,
    required DateTime? at,
    DateTime? due,
  }) async {
    final rings =
        ping.alarmsFor(isMine: isMine, reminderWantsAlarm: reminder.alarm);
    final isDue = ping.kind == ReminderPingKind.due;
    final counts = !isDue && due != null;
    final copy = pingCopy(
      ping,
      reminder,
      isMine: isMine,
      partnerName: partnerName,
      now: at ?? DateTime.now(),
    );

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        rings
            ? _alarmChannelId
            : isDue
                ? _quietChannelId
                : _countdownChannelId,
        rings
            ? 'Reminder alarms'
            : isDue
                ? 'Reminder notifications'
                : 'Reminder countdown',
        importance: rings
            ? Importance.max
            : isDue
                ? Importance.defaultImportance
                : Importance.high,
        priority: rings
            ? Priority.max
            : isDue
                ? Priority.defaultPriority
                : Priority.high,
        // `alarm` (not `reminder`) is what tells the OS this may interrupt
        // like a clock; `reminder` is explicitly the gentler class.
        category: rings
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        // The countdown, on the collapsed row beside the app name. It goes
        // here rather than in the title because Android never truncates
        // subText and does truncate a long title.
        subText: copy.subText,
        ticker: copy.ticker,
        // WARNING: a live counter ticking down inside the notification, so a
        // glance answers "how long have I got" without opening anything —
        // and it stays right in the gaps between pings.
        when: counts ? due.millisecondsSinceEpoch : null,
        usesChronometer: counts,
        chronometerCountDown: counts,
        // Tints the icon and title. Cheap, and it is what makes these read
        // as one running thread rather than seven unrelated banners.
        color: _brand,
        sound: rings
            ? const RawResourceAndroidNotificationSound(_alarmSound)
            : null,
        audioAttributesUsage: rings
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        vibrationPattern: rings ? _vibrationPattern : null,
        // Takes over the screen instead of arriving as a heads-up strip.
        // Only the real thing does. A full-screen takeover every five
        // minutes for an hour is what makes somebody turn the feature off.
        fullScreenIntent: rings,
        // An alarm you can swipe away is a notification. Snooze and Done
        // are the only exits.
        ongoing: rings,
        autoCancel: !rings,
        actions: rings
            ? <AndroidNotificationAction>[
                AndroidNotificationAction(
                  actionSnooze,
                  'Snooze ${kSnoozeDuration.inMinutes} min',
                  // Handled in the background isolate — the app must not
                  // have to come to the foreground just to snooze.
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
                const AndroidNotificationAction(
                  actionDone,
                  'Done',
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
              ]
            : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        subtitle: copy.subText,
        // WARNING: iOS gets the DEFAULT sound, not alarm.wav. The file lives
        // in Android's res/raw and would have to be added to the Runner
        // target in Xcode to exist on iOS at all — exactly the same gap as
        // heartbeat.wav. Naming it here without doing that would fall back
        // to the default chime anyway, just less visibly.
        //
        // iOS also has no full-screen intent and no alarm audio stream for
        // local notifications, so timeSensitive (which does pierce Focus
        // modes) is genuinely as close to an alarm as a third-party app gets
        // without a push backend. A real iOS alarm is the system Clock app.
        interruptionLevel: rings
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      ),
    );

    final payload = isDue
        ? '$_payloadPrefix${reminder.id}'
        : '$_countdownPrefix${reminder.id}';

    if (at == null) {
      await _plugin.show(
        id: id,
        title: copy.title,
        body: copy.body,
        notificationDetails: details,
        payload: payload,
      );
      return;
    }

    await _plugin.zonedSchedule(
      id: id,
      title: copy.title,
      body: copy.body,
      // `tz.local` is UTC here — nothing calls `setLocalLocation`, and no
      // package in the project reads the device zone. It doesn't matter:
      // `TZDateTime.from` preserves the *instant*, and the instant is what
      // the OS schedules against. Only `matchDateTimeComponents` reasons
      // about wall-clock fields, and daily/weekly repeats land on the same
      // instant either way.
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: details,
      // Exact alarms survive doze; a reminder that fires an hour late
      // because the phone was idle is a reminder that failed. Silently
      // degrades to inexact without SCHEDULE_EXACT_ALARM — see
      // [ensureAlarmPermissions].
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // Only the reminder itself repeats. See the note in _schedule.
      matchDateTimeComponents:
          isDue ? _repeatComponents(reminder.repeat) : null,
      payload: payload,
    );
  }

  /// The brand pink, spelled out rather than imported: app_colors.dart is a
  /// UI file and this one is loaded by the background isolate too.
  static const _brand = Color(0xFFEE6FA8);

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

  /// A stable id per reminder *and* per beat of its run-up.
  ///
  /// WARNING: the due ping keeps [_notificationId] unchanged, because
  /// [stopRinging] cancels by that id and the background isolate computes it
  /// from the reminder id alone. Only the run-up gets derived ids.
  ///
  /// The salt keeps each beat of the run-up distinct, so "in 3 hours" and
  /// "in 1 hour" cannot collide and silently replace one another.
  static int _pingId(String reminderId, ReminderPing ping) {
    if (ping.kind == ReminderPingKind.due) return _notificationId(reminderId);
    final salt = switch (ping.kind) {
      ReminderPingKind.hours => 1000 + ping.remaining.inHours,
      // The "just set" ping is posted immediately and never scheduled, so
      // it only needs an id nothing else uses.
      _ => 3000,
    };
    return (reminderId.hashCode ^ (salt * 2654435761)) & 0x7fffffff;
  }
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
/// It also dispatches every *other* notification the app posts, because the
/// plugin allows exactly one foreground handler for the whole process (see
/// the class doc on [AppNotifications]). It lives in this file rather than
/// in core because the alarm case is the one with real logic — the rest is
/// "open this route" and has none.
void handleNotificationTap(NotificationResponse response) {
  if (CallAlerts.handleTap(response)) return;
  if (response.actionId != null) return; // an action, handled in background

  final reminderId = ReminderScheduler.reminderIdOf(response.payload);
  if (reminderId != null) {
    ringingReminderId.value = reminderId;
    return;
  }

  // A run-up ping. It opens the list, NOT the ringing-alarm screen — there
  // is nothing ringing yet, and a full-screen Snooze/Done for a reminder
  // that is still an hour away would be nonsense.
  if (ReminderScheduler.isCountdown(response.payload)) {
    AppNotifications.pendingRoute.value = ReminderScheduler.remindersRoute;
    return;
  }

  // A message, a photo, an activity, a new build — anything whose whole
  // intent is a destination.
  final route = AppNotifications.routeOf(response.payload);
  if (route != null) AppNotifications.pendingRoute.value = route;
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
  final callId = CallAlerts.callIdOf(response.payload);
  if (callId != null && response.actionId == CallAlerts.actionDecline) {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load(fileName: '.env');
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']!,
        anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      );
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final call = await client.from('flower_messages').select('sender_id,call_mode')
          .eq('id', callId).maybeSingle();
      if (call == null || call['call_mode'] == null || call['sender_id'] == user.id) return;
      await client.rpc('end_call', params: {'p_message_id': callId});
    } catch (e) {
      debugPrint('call decline failed: $e');
    }
    return;
  }
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

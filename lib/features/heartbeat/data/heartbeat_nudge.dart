import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/services/app_notifications.dart';

/// A device-local reminder. Wording never claims the partner hasn't sent
/// anything: a scheduled notification cannot check live data when it fires.
class HeartbeatNudge {
  HeartbeatNudge._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Its own channel: Android freezes a channel's importance and sound at
  /// creation, so a nudge can never share one with pulses or reminders.
  static const _channelId = 'heartbeat_nudge_v1';
  static const _channelName = 'Heartbeat nudges';
  static const _channelDescription =
      "A daily reminder when you haven't sent a heartbeat.";

  /// Fixed id — there is only ever one of these pending, and re-scheduling
  /// the same id replaces rather than stacks.
  static const _id = 90111;

  static const _kEnabled = 'heartbeat_nudge_enabled';
  static const _kHour = 'heartbeat_nudge_hour';

  /// Early evening: late enough that not having tapped is meaningful, early
  /// enough that acting on it isn't a 2am text.
  static const defaultHour = 20;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool _initialised = false;

  /// Creates the channel. The plugin itself is a singleton already
  /// `initialize()`d by PulseAlerts from main(); only the channel is ours.
  static Future<void> init() async {
    if (!supported || _initialised) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.defaultImportance,
            ),
          );
      _initialised = true;
    } catch (e) {
      debugPrint('heartbeat nudge init failed: $e');
    }
  }

  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<int> hour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_kHour) ?? defaultHour;
    } catch (_) {
      return defaultHour;
    }
  }

  static Future<void> setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, value);
    } catch (e) {
      debugPrint('heartbeat nudge pref save failed: $e');
    }
    if (!value) await sync(sentToday: false, eligible: false);
  }

  static const title = 'A little love, in one tap 💗';
  static const body =
      'Send your partner a heartbeat from Dayflower or your widget.';

  static Future<void> _pending = Future.value();

  /// Serialize changes so a stale schedule cannot win over a cancellation.
  static Future<void> sync({
    required bool sentToday,
    bool eligible = true,
  }) {
    _pending = _pending.then((_) => _sync(
          sentToday: sentToday,
          eligible: eligible,
        ));
    return _pending;
  }

  static Future<void> _sync({
    required bool sentToday,
    required bool eligible,
  }) async {
    if (!supported) return;
    if (!eligible || sentToday || !await isEnabled()) {
      await _cancel();
      return;
    }
    try {
      await _cancel();

      final at = await hour();
      final now = DateTime.now();
      var when = DateTime(now.year, now.month, now.day, at);
      // No reminder is armed for a day on which we know you already sent one.
      if (!when.isAfter(now)) {
        when = DateTime(now.year, now.month, now.day + 1, at);
      }

      await _plugin.zonedSchedule(
        id: _id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // Deliberately inexact, unlike Reminders: a nudge that slides a few
        // minutes to save battery has lost nothing, and exact alarms are a
        // permission worth spending only on things the user explicitly set.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: AppNotifications.payloadForRoute('/app/home'),
      );
    } catch (e) {
      debugPrint('heartbeat nudge schedule failed: $e');
    }
  }

  static Future<void> _cancel() async {
    try {
      await _plugin.cancel(id: _id);
    } catch (e) {
      debugPrint('heartbeat nudge cancel failed: $e');
    }
  }
}

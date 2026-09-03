import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_notifications.dart';

/// Notifications for the things the partner does: messages, day photos, and
/// entries in the shared activity feed.
///
/// ⚠️ **Read this before trusting it to wake a phone.**
///
/// There is no push backend in this project. Everything here is a *local*
/// notification, raised by this device in response to a Supabase realtime
/// event — which means it only fires while the app's process is alive and
/// its websocket is connected. That covers the common case by a wide
/// margin: the app backgrounded a few minutes ago and is still resident.
/// It does **not** cover a phone that has swiped the app away, or one deep
/// enough into Doze that the socket has been torn down.
///
/// Closing that last gap needs FCM — a Firebase project, `google-services
/// .json`, a `device_tokens` table and an edge function on the insert. That
/// is a real piece of work with an external dependency, and it is not here.
/// Do not describe delivery as guaranteed until it is.
///
/// Heartbeats are deliberately not handled here: they already have
/// `PulseAlerts`, with their own sound, their own vibration waveform and a
/// cadence throttle none of the rest of this needs.
class PartnerAlerts {
  PartnerAlerts._();

  /// Android freezes a channel's sound and importance at creation and they
  /// can never be changed in code afterwards. Bump the `_v` suffix if either
  /// has to change, so a new channel is created instead.
  static const _messageChannelId = 'partner_messages_v1';
  static const _activityChannelId = 'partner_activity_v1';

  /// One id per kind, reused. A second message rewrites the first rather
  /// than stacking, so a chatty five minutes is one line in the shade
  /// instead of fifteen — same reasoning as the heartbeat throttle.
  static const _messageNotificationId = 4301;
  static const _activityNotificationId = 4302;

  /// The newest thing already notified about, in millis since epoch. Two
  /// separate marks: a message and an activity are different notifications
  /// and one must not silence the other.
  static const _kMessageMark = 'partner_alert_message_ms';
  static const _kActivityMark = 'partner_alert_activity_ms';

  static final _plugin = AppNotifications.plugin;
  static bool _initialised = false;

  static bool get supported => AppNotifications.supported;

  static Future<void> init() async {
    if (!supported || _initialised) return;
    try {
      await AppNotifications.init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _messageChannelId,
          'Messages',
          description: 'Messages and photos from your partner.',
          importance: Importance.high,
        ),
      );

      // Quieter on purpose. An activity is worth knowing about, not worth
      // a heads-up banner over whatever you were doing — that is the
      // difference between it and a message, and the channel is where the
      // difference has to live, because the user can then retune each.
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _activityChannelId,
          'Activity',
          description:
              'Reminders, goals, photo strips and other shared activity.',
          importance: Importance.defaultImportance,
        ),
      );
      _initialised = true;
    } catch (e) {
      debugPrint('partner alerts init failed: $e');
    }
  }

  static Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        return granted ?? false;
      }
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true, badge: false);
      return granted ?? false;
    } catch (e) {
      debugPrint('partner alerts permission request failed: $e');
      return false;
    }
  }

  /// Messages and day photos from the partner, newest first.
  ///
  /// Pass everything they have ever sent — this decides for itself which of
  /// them are new, because the "already told them about it" mark lives here
  /// and nowhere else. Callers do not have to track anything.
  static Future<void> messages({
    required List<AlertItem> items,
    required bool foreground,
  }) =>
      _note(
        markKey: _kMessageMark,
        channelId: _messageChannelId,
        channelName: 'Messages',
        notificationId: _messageNotificationId,
        items: items,
        foreground: foreground,
        importance: Importance.high,
      );

  /// Entries in the shared activity feed, newest first.
  static Future<void> activity({
    required List<AlertItem> items,
    required bool foreground,
  }) =>
      _note(
        markKey: _kActivityMark,
        channelId: _activityChannelId,
        channelName: 'Activity',
        notificationId: _activityNotificationId,
        items: items,
        foreground: foreground,
        importance: Importance.defaultImportance,
      );

  static Future<void> _note({
    required String markKey,
    required String channelId,
    required String channelName,
    required int notificationId,
    required List<AlertItem> items,
    required bool foreground,
    required Importance importance,
  }) async {
    if (!supported || items.isEmpty) return;
    await init();

    try {
      final prefs = await SharedPreferences.getInstance();
      final mark = prefs.getInt(markKey);
      final newest = items.first.at.millisecondsSinceEpoch;

      // First run on this device. Take what is already there as the
      // baseline and say nothing — a fresh install has no business
      // announcing a conversation that was read on the old phone.
      if (mark == null) {
        await prefs.setInt(markKey, newest);
        return;
      }

      final fresh = items
          .where((i) => i.at.millisecondsSinceEpoch > mark)
          .toList(growable: false);
      if (fresh.isEmpty) return;
      await prefs.setInt(markKey, newest);

      // ⚠️ The mark is advanced *before* this check, deliberately. Opening
      // the app is how you find out about anything that arrived while it
      // was open, so notifying then is noise — but so is notifying later
      // about something the user has by now long since read. Moving the
      // mark and staying quiet is the only combination right in both
      // directions.
      if (foreground) return;

      final top = fresh.first;
      final extra = fresh.length - 1;
      final body = extra > 0 ? '${top.body}  ·  +$extra more' : top.body;

      await _plugin.show(
        id: notificationId,
        title: top.title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: importance,
            priority: importance == Importance.high
                ? Priority.high
                : Priority.defaultPriority,
            category: AndroidNotificationCategory.message,
            // A message can easily run past one line. Without this Android
            // truncates it and the notification says less than the lock
            // screen had room for.
            styleInformation: BigTextStyleInformation(
              extra > 0 ? '${top.body}\n\n+$extra more' : top.body,
              contentTitle: top.title,
            ),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: AppNotifications.payloadForRoute(top.route),
      );
    } catch (e) {
      debugPrint('partner alert failed: $e');
    }
  }
}

/// One candidate notification: when it happened, how it reads, and where a
/// tap should land.
///
/// [at] is the only field compared — the mark is a timestamp, so items are
/// ordered by when they arrived and never by how they read. [route] belongs
/// on the item rather than on the call because a batch is not all one
/// destination: a photo sent straight to the home screen is not in the
/// thread, and sending someone to the thread to look for it would be
/// sending them to an empty room.
typedef AlertItem = ({DateTime at, String title, String body, String route});

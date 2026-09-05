import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../app_router.dart';
import '../../../core/services/app_notifications.dart';

/// An incoming call, on the lock screen and over whatever is on top.
///
/// 🔴 **Calls raised nothing at all before this.** The ring lived entirely
/// inside the app: `incomingCallProvider` fires, the shell pushes the call
/// screen. With Dayflower in the background that is a screen nobody is
/// looking at, so a call simply went unanswered with the phone in a pocket
/// and no sign it had ever rung.
///
/// ⚠️ **This does not reach a phone whose app has been swiped away.** It is
/// a *local* notification: the row arrives over the Supabase realtime socket
/// and this device raises it, which needs the process alive and the socket
/// connected. Backgrounded a few minutes ago and still resident: works.
/// Force-stopped, or deep enough into Doze that the socket is gone: nothing,
/// and nothing will until the app is next opened. Closing that gap needs
/// FCM — a Firebase project, `google-services.json`, a `device_tokens` table
/// and an edge function on the insert. See the same note on [PartnerAlerts].
/// **Do not describe call delivery as guaranteed.**
class CallAlerts {
  CallAlerts._();

  /// ⚠️ Android freezes a channel's importance, sound and vibration at
  /// creation. Bump `_v` to change any of them; an existing install keeps
  /// the old channel's settings forever otherwise.
  static const _channelId = 'incoming_calls_v1';
  static const _notificationId = 4501;

  static final _plugin = AppNotifications.plugin;
  static bool _initialised = false;

  /// The call currently being rung for, so a re-emitted row does not raise
  /// the same call twice and a *different* call still gets through.
  static String? _ringingId;

  static bool get supported => AppNotifications.supported;

  static Future<void> init() async {
    if (!supported || _initialised) return;
    try {
      await AppNotifications.init();
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              'Incoming calls',
              description: 'Someone is calling you on Dayflower.',
              // The one alert in this app that is allowed to take over the
              // screen. Everything else — hearts, flowers, activity — is
              // deliberately quiet; a call is the exception because it
              // expires if it is not seen while it is happening.
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
      _initialised = true;
    } catch (e) {
      debugPrint('call alerts init failed: $e');
    }
  }

  /// Rings for [callId], unless it is already the one ringing.
  static Future<void> ring({
    required String callId,
    required String callerName,
    required bool isVideo,
    required bool foreground,
  }) async {
    if (!supported) return;

    // On screen already: the call screen is showing, with the same two
    // buttons and their faces on it. A notification over that would be the
    // app telling you about something you are looking at.
    if (foreground) {
      _ringingId = callId;
      return;
    }
    if (_ringingId == callId) return;
    _ringingId = callId;

    await init();
    try {
      await _plugin.show(
        id: _notificationId,
        title: callerName,
        body: isVideo ? 'Incoming video call' : 'Incoming call',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Incoming calls',
            importance: Importance.max,
            priority: Priority.max,
            // `call` is what makes Android treat this as a phone call
            // rather than a message — it is what keeps it at the top of
            // the shade and lets it through some Do Not Disturb settings.
            category: AndroidNotificationCategory.call,
            // ⚠️ Takes over the screen when the phone is locked, which is
            // the whole point: the app's own ring screen appears, with
            // Answer and Decline on it. Unlocked, Android shows it as a
            // heads-up strip instead — tapping it opens the same screen.
            fullScreenIntent: true,
            // A ringing call you can swipe away is a missed call. It is
            // cleared by [stop] when the call is answered, declined, or
            // gives up.
            ongoing: true,
            autoCancel: false,
            timeoutAfter: 60000,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        // Straight to the call. The shell is already listening for the same
        // row, so by the time this lands the ring screen is what is there.
        payload: AppNotifications.payloadForRoute(Routes.call),
      );
    } catch (e) {
      debugPrint('call alert failed: $e');
    }
  }

  /// Answered, declined, or gave up. Clears the ring either way.
  ///
  /// ⚠️ Must be called on *every* exit from ringing, not just decline. The
  /// notification is `ongoing`, so nothing else will take it off the lock
  /// screen — a call answered on the other device would otherwise keep
  /// ringing here forever.
  static Future<void> stop() async {
    _ringingId = null;
    if (!supported) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (e) {
      debugPrint('call alert cancel failed: $e');
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The single owner of `FlutterLocalNotificationsPlugin.initialize()`.
///
/// `FlutterLocalNotificationsPlugin()` is a **factory singleton** — every
/// `FlutterLocalNotificationsPlugin()` in this app is the same object. So
/// `initialize()` is global state: whoever calls it last wins, and calling
/// it twice silently replaces the tap handlers registered by the first
/// call with whatever the second passed (usually null).
///
/// That is fine while nothing needs a tap handler, which is why
/// `PulseAlerts.init()` owned this call for a year. Reminder alarms have
/// Snooze and Done buttons, so the handlers now matter, and the ownership
/// has to sit somewhere that isn't one particular feature.
///
/// Each feature still creates and owns **its own channel** — Android
/// freezes a channel's sound and importance at creation, so heartbeats,
/// nudges and alarms can never share one. Only `initialize()` is shared.
class AppNotifications {
  AppNotifications._();

  static final plugin = FlutterLocalNotificationsPlugin();
  static bool _initialised = false;

  /// Notifications only exist on the phones. On web and desktop every call
  /// here is a no-op, so the dev preview is unaffected.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initialises the plugin once, with the tap handlers wired in.
  ///
  /// [onResponse] fires when the app is alive; [onBackgroundResponse] fires
  /// when it is not, in a **separate isolate** — so it must be a top-level
  /// or static function annotated `@pragma('vm:entry-point')`, and nothing
  /// from the running app exists inside it.
  ///
  /// Call this from `main()` before any feature's `init()`. Later calls are
  /// no-ops, which is what stops a feature clobbering the handlers.
  static Future<void> init({
    DidReceiveNotificationResponseCallback? onResponse,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
  }) async {
    if (!supported || _initialised) return;
    try {
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          // Permission is requested on demand instead, so enabling alerts is
          // what triggers the iOS prompt — not the first cold start.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: onResponse,
        onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
      );
      _initialised = true;
    } catch (e) {
      debugPrint('notification init failed: $e');
    }
  }

  /// What the app was launched by, if it was launched by a notification.
  ///
  /// Read once at startup: an alarm's full-screen intent starts the app
  /// cold, and this payload is the only way to know which reminder is
  /// ringing.
  static Future<NotificationResponse?> launchResponse() async {
    if (!supported) return null;
    try {
      final details = await plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details!.notificationResponse;
    } catch (e) {
      debugPrint('notification launch details failed: $e');
      return null;
    }
  }
}

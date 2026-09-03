import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app_router.dart';
import '../../../core/services/app_notifications.dart';
import 'app_release.dart';

/// Tells the phone a new build is waiting, when the sheet can't.
///
/// ⚠️ **Its reach is narrower than it looks, and that is not a bug here —
/// it is where the updater's design ends.**
///
/// The manifest is only ever fetched on launch and on resume, so almost
/// every check completes with the app on screen, where [showUpdateSheet]
/// is a better answer than a notification. This exists for the one case
/// the sheet cannot cover: the check was still in flight when the phone was
/// put down, and the answer arrived to a backgrounded app.
///
/// A phone that has not opened Dayflower for a week will not learn about a
/// build this way, because nothing is running to ask. That needs either a
/// push message or a periodic background worker; neither exists yet. See
/// the note on `PartnerAlerts` — it is the same missing piece.
class UpdateAlerts {
  UpdateAlerts._();

  /// Android freezes a channel's importance and sound at creation. Bump the
  /// `_v` suffix if either has to change.
  static const _channelId = 'app_updates_v1';
  static const _notificationId = 4303;

  /// Keyed on the build number rather than a timestamp: a release *is* its
  /// build number, and re-announcing build 16 every time the app resumes
  /// would be the fastest way to teach someone to swipe these away.
  static const _kAnnouncedBuild = 'update_alert_build';

  static final _plugin = AppNotifications.plugin;
  static bool _initialised = false;

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
              'App updates',
              description: 'A new build of Dayflower is ready to install.',
              // Low: this is never urgent. The build will still be there
              // tomorrow, and an update that interrupts you is worse than
              // one that waits in the shade.
              importance: Importance.low,
            ),
          );
      _initialised = true;
    } catch (e) {
      debugPrint('update alerts init failed: $e');
    }
  }

  /// Announces [release] once, and only if the app is not on screen.
  static Future<void> announce(
    AppRelease release, {
    required bool foreground,
  }) async {
    if (!supported) return;
    await init();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt(_kAnnouncedBuild) == release.buildNumber) return;
      await prefs.setInt(_kAnnouncedBuild, release.buildNumber);

      // Marked as announced either way — with the app open, the sheet is
      // about to say the same thing better, and a notification behind it
      // would be the same news twice.
      if (foreground) return;

      final note = release.notes.isEmpty ? null : release.notes.first;

      await _plugin.show(
        id: _notificationId,
        title: 'Dayflower ${release.buildNumber} is ready',
        body: note ?? 'Open the app to install it.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'App updates',
            importance: Importance.low,
            priority: Priority.low,
            category: AndroidNotificationCategory.recommendation,
          ),
          iOS: DarwinNotificationDetails(presentSound: false),
        ),
        // Settings rather than Home: resuming runs the check again and the
        // sheet usually beats us to it, but if it has been dismissed this
        // is the one screen with a "Check for updates" button on it.
        payload: AppNotifications.payloadForRoute(Routes.settings),
      );
    } catch (e) {
      debugPrint('update alert failed: $e');
    }
  }
}

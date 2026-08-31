import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import 'app_notifications.dart';

/// How often an incoming heartbeat is allowed to interrupt the receiver.
///
/// A burst of taps is normal — the point is that the *first* one lands and the
/// rest quietly pile onto the same notification instead of buzzing again.
enum PulseCadence {
  everyPulse(Duration.zero, 'Every heartbeat'),
  tenMinutes(Duration(minutes: 10), 'At most every 10 min'),
  thirtyMinutes(Duration(minutes: 30), 'At most every 30 min'),
  hourly(Duration(hours: 1), 'At most once an hour');

  const PulseCadence(this.cooldown, this.label);

  final Duration cooldown;
  final String label;

  static PulseCadence fromName(String? name) => PulseCadence.values.firstWhere(
        (c) => c.name == name,
        orElse: () => PulseCadence.tenMinutes,
      );
}

/// Vibration + sound + notification for an incoming heartbeat.
///
/// There is no push backend — this only fires while the app is alive (
/// foreground or backgrounded) and the Supabase realtime stream is connected.
/// A killed app misses the pulse; the count still reconciles on next launch.
///
/// Sound comes from a local notification rather than an audio player: it's the
/// one path that works with the packages already in the project, and it means a
/// backgrounded phone still lights up.
class PulseAlerts {
  PulseAlerts._();

  /// Channel settings are frozen by Android at creation time — sound and
  /// vibration on an existing channel can never be changed in code. Bump the
  /// `_v` suffix whenever either changes so a new channel is created.
  static const _channelId = 'heartbeat_pulse_v1';
  static const _notificationId = 4201;

  static const _kLastAlertMs = 'pulse_alert_last_ms';
  static const _kPendingCount = 'pulse_alert_pending';
  static const _kLastLine = 'pulse_alert_last_line';

  /// Written as if it were them talking, because that's what a heartbeat is
  /// standing in for. Kept short — this has to read well on a lock screen.
  static const messages = <String>[
    'I miss you 💗',
    'Thinking of you',
    'Wish you were here',
    "You're on my mind",
    'Miss you like crazy',
    'Just thinking about us',
    'Sending you a squeeze',
    'Counting down to seeing you',
    'Hope your day is being kind to you',
    'Nothing important — just you',
  ];

  static final _plugin = AppNotifications.plugin;
  static final _random = Random();
  static bool _initialised = false;

  /// Vibration + local notifications only exist on the phones. Everywhere else
  /// (the web dev preview, desktop) every call below is a no-op.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// The lub-dub, twice — timed to line up with `res/raw/heartbeat.wav`.
  /// Android waveform format: [wait, buzz, wait, buzz, …], and
  /// `VibrationEffect.createWaveform` throws unless the intensity list is
  /// exactly as long as the pattern, so the gaps carry a 0.
  static const _pattern = <int>[0, 160, 55, 130, 420, 160, 55, 130];
  static const _intensities = <int>[0, 255, 0, 160, 0, 255, 0, 160];

  static Future<void> init() async {
    if (!supported || _initialised) return;
    try {
      // `initialize()` used to live here. It moved to AppNotifications when
      // reminder alarms needed tap handlers: the plugin is a singleton, so
      // whoever calls initialize() last owns the handlers, and that call
      // can't belong to one feature any more. The channel below is still
      // ours — channels are per-feature and always were.
      await AppNotifications.init();

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              'Heartbeats',
              description: "Your partner's pulses.",
              importance: Importance.high,
              sound: RawResourceAndroidNotificationSound('heartbeat'),
              enableVibration: false, // the Vibration package drives the buzz
            ),
          );
      _initialised = true;
    } catch (e) {
      debugPrint('pulse alerts init failed: $e');
    }
  }

  /// Asks for notification permission. Returns false if the user declined —
  /// vibration still works without it, so callers treat this as advisory.
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
      debugPrint('pulse alerts permission request failed: $e');
      return false;
    }
  }

  /// Handles [pulses] heartbeats that just arrived from [from].
  ///
  /// Inside the cadence cooldown this does **not** buzz or make a sound: it
  /// silently rewrites the same notification with a running count, so a partner
  /// tapping twenty times in a row is one interruption, not twenty.
  static Future<void> handleIncoming({
    required String from,
    required int pulses,
    required PulseCadence cadence,
  }) async {
    if (!supported || pulses <= 0) return;
    await init();

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = prefs.getInt(_kLastAlertMs) ?? 0;
      final quiet = now - last < cadence.cooldown.inMilliseconds;

      if (quiet) {
        final pending = (prefs.getInt(_kPendingCount) ?? 0) + pulses;
        await prefs.setInt(_kPendingCount, pending);
        // Same line as the alert the user actually heard — swapping it now
        // would look like a second, different message arrived.
        final line = prefs.getString(_kLastLine) ?? messages.first;
        await _notify(from: from, line: line, extra: pending, alert: false);
        return;
      }

      final line = _pickLine(prefs.getString(_kLastLine));
      await prefs.setInt(_kLastAlertMs, now);
      await prefs.setInt(_kPendingCount, 0);
      await prefs.setString(_kLastLine, line);
      await Future.wait([
        _vibrate(),
        _notify(from: from, line: line, extra: 0, alert: true),
      ]);
    } catch (e) {
      debugPrint('pulse alert failed: $e');
    }
  }

  /// Never the same line twice running — repetition is what makes a canned
  /// message feel canned.
  static String _pickLine(String? previous) {
    final pool = messages.where((m) => m != previous).toList();
    return pool[_random.nextInt(pool.length)];
  }

  static Future<void> _vibrate() async {
    try {
      if (!await Vibration.hasVibrator()) return;
      if (await Vibration.hasAmplitudeControl()) {
        await Vibration.vibrate(pattern: _pattern, intensities: _intensities);
      } else {
        await Vibration.vibrate(pattern: _pattern);
      }
    } catch (e) {
      debugPrint('pulse vibration failed: $e');
    }
  }

  static Future<void> _notify({
    required String from,
    required String line,
    required int extra,
    required bool alert,
  }) async {
    final body = extra > 0
        ? '$line  ·  +$extra more since'
        : line;
    try {
      await _plugin.show(
        id: _notificationId, // reused, so a burst rewrites one notification
        title: '$from sent you a heartbeat 💗',
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Heartbeats',
            channelDescription: "Your partner's pulses.",
            importance: Importance.high,
            priority: Priority.high,
            sound: const RawResourceAndroidNotificationSound('heartbeat'),
            enableVibration: false,
            category: AndroidNotificationCategory.message,
            // The whole throttle rests on this: an update posted with
            // onlyAlertOnce refreshes the text without sound or heads-up.
            onlyAlertOnce: !alert,
            silent: !alert,
          ),
          // No custom sound on iOS: the file would have to be added to the
          // Runner target in Xcode, which hasn't been done. Default chime.
          iOS: DarwinNotificationDetails(presentSound: alert),
        ),
      );
    } catch (e) {
      debugPrint('pulse notification failed: $e');
    }
  }
}

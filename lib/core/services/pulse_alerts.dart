import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import 'app_notifications.dart';

/// Vibration + sound + notification for an incoming heartbeat.
///
/// ⚠️ **This is the love-tap heartbeat, not presence.** `features/presence`
/// pings once a minute and nobody is ever told about it; see the note at the
/// top of its repository.
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

  static final _plugin = AppNotifications.plugin;

  static ({String title, String body}) copy({
    required String from,
    required int pulses,
  }) {
    final name = from.trim().isEmpty ? 'Your partner' : from.trim();
    return (
      title: pulses == 1
          ? '$name sent you a heartbeat 💗'
          : '$name sent you $pulses heartbeats 💗',
      // Only ever read by somebody who does *not* have the app in front of
      // them — see handleIncoming. It used to be shown to people staring at
      // the home screen, where "Open Dayflower" is nonsense.
      body: 'Open Dayflower to send one back.',
    );
  }

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

  /// How long before a burst is allowed to make noise again.
  ///
  /// 🔴 A heart is one tap and people send them in fives. The id is reused
  /// so the text updates in place, but every rewrite re-sounded and
  /// re-buzzed — ten taps was ten rounds of lub-dub for the gentlest thing
  /// in the app. Inside this window the count still climbs; the phone just
  /// stays quiet about it.
  static const reAlertAfter = Duration(seconds: 30);

  /// Taps that have landed since the app was last in front of you.
  ///
  /// 🔴 Cumulative, because [_notificationId] is reused. Reporting the size
  /// of the latest batch meant five taps said "5 heartbeats" and the next
  /// three **rewrote the same notification to "3"** — the number fell while
  /// more were arriving.
  static int _waiting = 0;
  static DateTime? _lastAlertAt;

  @visibleForTesting
  static int get waiting => _waiting;

  /// One alert per incoming batch, with factual copy and no invented message.
  ///
  /// [foreground] is the app being on screen right now.
  static Future<void> handleIncoming({
    required String from,
    required int pulses,
    required bool foreground,
    DateTime? now,
  }) async {
    if (!supported || pulses <= 0) return;
    await init();

    // 🔴 Buzz, but post nothing. The home screen is already rippling and
    // the phone is in their hand; a tray entry is the app telling somebody
    // about something they are watching happen. Every other alert in this
    // app takes a `foreground` flag for exactly this reason — PartnerAlerts
    // says it in as many words — and this one simply never did.
    //
    // ⚠️ The sound goes with it: it comes from the notification channel,
    // there being no audio player in the project. The lub-dub is still in
    // your hand, which is where a heartbeat belongs.
    if (foreground) {
      await _vibrate();
      return;
    }

    _waiting += pulses;
    final clock = now ?? DateTime.now();
    final loud =
        _lastAlertAt == null || clock.difference(_lastAlertAt!) >= reAlertAfter;
    if (loud) _lastAlertAt = clock;

    await Future.wait([
      if (loud) _vibrate(),
      _notify(from: from, pulses: _waiting, loud: loud),
    ]);
  }

  /// They have been seen — the app is open.
  ///
  /// 🔴 Nothing used to do this. You opened Dayflower, watched the hearts
  /// land, and "Wifey sent you 3 heartbeats" sat in the shade until you
  /// swiped it away — and the next tap counted from one again underneath a
  /// notification you had already read.
  static Future<void> seen() async {
    _waiting = 0;
    _lastAlertAt = null;
    if (!supported) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (e) {
      debugPrint('pulse notification cancel failed: $e');
    }
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
    required int pulses,
    required bool loud,
  }) async {
    final text = copy(from: from, pulses: pulses);
    try {
      await _plugin.show(
        id: _notificationId, // reused, so a burst rewrites one notification
        title: text.title,
        body: text.body,
        payload: AppNotifications.payloadForRoute('/app/home'),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Heartbeats',
            channelDescription: "Your partner's pulses.",
            importance: Importance.high,
            priority: Priority.high,
            sound: const RawResourceAndroidNotificationSound('heartbeat'),
            playSound: loud,
            enableVibration: false,
            category: AndroidNotificationCategory.message,
            // ⚠️ **`onlyAlertOnce` is the load-bearing one here, not
            // `playSound`.** From Android 8 the channel owns the sound, and
            // a per-notification `playSound: false` is ignored on an update
            // — `onlyAlertOnce` is what actually stops Android
            // re-announcing a notification it has already announced.
            // `playSound` still covers the phones below that.
            onlyAlertOnce: !loud,
          ),
          // No custom sound on iOS: the file would have to be added to the
          // Runner target in Xcode, which hasn't been done. Default chime.
          iOS: DarwinNotificationDetails(presentSound: loud),
        ),
      );
    } catch (e) {
      debugPrint('pulse notification failed: $e');
    }
  }
}

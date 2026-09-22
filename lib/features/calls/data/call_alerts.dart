import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../app_router.dart';
import '../../../core/services/app_notifications.dart';
import 'native_calls.dart';

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
  static const _channelId = 'incoming_calls_v2';
  static const _missedChannelId = 'missed_calls_v1';
  static const _notificationId = 4501;

  /// ⚠️ Its own id, so a missed call is not cancelled by the same [stop]
  /// that takes the ring down — the ring ending is precisely when this one
  /// is raised.
  static const _missedNotificationId = 4502;
  static const actionAnswer = 'call_answer';
  static const actionDecline = 'call_decline';
  static String? pendingAnswerId;

  static String? callIdOf(String? payload) {
    final uri = Uri.tryParse(payload ?? '');
    if (uri?.scheme != 'dayflower' || uri?.host != 'call') return null;
    final id = uri?.queryParameters['id'];
    return id == null || id.isEmpty ? null : id;
  }

  static bool handleTap(NotificationResponse response) {
    final id = callIdOf(response.payload);
    if (id == null) return false;
    if (response.actionId == actionDecline) return true;
    pendingAnswerId = response.actionId == actionAnswer ? id : null;
    AppNotifications.pendingRoute.value = Routes.call;
    return true;
  }

  static final _plugin = AppNotifications.plugin;
  static bool _initialised = false;

  /// The call currently being rung for, so a re-emitted row does not raise
  /// the same call twice and a *different* call still gets through.
  static String? _ringingId;

  /// ⚠️ Test seams. [settle] decides "missed" from [_ringingId] alone, and
  /// that decision is worth pinning: reporting a missed call for one the
  /// user declined is worse than reporting nothing.
  @visibleForTesting
  static bool get debugWouldReportMissed => _ringingId != null;
  @visibleForTesting
  static void debugStartRinging(String id) => _ringingId = id;
  @visibleForTesting
  static void debugResetRinging() => _ringingId = null;

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
              sound: UriAndroidNotificationSound('content://settings/system/ringtone'),
              audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
              enableVibration: true,
            ),
          );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _missedChannelId,
              'Missed calls',
              description: 'A call you did not get to.',
              importance: Importance.defaultImportance,
            ),
          );
      // ⚠️ The channel this replaced, still sitting in the phone's settings
      // as a second "Incoming calls" with its own switches. Android keeps a
      // channel until the app is uninstalled, so bumping _v left the old one
      // behind — two identical-looking entries, one of them dead and one of
      // them the one that matters.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.deleteNotificationChannel(channelId: 'incoming_calls');
      _initialised = true;
    } catch (e) {
      debugPrint('call alerts init failed: $e');
    }
  }

  /// Rings for [callId], unless it is already the one ringing.
  /// The app's own answer and end-call colours, for the notification's two
  /// buttons.
  ///
  /// ⚠️ Not the usual green and red, and not the gradient either — a colour
  /// hint takes one value. The answer button on the call screen runs pink to
  /// purple, and the purple end is the half that does not read as the same
  /// colour as Decline at a glance.
  static const _answerColor = 0xFF906FE8; // AppGradients.cta, purple end
  static const _declineColor = 0xFFE2447C; // AppColors.danger

  static Future<void> ring({
    required String callId,
    required String callerName,
    required bool isVideo,
    required bool foreground,
    Uint8List? callerAvatar,
  }) async {
    if (!supported) return;

    // On screen already: the call screen is showing, with the same two
    // buttons and their faces on it. A notification over that would be the
    // app telling you about something you are looking at.
    if (_ringingId == callId) return;
    _ringingId = callId;

    await init();
    try {
      await _plugin.show(
        id: _notificationId,
        title: callerName,
        body: isVideo ? 'Incoming video call' : 'Incoming call',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Incoming calls',
            importance: Importance.max,
            priority: Priority.max,
            sound: const UriAndroidNotificationSound('content://settings/system/ringtone'),
            additionalFlags: Int32List.fromList([4]), // Android FLAG_INSISTENT.
            // `call` is what makes Android treat this as a phone call
            // rather than a message — it is what keeps it at the top of
            // the shade and lets it through some Do Not Disturb settings.
            category: AndroidNotificationCategory.call,
            actions: [
              const AndroidNotificationAction(actionDecline, 'Decline',
                  showsUserInterface: false, cancelNotification: true),
              const AndroidNotificationAction(actionAnswer, 'Answer',
                  showsUserInterface: true, cancelNotification: true),
            ],
            // ⚠️ Takes over the screen when the phone is locked, which is
            // the whole point: the app's own ring screen appears, with
            // Answer and Decline on it. Unlocked, Android shows it as a
            // heads-up strip instead — tapping it opens the same screen.
            fullScreenIntent: !foreground,
            // A ringing call you can swipe away is a missed call. It is
            // cleared by [stop] when the call is answered, declined, or
            // gives up.
            ongoing: true,
            autoCancel: false,
            timeoutAfter: 60000,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          ),
          iOS: const DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        // Straight to the call. The shell is already listening for the same
        // row, so by the time this lands the ring screen is what is there.
        payload: 'dayflower://call?id=${Uri.encodeComponent(callId)}',
      );
      // 🔴 After the plugin's notification, never instead of it. This
      // replaces it in place with a CallStyle one — the caller's face and
      // two round buttons in the app's colours — and if any of that fails
      // the working notification is still on screen. See CallNotification.
      await NativeCalls.invoke<bool>('styleIncoming', {
        'name': callerName,
        'subtitle': isVideo ? 'Incoming video call' : 'Incoming call',
        'callId': callId,
        'channelId': _channelId,
        'answerColor': _answerColor,
        'declineColor': _declineColor,
        if (callerAvatar != null) 'avatar': callerAvatar,
      });
    } catch (e) {
      debugPrint('call alert failed: $e');
    }
  }

  /// Takes the banner down without deciding the call is over.
  ///
  /// 🔴 **Not [stop].** The ring screen was showing with the heads-up banner
  /// still sitting on top of it — the app telling you about something you
  /// were already looking at. The obvious fix is to call stop(), and it is
  /// wrong: stop() clears [_ringingId], which is the only evidence [settle]
  /// has that nobody here answered. A call ignored from the ring screen
  /// would then never be reported missed.
  static Future<void> dismissBanner() async {
    if (!supported) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (e) {
      debugPrint('call banner dismiss failed: $e');
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

  /// The ring is over. Says so if nobody here ended it.
  ///
  /// 🔴 **A call that stops ringing on its own left no trace at all.** The
  /// row was marked missed and the thread showed it, but the thread is
  /// somewhere you have to go and look — from outside the app a call in a
  /// pocket rang, gave up, and vanished.
  ///
  /// ⚠️ [_ringingId] is the whole test, and it works because every local
  /// exit already clears it: answering calls [stop], declining calls
  /// [stop] through hangUp. So a ring still holding its id when the row
  /// closes is one the caller gave up on — which is the only case that is
  /// actually a missed call, and the reason this is not just "the provider
  /// went null".
  static Future<void> settle({
    required String callerName,
    required bool isVideo,
  }) async {
    final missed = _ringingId != null;
    await stop();
    if (!missed || !supported) return;
    try {
      await init();
      await _plugin.show(
        id: _missedNotificationId,
        title: 'Missed call',
        body: isVideo
            ? 'You missed a video call from $callerName'
            : 'You missed a call from $callerName',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _missedChannelId,
            'Missed calls',
            // ⚠️ Nothing like the ring channel. This is news about something
            // that already finished: no ringtone, no insistent flag, no
            // full-screen intent. It waits in the shade.
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            category: AndroidNotificationCategory.missedCall,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // Into the conversation, where the call bubble is.
        payload: AppNotifications.payloadForRoute(Routes.chat),
      );
    } catch (e) {
      debugPrint('missed call alert failed: $e');
    }
  }
}

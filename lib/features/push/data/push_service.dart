import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../app_router.dart';
import '../../../core/services/app_notifications.dart';
import '../../../core/services/partner_alerts.dart';
import '../../calls/data/call_alerts.dart';
import '../domain/push_message.dart';
import 'push_repository.dart';

/// The wire between FCM and this app.
///
/// The schema, the sender and the parsing already existed (migration 0028,
/// `supabase/functions/push`, `PushMessage`); this is the half that was
/// missing — getting a token, keeping it fresh, and doing something with
/// what arrives.
///
/// ⚠️ **The edge function sends data-only messages, deliberately.** A payload
/// with a `notification` block is drawn by Android itself and never reaches
/// the app while it is backgrounded — which would make a full-screen
/// incoming call impossible. Everything below is the price of that: this app
/// draws its own notifications, in all three states.
class PushService {
  PushService._();

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool _started = false;

  /// The token this device last registered, so sign-out can drop the right
  /// row. ⚠️ Not read back from the table — that row is a write-only mailbox
  /// address and the app has no reason to query it.
  static String? _token;

  /// Sets up Firebase and the listeners. Safe to call more than once.
  static Future<void> init() async {
    if (!supported || _started) return;
    _started = true;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      // Android 13+ needs this; below it the call is a no-op that returns
      // authorised. PartnerAlerts asks for the same permission for its own
      // reasons — the OS prompt appears once whichever asks first.
      await messaging.requestPermission();

      FirebaseMessaging.onMessage.listen(_onForeground);

      // A notification tapped while the app was dead. The token stream below
      // is what keeps registration current; this is the launch payload.
      final opened = await messaging.getInitialMessage();
      if (opened != null) _onTap(opened);
      FirebaseMessaging.onMessageOpenedApp.listen(_onTap);
    } catch (e) {
      // A missing google-services.json, a device with no Play Services, a
      // revoked project. ⚠️ Push is an enhancement to a working app — the
      // realtime path still delivers everything while the app is open — so
      // none of this may be fatal.
      debugPrint('push init failed: $e');
    }
  }

  /// Registers this device against the signed-in user, and keeps it
  /// registered when FCM rotates the token.
  ///
  /// ⚠️ Takes the repository rather than a `Ref`. Both callers are widgets
  /// holding a `WidgetRef`, and the two are not interchangeable — asking for
  /// the narrower thing it actually uses means neither caller has to reach
  /// for the wrong flavour.
  ///
  /// ⚠️ Called after sign-in, not at launch. A token written before there is
  /// a session has no user to attach to, and `PushRepository.register`
  /// correctly does nothing — which would leave the phone silent until the
  /// next reinstall.
  static Future<void> registerFor(PushRepository repo) async {
    if (!supported) return;
    try {
      final messaging = FirebaseMessaging.instance;

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _token = token;
        await repo.register(token);
      }

      // FCM rotates tokens on reinstall, restore, and occasionally on its
      // own. A rotation nobody records is a phone that goes quiet for good.
      messaging.onTokenRefresh.listen((fresh) async {
        _token = fresh;
        try {
          await repo.register(fresh);
        } catch (e) {
          debugPrint('push token refresh failed: $e');
        }
      });
    } catch (e) {
      debugPrint('push registration failed: $e');
    }
  }

  /// Drops this device on sign-out.
  ///
  /// ⚠️ Load-bearing for privacy, not housekeeping. A token left behind keeps
  /// delivering one person's messages to a phone somebody else may now be
  /// signed into — and nothing visibly breaks, which is why it is easy to
  /// forget.
  static Future<void> forget(PushRepository repo) async {
    final token = _token;
    _token = null;
    if (token == null) return;
    try {
      await repo.unregister(token);
    } catch (e) {
      debugPrint('push unregister failed: $e');
    }
  }

  /// Arrived while the app is on screen.
  ///
  /// ⚠️ Only calls interrupt here. Everything else is already visible: the
  /// realtime stream has put the message in the thread the user is looking
  /// at, and a heads-up notification on top of it would be the app telling
  /// somebody about something they can see.
  static void _onForeground(RemoteMessage remote) {
    final push = PushMessage.parse(remote.data);
    if (push == null || !push.isActionableCall) return;
    CallAlerts.ring(
      callId: push.messageId!,
      callerName: push.title,
      isVideo: push.isVideoCall,
      // Foreground, but a call still has to ring — the whole point is that
      // it expires if it is not seen while it is happening.
      foreground: false,
    );
  }

  /// A notification the user tapped.
  static void _onTap(RemoteMessage remote) {
    final push = PushMessage.parse(remote.data);
    if (push == null) return;
    // ⚠️ The same `pendingRoute` every other notification tap uses, not a
    // second route mechanism. app.dart already watches it and navigates once
    // the router exists — which matters most here, because a tap that opens
    // the app from dead arrives long before there is anything to navigate.
    AppNotifications.pendingRoute.value =
        push.isActionableCall ? Routes.call : Routes.chat;
  }
}

/// Arrived with the app backgrounded or dead.
///
/// ⚠️ **Top-level and `@pragma('vm:entry-point')`**, because Android spawns a
/// fresh isolate for it with nothing from the running app — the same
/// constraint the widget's background handler works under. Anything it needs
/// has to be set up again here.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage remote) async {
  final push = PushMessage.parse(remote.data);
  if (push == null) return;

  try {
    if (push.isActionableCall) {
      // The one thing worth waking the screen for.
      await CallAlerts.ring(
        callId: push.messageId!,
        callerName: push.title,
        isVideo: push.isVideoCall,
        foreground: false,
      );
      return;
    }
    await PartnerAlerts.pushed(
      title: push.title,
      body: push.body,
      route: Routes.chat,
    );
  } catch (e) {
    debugPrint('push background handler failed: $e');
  }
}

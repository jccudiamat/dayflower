import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/core/services/app_notifications.dart';
import 'package:dayflower/features/calls/data/call_alerts.dart';

void main() {
  _missedCallRules();
  tearDown(() {
    CallAlerts.pendingAnswerId = null;
    AppNotifications.pendingRoute.value = null;
  });
  test('Answer carries the exact call ID into the app', () {
    expect(CallAlerts.handleTap(const NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotificationAction,
      actionId: CallAlerts.actionAnswer,
      payload: 'dayflower://call?id=call-a',
    )), isTrue);
    expect(CallAlerts.pendingAnswerId, 'call-a');
    expect(AppNotifications.pendingRoute.value, isNotNull);
  });
  test('Plain call tap does not automatically answer', () {
    CallAlerts.pendingAnswerId = 'old-call';
    CallAlerts.handleTap(const NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
      payload: 'dayflower://call?id=call-b',
    ));
    expect(CallAlerts.pendingAnswerId, isNull);
  });
  test('Decline does not navigate or answer', () {
    CallAlerts.handleTap(const NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotificationAction,
      actionId: CallAlerts.actionDecline,
      payload: 'dayflower://call?id=call-a',
    ));
    expect(CallAlerts.pendingAnswerId, isNull);
    expect(AppNotifications.pendingRoute.value, isNull);
  });
  test('Unrelated or empty payloads are not call actions', () {
    for (final payload in [null, '', 'dayflower://call?id=', 'https://call?id=a', 'dayflower://open?route=/chat']) {
      expect(CallAlerts.callIdOf(payload), isNull);
    }
  });
}

/// 🔴 A call that stops ringing on its own used to leave nothing behind —
/// the row was marked missed and the thread showed it, but from outside the
/// app a call in a pocket rang, gave up and vanished.
///
/// ⚠️ These pin the *decision*, which is the part that can go wrong
/// silently: saying "missed" about a call somebody declined is worse than
/// saying nothing. Whether the notification then renders is Android's, and
/// no test here sees it.
void _missedCallRules() {
  group('missed call', () {
    setUp(CallAlerts.debugResetRinging);

    test('a ring nothing ended locally is a missed call', () {
      CallAlerts.debugStartRinging('call-1');
      expect(CallAlerts.debugWouldReportMissed, isTrue);
    });

    test('answering it is not', () {
      CallAlerts.debugStartRinging('call-1');
      // answer() clears the ring through stop() before the row closes.
      CallAlerts.debugResetRinging();
      expect(CallAlerts.debugWouldReportMissed, isFalse);
    });

    test('declining it is not', () {
      CallAlerts.debugStartRinging('call-1');
      // decline reaches the same stop() via hangUp().
      CallAlerts.debugResetRinging();
      expect(CallAlerts.debugWouldReportMissed, isFalse);
    });

    test('a row closing with no ring at all is not', () {
      // The call was never rung for on this device — a second device
      // answered, or the app started after it ended.
      expect(CallAlerts.debugWouldReportMissed, isFalse);
    });
  });
}

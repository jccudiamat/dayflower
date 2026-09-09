import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/core/services/app_notifications.dart';
import 'package:dayflower/features/calls/data/call_alerts.dart';

void main() {
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

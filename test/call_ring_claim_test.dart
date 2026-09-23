import 'package:dayflower/features/calls/data/call_alerts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔴 One call, one ring. A call to a closed app is rung natively by the push
/// service (CallPushService -> CallNotification), which writes its claim into
/// shared_preferences' own store — "flutter.ringing_call_id" and
/// "flutter.ringing_call_at", which Dart reads as these two keys. Then the
/// plugin starts the FCM background isolate for the same push, and that
/// isolate has no way to reach the native side. If it did not see the claim
/// it would post the plugin's plain notification as well: the "W" with no
/// buttons that arrived beside the real one on every call.
void main() {
  setUp(CallAlerts.debugResetRinging);

  int now() => DateTime.now().millisecondsSinceEpoch;

  test('a call the push service already rang stays one ring', () async {
    SharedPreferences.setMockInitialValues({
      'ringing_call_id': 'call-1',
      'ringing_call_at': now() - 2000,
    });
    expect(await CallAlerts.debugClaim('call-1'), isFalse);
  });

  test('a different call still rings', () async {
    SharedPreferences.setMockInitialValues({
      'ringing_call_id': 'call-1',
      'ringing_call_at': now() - 2000,
    });
    expect(await CallAlerts.debugClaim('call-2'), isTrue);
  });

  test('a claim left by a crash does not silence the next ring forever',
      () async {
    // The native claim holds 70s, a little past the 60s ring.
    SharedPreferences.setMockInitialValues({
      'ringing_call_id': 'call-1',
      'ringing_call_at': now() - 71000,
    });
    expect(await CallAlerts.debugClaim('call-1'), isTrue);
  });

  test('nothing claimed: this isolate rings', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await CallAlerts.debugClaim('call-1'), isTrue);
  });
}

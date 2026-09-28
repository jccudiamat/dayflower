import 'package:dayflower/features/calls/data/call_alerts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  // 🔴 A call rang a second time a minute into the conversation: the row
  // stays live for the whole call and was rung on every emission.
  test('the same call seen again does not ring again', () {
    expect(CallAlerts.isNewCall(previousId: null, nextId: 'call-1'), isTrue);
    expect(CallAlerts.isNewCall(previousId: 'call-1', nextId: 'call-1'),
        isFalse);
    expect(CallAlerts.isNewCall(previousId: 'call-1', nextId: 'call-2'),
        isTrue);
  });

  testWidgets('a call the phone refuses is not rung, nor reported missed',
      (tester) async {
    // Answered or declined already, stale, or this phone is on a call:
    // native says "handled", and Dart must neither post its plain fallback
    // nor hold the call, or its end would be reported as a missed call.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final asked = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dayflower/native_calls'), (call) async {
      asked.add(call.method);
      return call.method == 'ring' ? 'handled' : null;
    });
    try {
      SharedPreferences.setMockInitialValues({});
      await CallAlerts.ring(
        callId: 'call-1',
        callerName: 'Wifey',
        isVideo: true,
        foreground: true,
      );
      expect(asked, ['ring']);
      expect(CallAlerts.debugWouldReportMissed, isFalse);
      // And no claim taken for a fallback ring.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ringing_call_id'), isNull);
    } finally {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('dayflower/native_calls'), null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

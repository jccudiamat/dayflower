import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Kotlin half of a call — see CallNotification.kt.
class NativeCalls {
  static const _channel = MethodChannel('dayflower/native_calls');

  static Future<T?> invoke<T>(String method, [Map<String, Object?>? args]) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (e) {
      // ⚠️ Never rethrow. The one caller is the incoming-call ring, and a
      // failure here means the notification simply stays as Dart posted it.
      debugPrint('native call $method failed: $e');
      return null;
    }
  }

  /// Why the last incoming call notification did or did not get restyled.
  ///
  /// ⚠️ Worth surfacing because every failure in that path is silent: the
  /// fallback is "leave the working notification alone", which once hid the
  /// whole feature doing nothing on every call.
  static Future<String> callStyleStatus() async =>
      await invoke<String>('callStyleStatus') ?? 'unavailable';

  /// Answer or Decline, tapped on the notification's own buttons.
  ///
  /// 🔴 CallStyle draws its own buttons, so their taps arrive as Activity
  /// intents rather than through flutter_local_notifications. This is the
  /// only way back from them.
  static void onAction(void Function(String action, String callId) handler) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'callAction') return null;
      final args = (call.arguments as Map?)?.cast<String, Object?>();
      final action = args?['action'] as String?;
      final callId = args?['callId'] as String?;
      if (action == null || callId == null) return null;
      handler(action, callId);
      return null;
    });
  }
}

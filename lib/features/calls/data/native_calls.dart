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

  /// Rings for [callId] natively: the caller's face and the app's own
  /// Answer and Decline. "posted", "already" when it is ringing already
  /// (the push got there first), "failed", or null where there is no native
  /// side to ask - the FCM background isolate, where the push service has
  /// normally rung before Dart even starts. See CallNotification.kt.
  static Future<String?> ring({
    required String callId,
    required String name,
    required String subtitle,
    Uint8List? avatar,
  }) =>
      invoke<String>('ring', {
        'callId': callId,
        'name': name,
        'subtitle': subtitle,
        if (avatar != null) 'avatar': avatar,
      });

  /// Takes the native ring down and releases its claim.
  static Future<void> stopRinging() => invoke<void>('stopRinging');

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
    void deliver(Object? arguments) {
      final args = (arguments as Map?)?.cast<String, Object?>();
      final action = args?['action'] as String?;
      final callId = args?['callId'] as String?;
      if (action == null || callId == null) return;
      debugPrint('call notification: $action ($callId)');
      handler(action, callId);
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'callAction') deliver(call.arguments);
      return null;
    });
    // 🔴 Then say so, and collect whatever was tapped before now. Answer
    // tapped on a closed app launches it, and the tap used to be sent down
    // the channel before this handler existed - Flutter drops a call nobody
    // handles, so the app opened and answered nothing. MainActivity holds it
    // until this asks.
    invoke<Object?>('callActionsReady').then(deliver);
  }
}

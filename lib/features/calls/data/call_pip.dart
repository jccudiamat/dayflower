import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Picture-in-picture — the floating call window.
///
/// The Android half is `MainActivity.kt`; PiP is an Activity capability and
/// there is no Flutter API for it. This is the wire between them.
///
/// ⚠️ **Android only, and API 26+ at that.** Everywhere else every call here
/// is a no-op returning false, which the call screen reads as "stay
/// full-screen" — the honest failure, rather than a Minimise button that
/// does nothing.
class CallPip {
  CallPip._();

  static const _channel = MethodChannel('dayflower/pip');

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether this device can actually float a call.
  ///
  /// Asked once and remembered: it cannot change while the app is running,
  /// and the answer decides whether the back button offers to minimise at
  /// all.
  static bool? _supported;

  static Future<bool> supported() async {
    if (!_android) return false;
    return _supported ??= await _invoke<bool>('supported') ?? false;
  }

  /// Shrinks the app into the floating window. False when the system
  /// refused — already finishing, locked, or a device that claims PiP and
  /// declines it anyway.
  static Future<bool> enter() async {
    if (!_android) return false;
    return await _invoke<bool>('enter') ?? false;
  }

  /// Tells the Activity a call is up.
  ///
  /// ⚠️ Load-bearing. `onUserLeaveHint` fires on *every* exit from the app,
  /// so without this flag pressing Home on the home screen would shrink
  /// Dayflower into a floating window. Only Dart knows a call is live, so
  /// only Dart can say.
  static Future<void> setCallActive(bool active) async {
    if (!_android) return;
    await _invoke<void>('setCallActive', active);
  }

  static Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (e) {
      // A missing implementation is the normal state on iOS and web, and on
      // an Android build whose native half has not been rebuilt yet.
      debugPrint('pip $method failed: $e');
      return null;
    }
  }
}

/// True while the app is drawn as the floating window.
///
/// Pushed from `onPictureInPictureModeChanged`, never inferred from
/// lifecycle: PiP is not "paused" — the app keeps rendering, which is the
/// whole point, and treating it as backgrounded would stop the video.
final pipModeProvider = StateProvider<bool>((ref) => false);

/// Listens for the Activity's PiP notifications and keeps [pipModeProvider]
/// in step. Call once, at app start.
void wirePipMode(WidgetRef ref) {
  const MethodChannel('dayflower/pip').setMethodCallHandler((call) async {
    if (call.method == 'pipChanged') {
      ref.read(pipModeProvider.notifier).state = call.arguments == true;
    }
  });
}

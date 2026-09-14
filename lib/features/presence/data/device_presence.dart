import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Is the phone awake, and past its lock screen?
///
/// The one question that separates a person using the app from an Activity
/// that merely exists. Android has no Flutter API for either half, so this
/// is twelve lines of Kotlin in MainActivity behind a channel — the same
/// reasoning as `call_pip.dart`, and for the same reason it is not a new
/// dependency.
///
/// ⚠️ **Fails open, but only on a phone.** An Android device that will not
/// answer — an older native side with no such method, a manufacturer that
/// throws — is not evidence of absence, and answering `false` there would
/// make somebody permanently invisible to their partner with nothing on
/// screen to explain it. A wrong `true` costs one minute of accuracy on a
/// header; a wrong `false` costs the feature.
///
/// 🔴 **Anything that is not an Android install answers `false`**, which is
/// the opposite rule and deliberate. The app ships as an APK; a web or
/// desktop build of it is a development preview, signed in through
/// `maybeDevAutoLogin` as a *real* account, writing to the same production
/// row every phone reads. One left open reported a partner as "Active now"
/// for nineteen hours after its server had been stopped.
///
/// ⚠️ So an iOS build would be silent here until it is given the same two
/// questions to answer. Silent is the right failure — better than a phone
/// claiming a presence it cannot actually check.
class DevicePresence {
  DevicePresence._();

  static const _channel = MethodChannel('dayflower/presence');

  static Future<bool> deviceAwake() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('deviceAwake') ?? true;
    } catch (_) {
      return true;
    }
  }
}

/// The seam the heartbeat asks through, so a test can answer for it.
typedef DeviceAwakeCheck = Future<bool> Function();

final deviceAwakeProvider = Provider<DeviceAwakeCheck>(
  (ref) => DevicePresence.deviceAwake,
);

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Puts a widget on the home screen in one tap: the launcher's own "Add to
/// home screen" dialog, as the chat's shortcut is added, instead of steps
/// through the widget tray. The native half is WidgetPin.kt.
///
/// ⚠️ **The launcher owns the last step.** True means it was asked, never
/// that the widget landed: the person can still say no. False means it
/// cannot be asked here (iOS, Android 7, a launcher that takes no
/// requests), and the caller shows the steps through the tray instead.
class WidgetPinner {
  WidgetPinner._();

  static const _channel = MethodChannel('dayflower/widget_pin');

  static bool get supported =>
      debugSupported ?? (!kIsWeb && Platform.isAndroid);

  /// Tests stand in for an Android phone with this.
  @visibleForTesting
  static bool? debugSupported;

  /// Asks for the widget named [kind]: `myDay`, `heartbeat` or `reunion`
  /// (HomeWidgetKind's names, which WidgetPin.kt matches).
  static Future<bool> pin(String kind) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('pin', kind) ?? false;
    } on PlatformException catch (e) {
      debugPrint('widget pin failed: $e');
      return false;
    } on MissingPluginException {
      // The Dart side shipped ahead of the Kotlin.
      return false;
    }
  }
}

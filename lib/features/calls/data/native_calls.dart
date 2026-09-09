import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeCalls {
  static const _channel = MethodChannel('dayflower/native_calls');
  static Future<void> invoke(String method, [Map<String, Object>? args]) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>(method, args);
  }
}

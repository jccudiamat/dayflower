import 'dart:io';

import 'package:dayflower/features/home/presentation/widgets/home_widget_gallery.dart';
import 'package:dayflower/features/widget/widget_pinner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A widget added in one tap: Dart asks by name, Kotlin knows each name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String path) => File(path).readAsStringSync();
  const kotlin = 'android/app/src/main/kotlin/com/dayflower/app/';

  test('Android knows every widget the gallery asks for', () {
    final native = read('${kotlin}WidgetPin.kt');
    expect(
        RegExp(r'const val CHANNEL = "([\w/]+)"').firstMatch(native)?.group(1),
        'dayflower/widget_pin');
    for (final (kind, provider) in [
      (HomeWidgetKind.myDay, 'TodaysTulipWidget'),
      (HomeWidgetKind.heartbeat, 'HeartbeatWidget'),
      (HomeWidgetKind.reunion, 'ReunionWidget'),
    ]) {
      expect(native, contains('"${kind.name}" -> $provider::class.java'),
          reason: kind.name);
    }
    expect(read('${kotlin}MainActivity.kt'), contains('WidgetPin.CHANNEL'));
  });

  test('says no where the launcher cannot be asked', () async {
    const channel = MethodChannel('dayflower/widget_pin');
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      calls++;
      return false;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    WidgetPinner.debugSupported = false;
    addTearDown(() => WidgetPinner.debugSupported = null);
    expect(await WidgetPinner.pin('heartbeat'), isFalse);
    expect(calls, 0, reason: 'not even asked off Android');

    WidgetPinner.debugSupported = true;
    expect(await WidgetPinner.pin('heartbeat'), isFalse);
    expect(calls, 1);
  });
}

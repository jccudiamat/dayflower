import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A screenshot was taken while Dayflower was on screen.
///
/// Raised by ScreenshotWatcher in MainActivity: Android 14's own screenshot
/// event, or on older phones a new picture arriving in the gallery while the
/// app is in front. It carries no picture; the app captures its own screen.
class ScreenshotEvents {
  ScreenshotEvents._();

  static const _channel = MethodChannel('dayflower/screenshots');
  static final _taken = StreamController<void>.broadcast();
  static bool _listening = false;

  static Stream<void> get taken {
    if (!_listening &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'taken') _taken.add(null);
      });
    }
    return _taken.stream;
  }
}

/// The screenshot events, as a seam: tests hand in their own.
final screenshotEventsProvider =
    Provider<Stream<void>>((ref) => ScreenshotEvents.taken);

/// Whether a screenshot brings up the offer to report it. On by default,
/// and switchable in Settings for somebody who screenshots a lot and never
/// means a bug by it. Device-local, like the theme.
class ScreenshotPromptPrefs extends StateNotifier<bool> {
  ScreenshotPromptPrefs() : super(true) {
    ready = _load();
  }

  /// Done reading the saved choice. ⚠️ Awaited before offering: without it
  /// the first screenshot after launch read the default, and "off" was
  /// ignored exactly once per launch.
  late final Future<void> ready;

  static const _key = 'feedback_screenshot_prompt';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_touched) state = prefs.getBool(_key) ?? true;
    } catch (e) {
      debugPrint('screenshot prompt setting failed to load: $e');
    }
  }

  /// Switched in Settings before the saved choice finished loading: the
  /// switch wins.
  bool _touched = false;

  Future<void> set(bool on) async {
    _touched = true;
    state = on;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, on);
    } catch (e) {
      debugPrint('screenshot prompt setting failed to save: $e');
    }
  }
}

final screenshotPromptProvider =
    StateNotifierProvider<ScreenshotPromptPrefs, bool>(
        (ref) => ScreenshotPromptPrefs());

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widget_sync.dart';

/// What the *adaptive* home-screen widget shows. Persisted in the shared
/// widget store (not SharedPreferences) so the native provider can read the
/// same value without a plugin round-trip.
class WidgetModeNotifier extends StateNotifier<WidgetMode> {
  WidgetModeNotifier() : super(WidgetMode.flower) {
    _load();
  }

  Future<void> _load() async {
    final stored = await DayflowerWidgets.currentMode();
    if (mounted) state = stored;
  }

  Future<void> setMode(WidgetMode mode) async {
    state = mode;
    await DayflowerWidgets.setMode(mode);
  }
}

final widgetModeProvider =
    StateNotifierProvider<WidgetModeNotifier, WidgetMode>(
  (ref) => WidgetModeNotifier(),
);

/// How often the home-screen widget advances to the next day photo.
///
/// ⚠️ Stored in the shared widget store like the mode, not SharedPreferences,
/// so the native provider reads the same value without a plugin round-trip —
/// which matters here because the widget renders while the app is dead.
///
/// 0 means off, and is the default. A card that animates on its own draws
/// the eye from across a room; some people want that and some do not, which
/// is precisely why it is a setting rather than a decision.
class WidgetRotationNotifier extends StateNotifier<int> {
  WidgetRotationNotifier() : super(0) {
    _load();
  }

  Future<void> _load() async {
    final stored = await DayflowerWidgets.currentRotateSeconds();
    if (mounted) state = stored;
  }

  Future<void> setSeconds(int seconds) async {
    state = seconds;
    await DayflowerWidgets.setRotateSeconds(seconds);
  }
}

final widgetRotationProvider =
    StateNotifierProvider<WidgetRotationNotifier, int>(
  (ref) => WidgetRotationNotifier(),
);

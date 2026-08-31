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

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

/// How My Day shows more than one live day: a list to [scroll] up and down,
/// or rotating every [seconds], where 0 holds still on the newest.
typedef DaysMotion = ({bool scroll, int seconds});

/// How the home-screen widget moves through their live days.
///
/// ⚠️ Stored in the shared widget store like the mode, not SharedPreferences,
/// so the native provider reads the same value without a plugin round-trip —
/// which matters here because the widget renders while the app is dead.
///
/// Holding still is the default. A card that animates on its own draws the
/// eye from across a room; some people want that and some do not, which is
/// precisely why it is a setting rather than a decision. Scrolling is the
/// other way through them: nothing moves until you move it.
class WidgetDaysNotifier extends StateNotifier<DaysMotion> {
  WidgetDaysNotifier() : super((scroll: false, seconds: 0)) {
    _load();
  }

  /// Set by a choice. ⚠️ The stored value is read asynchronously, and a
  /// read that finished after a tap would put back what was there before
  /// it: the row would light, then go out again.
  var _chosen = false;

  Future<void> _load() async {
    final seconds = await DayflowerWidgets.currentRotateSeconds();
    final scroll = await DayflowerWidgets.currentDaysScroll();
    if (mounted && !_chosen) state = (scroll: scroll, seconds: seconds);
  }

  /// Rotating every [seconds], or still on the newest for 0.
  Future<void> rotate(int seconds) async {
    _chosen = true;
    state = (scroll: false, seconds: seconds);
    await DayflowerWidgets.setDaysMotion(scroll: false, seconds: seconds);
  }

  /// A list to scroll. The rotation is kept for if they go back to it.
  Future<void> scroll() async {
    _chosen = true;
    state = (scroll: true, seconds: state.seconds);
    await DayflowerWidgets.setDaysMotion(scroll: true, seconds: state.seconds);
  }
}

final widgetDaysProvider =
    StateNotifierProvider<WidgetDaysNotifier, DaysMotion>(
  (ref) => WidgetDaysNotifier(),
);

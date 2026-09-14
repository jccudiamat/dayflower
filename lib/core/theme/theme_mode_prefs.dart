import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// Which palette this phone is painted in, remembered across launches.
///
/// ⚠️ **Device-local, deliberately not synced.** Sharing a mood is the
/// point of this app; sharing a screen brightness is not. Two people in two
/// timezones are in daylight and darkness at different hours, and a setting
/// that followed the pair would flip one of their phones to night while
/// they were outside in the sun.
class ThemeModePrefs extends StateNotifier<AppMode> {
  ThemeModePrefs() : super(startingMode) {
    _load();
  }

  static const _key = 'theme_mode';

  /// What the first frame is painted in, before storage has answered.
  ///
  /// 🔴 Read synchronously by `main()` and set on [AppColors] *before*
  /// `runApp`. Storage is a future, and a dark-mode user who saw a white
  /// flash on every cold start would rightly call that a bug — so the mode
  /// is restored before there is anything on screen to flash.
  static AppMode startingMode = AppMode.light;

  /// Restores the saved mode into [AppColors]. Call before `runApp`.
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      startingMode = decode(prefs.getString(_key));
    } catch (_) {
      // A phone that will not give up its preferences still gets an app.
      startingMode = AppMode.light;
    }
    AppColors.use(startingMode);
  }

  /// Tolerant of a value this build has never heard of — a newer app that
  /// adds a third palette must not brick an older one.
  static AppMode decode(String? name) {
    for (final mode in AppMode.values) {
      if (mode.name == name) return mode;
    }
    return AppMode.light;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = decode(prefs.getString(_key));
    } catch (_) {
      // Keep whatever was already showing.
    }
  }

  Future<void> use(AppMode mode) async {
    if (mode == state) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // The screen already changed; it simply will not survive a restart.
    }
  }

  Future<void> toggle() => use(state.other);
}

final themeModeProvider =
    StateNotifierProvider<ThemeModePrefs, AppMode>((ref) => ThemeModePrefs());

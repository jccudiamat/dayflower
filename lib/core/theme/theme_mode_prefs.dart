import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// What somebody chose under Settings, Appearance.
///
/// 🔴 **Not the same thing as [AppMode], and kept apart on purpose.**
/// AppMode is a palette, and there are two. This is a choice, and there are
/// three: "System" is not a third palette, it is "whichever of the two the
/// phone is using right now", and it changes under the app at sunset on a
/// phone set to go dark on a schedule. Adding it to AppMode would have put a
/// palette-less value into every `AppMode.values` loop that paints both.
enum Appearance {
  system('System', 'Matches your phone (default)'),
  light('Light', 'Always light'),
  dark('Dark', 'Always dark. Kinder at night.');

  const Appearance(this.title, this.line);
  final String title;
  final String line;

  /// The palette this choice paints, on a phone currently set to [phone].
  AppMode resolve(Brightness phone) => switch (this) {
        Appearance.light => AppMode.light,
        Appearance.dark => AppMode.dark,
        Appearance.system =>
          phone == Brightness.dark ? AppMode.dark : AppMode.light,
      };
}

/// The appearance this phone is set to, remembered across launches.
///
/// ⚠️ **Device-local, deliberately not synced.** Sharing a mood is the
/// point of this app; sharing a screen brightness is not. Two people in two
/// timezones are in daylight and darkness at different hours, and a setting
/// that followed the pair would flip one of their phones to night while
/// they were outside in the sun.
class ThemeModePrefs extends StateNotifier<Appearance> {
  ThemeModePrefs() : super(startingChoice) {
    _load();
  }

  static const _key = 'theme_mode';

  /// What the first frame is painted in, before storage has answered.
  ///
  /// 🔴 Read by `main()` and set on [AppColors] *before* `runApp`. Storage
  /// is a future, and a dark-mode user who saw a white flash on every cold
  /// start would rightly call that a bug — so the choice is restored, and
  /// resolved against the phone, before there is anything on screen to
  /// flash.
  static Appearance startingChoice = Appearance.system;

  /// Restores the saved choice into [AppColors]. Call before `runApp`.
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      startingChoice = decode(prefs.getString(_key));
    } catch (_) {
      // A phone that will not give up its preferences still gets an app.
      startingChoice = Appearance.system;
    }
    AppColors.use(
        startingChoice.resolve(PlatformDispatcher.instance.platformBrightness));
  }

  /// Nothing saved means System, the default. So does a value this build
  /// has never heard of: a newer app that adds a choice must not brick an
  /// older one.
  ///
  /// ⚠️ The key and the two old names are what the Dark mode switch saved,
  /// so somebody who turned it on stays dark and somebody who turned it off
  /// again stays light. Only a phone that never touched it moves to System.
  static Appearance decode(String? name) {
    for (final choice in Appearance.values) {
      if (choice.name == name) return choice;
    }
    return Appearance.system;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = decode(prefs.getString(_key));
    } catch (_) {
      // Keep whatever was already showing.
    }
  }

  Future<void> use(Appearance choice) async {
    if (choice == state) return;
    state = choice;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, choice.name);
    } catch (_) {
      // The screen already changed; it simply will not survive a restart.
    }
  }
}

final appearanceProvider = StateNotifierProvider<ThemeModePrefs, Appearance>(
    (ref) => ThemeModePrefs());

/// Whether the phone itself is in dark mode right now. Kept current by the
/// root widget (`didChangePlatformBrightness` in app.dart), so System
/// follows the phone while the app is open, not just at launch.
final phoneBrightnessProvider = StateProvider<Brightness>(
    (ref) => PlatformDispatcher.instance.platformBrightness);

/// The palette the app is painted in: the choice, resolved against the
/// phone.
final themeModeProvider = Provider<AppMode>((ref) => ref
    .watch(appearanceProvider)
    .resolve(ref.watch(phoneBrightnessProvider)));

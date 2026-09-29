import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widget_sync.dart';

/// The scenes the heartbeat widget can show, in the order Settings lists
/// them. The art is built by tool/make_heartbeat_art.py from the designs in
/// assets/heartbeat/src: an Android drawable each for the widget
/// (hb_art_<name>, mapped in HeartbeatWidget.artFor) and a small copy here
/// for Settings.
///
/// ⚠️ [name] is what the widget stores and Kotlin reads: renaming one is a
/// change on both sides, and a phone already showing the old name falls
/// back to the moon.
enum HeartbeatTheme {
  /// The heart with the moon and the clouds, and everyone's.
  moon('Moonlight', premium: false),
  cat('Kitten', premium: true),
  tulips('Tulips', premium: true),
  puppy('Puppy', premium: true),
  capybara('Capybara', premium: true);

  const HeartbeatTheme(this.label, {required this.premium});

  final String label;

  /// Only with Dayflower Premium ([premiumProvider]).
  final bool premium;

  String get thumbnail => 'assets/images/heartbeat/$name.webp';

  static const fallback = HeartbeatTheme.moon;

  static HeartbeatTheme fromName(String? name) =>
      values.where((t) => t.name == name).firstOrNull ?? fallback;
}

/// Whether this couple has Dayflower Premium.
///
/// 🔴 **Always false, because nothing can be bought yet.** There is no
/// store product, receipt or entitlement anywhere in this app (see the
/// premium card on Us, which says so). This is the one place a real
/// entitlement goes once there is one; everything premium reads it, so
/// nothing else has to change when it does.
final premiumProvider = Provider<bool>((ref) => false);

/// The heartbeat widget's scene.
///
/// ⚠️ Stored in the shared widget store, not SharedPreferences, so the
/// widget reads the same value while the app is closed.
class HeartbeatThemeNotifier extends StateNotifier<HeartbeatTheme> {
  HeartbeatThemeNotifier({required bool premium})
      : _premium = premium,
        super(HeartbeatTheme.fallback) {
    _load();
  }

  final bool _premium;

  /// Set by a choice, so a stored value read after it cannot undo it.
  var _chosen = false;

  Future<void> _load() async {
    final stored = HeartbeatTheme.fromName(await DayflowerWidgets.currentBeatTheme());
    // A premium scene without premium (lapsed, or never had it): the
    // default, on the widget too, not only here.
    if (stored.premium && !_premium) {
      await DayflowerWidgets.setBeatTheme(HeartbeatTheme.fallback.name);
      return;
    }
    if (mounted && !_chosen) state = stored;
  }

  /// Puts [theme] on the widget, unless it is premium and this couple is
  /// not. Returns whether it did.
  Future<bool> choose(HeartbeatTheme theme) async {
    if (theme.premium && !_premium) return false;
    _chosen = true;
    state = theme;
    await DayflowerWidgets.setBeatTheme(theme.name);
    return true;
  }
}

final heartbeatThemeProvider =
    StateNotifierProvider<HeartbeatThemeNotifier, HeartbeatTheme>(
  (ref) => HeartbeatThemeNotifier(premium: ref.watch(premiumProvider)),
);

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../presentation/widgets/ring_light.dart';

/// Whether a video call lights your face from the edges of the screen.
///
/// ⚠️ **Off by default, and it has to be.** It is the screen at full
/// brightness in a ring around whatever you are looking at: useful in a dark
/// room, and an ambush anywhere else. Somebody who has never heard of it
/// should never meet it by accident on an incoming call at night.
///
/// ⚠️ Device-local, like the theme. It is about the light where *you* are,
/// which the other person's phone knows nothing about — see ThemeModePrefs
/// for the same reasoning about a setting that must not follow the pair.
class RingLightPrefs extends StateNotifier<bool> {
  RingLightPrefs() : super(false) {
    _load();
  }

  static const _key = 'call_ring_light';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_key) ?? false;
    } catch (e) {
      // A phone that will not give up its preferences still gets a call.
      debugPrint('ring light preference failed to load: $e');
    }
  }

  Future<void> set(bool on) async {
    if (on == state) return;
    state = on;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, on);
    } catch (e) {
      // The light is already on; it simply will not survive a restart.
      debugPrint('ring light preference failed to save: $e');
    }
  }

  Future<void> toggle() => set(!state);
}

final ringLightProvider =
    StateNotifierProvider<RingLightPrefs, bool>((ref) => RingLightPrefs());

/// How wide the ring light is, in points of reach from the edge.
///
/// Device-local for the same reason the switch is: it is about the light
/// where you are. Set live from the slider under the call's controls while
/// the light is on; written to disk only when the thumb is let go, so a
/// drag is one write rather than sixty.
class RingLightWidth extends StateNotifier<double> {
  RingLightWidth() : super(RingLight.defaultThickness) {
    _load();
  }

  static const _key = 'call_ring_light_width';

  /// Whether the slider has moved since this was built, so a slow read
  /// from disk cannot snap the light back under a finger.
  bool _touched = false;

  static double clamp(double width) =>
      width.clamp(RingLight.minThickness, RingLight.maxThickness).toDouble();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getDouble(_key);
      if (stored != null && !_touched) state = clamp(stored);
    } catch (e) {
      debugPrint('ring light width failed to load: $e');
    }
  }

  /// While dragging: the light follows the thumb.
  void preview(double width) {
    _touched = true;
    state = clamp(width);
  }

  /// On letting go: kept for the next call.
  Future<void> save(double width) async {
    preview(width);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_key, state);
    } catch (e) {
      debugPrint('ring light width failed to save: $e');
    }
  }
}

final ringLightWidthProvider =
    StateNotifierProvider<RingLightWidth, double>((ref) => RingLightWidth());

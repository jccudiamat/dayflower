import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/pulse_alerts.dart';

/// Whether an incoming heartbeat buzzes and sounds. Device-local, not synced —
/// each phone decides for itself.
///
/// ⚠️ A plain bool, and that is the point. This used to be a settings object
/// carrying a cadence as well: on/off, plus a window of ten, thirty or
/// sixty minutes inside which further heartbeats updated the notification
/// silently. Both the window and the choice of window are gone.
///
/// A heartbeat is one tap that means one thing. Someone who has switched these
/// on has said they want to feel it when their partner thinks of them, and
/// deciding on their behalf that the second one in ten minutes was not worth a
/// buzz was answering a question they had already answered. The only real
/// question left is the one this holds: all of them, or none.
class PulseAlertPrefs extends StateNotifier<bool> {
  PulseAlertPrefs()
      // On by default on phones: feeling the pulse is the point of the
      // feature. Off on web/desktop, where none of it works anyway.
      : super(PulseAlerts.supported) {
    _load();
  }

  static const _kEnabled = 'heartbeat_alerts_enabled';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_kEnabled) ?? state;
      // Ask for notification permission at most once per launch, and only when
      // alerts are actually on. Declining leaves the vibration working.
      if (state) unawaited(PulseAlerts.requestPermission());
    } catch (e) {
      debugPrint('pulse alert prefs load failed: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    if (value) await PulseAlerts.requestPermission();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, value);
    } catch (e) {
      debugPrint('pulse alert prefs save failed: $e');
    }
  }
}

/// True when incoming heartbeats should buzz, sound and notify.
final pulseAlertsEnabledProvider =
    StateNotifierProvider<PulseAlertPrefs, bool>((ref) => PulseAlertPrefs());

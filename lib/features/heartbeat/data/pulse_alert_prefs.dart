import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/pulse_alerts.dart';

@immutable
class PulseAlertSettings {
  const PulseAlertSettings({required this.enabled, required this.cadence});

  final bool enabled;
  final PulseCadence cadence;

  PulseAlertSettings copyWith({bool? enabled, PulseCadence? cadence}) =>
      PulseAlertSettings(
        enabled: enabled ?? this.enabled,
        cadence: cadence ?? this.cadence,
      );
}

/// Whether an incoming heartbeat buzzes and sounds, and how often it's allowed
/// to. Device-local, not synced — each phone decides for itself.
class PulseAlertPrefs extends StateNotifier<PulseAlertSettings> {
  PulseAlertPrefs()
      : super(
          PulseAlertSettings(
            // On by default on phones: feeling the pulse is the point of the
            // feature. Off on web/desktop, where none of it works anyway.
            enabled: PulseAlerts.supported,
            cadence: PulseCadence.tenMinutes,
          ),
        ) {
    _load();
  }

  static const _kEnabled = 'heartbeat_alerts_enabled';
  static const _kCadence = 'heartbeat_alert_cadence';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = state.copyWith(
        enabled: prefs.getBool(_kEnabled),
        cadence: PulseCadence.fromName(prefs.getString(_kCadence)),
      );
      // Ask for notification permission at most once per launch, and only when
      // alerts are actually on. Declining leaves the vibration working.
      if (state.enabled) unawaited(PulseAlerts.requestPermission());
    } catch (e) {
      debugPrint('pulse alert prefs load failed: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    if (value) await PulseAlerts.requestPermission();
    await _write((prefs) => prefs.setBool(_kEnabled, value));
  }

  Future<void> setCadence(PulseCadence cadence) async {
    state = state.copyWith(cadence: cadence);
    await _write((prefs) => prefs.setString(_kCadence, cadence.name));
  }

  Future<void> _write(Future<void> Function(SharedPreferences) op) async {
    try {
      await op(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('pulse alert prefs save failed: $e');
    }
  }
}

final pulseAlertSettingsProvider =
    StateNotifierProvider<PulseAlertPrefs, PulseAlertSettings>(
  (ref) => PulseAlertPrefs(),
);

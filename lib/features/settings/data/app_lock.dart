import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locking the app without logging anybody out.
///
/// ## Why this exists instead of a session timeout
///
/// "Someone picked up my phone" is a **device** threat. Logging the session
/// out to solve it is the wrong instrument and an expensive one here: the
/// heartbeat widget sends a pulse from a background isolate with the app
/// never opening, reminder alarms fire with it dead, and signing out drops
/// the FCM token so every notification stops. All three break silently —
/// nothing visibly fails, so nobody reports it.
///
/// A lock over the UI protects against the actual threat and costs none of
/// that. The session stays valid; only the screen is closed. Signal and
/// WhatsApp ship exactly this and call it Screen Lock.
enum AppLockDelay {
  immediately('Immediately', Duration.zero),

  /// The default. Long enough to survive switching to the camera, the
  /// gallery or a notification and coming straight back — a lock that
  /// challenges you for stepping out for four seconds gets turned off.
  oneMinute('After 1 minute', Duration(minutes: 1)),

  fifteenMinutes('After 15 minutes', Duration(minutes: 15)),
  oneHour('After 1 hour', Duration(hours: 1));

  const AppLockDelay(this.label, this.after);

  final String label;
  final Duration after;

  static AppLockDelay byName(String? name) => AppLockDelay.values.firstWhere(
        (d) => d.name == name,
        orElse: () => AppLockDelay.oneMinute,
      );
}

@immutable
class AppLockSettings {
  const AppLockSettings({
    this.enabled = false,
    this.delay = AppLockDelay.oneMinute,
  });

  final bool enabled;
  final AppLockDelay delay;

  AppLockSettings copyWith({bool? enabled, AppLockDelay? delay}) =>
      AppLockSettings(
        enabled: enabled ?? this.enabled,
        delay: delay ?? this.delay,
      );
}

/// Whether this phone can do it at all, and the prompt itself.
class AppLockAuth {
  AppLockAuth._();

  static final _auth = LocalAuthentication();

  /// ⚠️ **`isDeviceSupported`, not `canCheckBiometrics`.** The latter is only
  /// true where a fingerprint or face is actually enrolled; the former also
  /// covers a phone with just a PIN or pattern, which is the majority and is
  /// perfectly good enough to gate a reminders app. Asking the narrower
  /// question would hide the setting from most people who could use it.
  static Future<bool> available() async {
    if (kIsWeb || !Platform.isAndroid && !Platform.isIOS) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Returns true only on a real unlock.
  ///
  /// `biometricOnly: false` on purpose — falling back to the device PIN is
  /// what makes this usable with a wet thumb, and refusing that fallback
  /// would strand anyone whose fingerprint stopped reading.
  static Future<bool> unlock() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Dayflower',
        // ⚠️ local_auth 3.x flattened these out of AuthenticationOptions,
        // and renamed stickyAuth to persistAcrossBackgrounding. The old
        // shape is what every example on the internet still shows.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // A cancelled prompt, no enrolled credential, a locked-out sensor.
      // All of them mean "still locked" — never "let them in".
      return false;
    }
  }
}

/// The setting, on this device only.
///
/// ⚠️ Deliberately **not** synced to Supabase. A lock is a decision about one
/// handset: locking your phone must not lock your partner's, and a row would
/// make it a property of the account. It is also the one setting that has to
/// work before the session is usable, so it cannot live behind the network.
class AppLockPrefs extends StateNotifier<AppLockSettings> {
  AppLockPrefs() : super(const AppLockSettings()) {
    _load();
  }

  static const _keyEnabled = 'app_lock_enabled';
  static const _keyDelay = 'app_lock_delay';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppLockSettings(
      enabled: prefs.getBool(_keyEnabled) ?? false,
      delay: AppLockDelay.byName(prefs.getString(_keyDelay)),
    );
  }

  /// Turning it **on** asks for an unlock first.
  ///
  /// Without that, somebody holding your unlocked phone could switch the
  /// lock on and pick their own delay — and on a device with nothing
  /// enrolled it would lock the owner out of their own app with no way back.
  Future<bool> setEnabled(bool value) async {
    if (value && !await AppLockAuth.unlock()) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
    state = state.copyWith(enabled: value);
    return true;
  }

  Future<void> setDelay(AppLockDelay delay) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDelay, delay.name);
    state = state.copyWith(delay: delay);
  }
}

final appLockPrefsProvider =
    StateNotifierProvider<AppLockPrefs, AppLockSettings>(
  (ref) => AppLockPrefs(),
);

/// Whether the app is showing the lock screen right now.
///
/// Separate from the setting because it changes on every trip to the
/// background, and nothing that merely reads the setting should rebuild for
/// that.
final appLockedProvider = StateProvider<bool>((ref) => false);

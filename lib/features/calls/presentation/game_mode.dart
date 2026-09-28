import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/call_transport.dart';
import '../domain/call.dart';
import '../domain/call_notifier.dart';
import 'widgets/call_video.dart';

/// Game mode: the call as a small circle floating over other apps.
///
/// For playing a game together: their face in a circle over the game, their
/// voice carrying on, and a tap on the circle to come back. The Android half,
/// which draws the circle, is `GameOverlay.kt`.
///
/// ⚠️ **Not picture-in-picture.** A PiP window is a rectangle the size of a
/// small video, sized by the system. A circle this small is a window of the
/// app's own over other apps, which Android only allows once the person has
/// switched on "Display over other apps" for Dayflower in Settings. Asked
/// for the first time game mode is used, and never before.
///
/// ⚠️ **Android only**, API 26+. Everywhere else the option is not offered.

/// What asking for game mode came to.
enum GameModeStart {
  /// The circle is up and the app has gone to the background.
  floating,

  /// "Display over other apps" is off. See [GameModeNotifier.askPermission].
  needsPermission,

  /// Not a phone this can float on.
  unsupported,

  /// The system refused, or there is no call to float.
  failed,
}

/// Whether game mode can be offered at all on this phone.
final gameModeSupportedProvider = FutureProvider<bool>((ref) async {
  if (!GameModeNotifier.android) return false;
  return await GameModeNotifier.invoke<bool>('supported') ?? false;
});

/// True while the call is floating as the circle.
final gameModeProvider =
    NotifierProvider<GameModeNotifier, bool>(GameModeNotifier.new);

class GameModeNotifier extends Notifier<bool> {
  static const _channel = MethodChannel('dayflower/game_mode');

  static bool get android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The media to follow while floating, see [remoteVideoChanges].
  Listenable? _media;

  /// What the circle was last told, so the timer's once-a-second session
  /// change does not become a once-a-second call across the channel.
  ({String? trackId, bool speaking})? _sent;

  /// Waiting for the person to come back from Settings.
  AppLifecycleListener? _waiting;

  @override
  bool build() {
    // Back in the app, by the circle or any other way: the Activity has
    // already taken the circle down. See MainActivity.onResume.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'ended') _ended();
    });
    ref.listen<CallSession?>(callNotifierProvider, (_, session) {
      if (session == null || session.status.isTerminal) {
        stop();
      } else if (state) {
        _push();
      }
    });
    ref.onDispose(() {
      _unhook();
      _waiting?.dispose();
    });
    return false;
  }

  /// Floats the call and sends the app to the background.
  Future<GameModeStart> start() async {
    if (!android) return GameModeStart.unsupported;
    final session = ref.read(callNotifierProvider);
    if (session == null || session.status.isTerminal) {
      return GameModeStart.failed;
    }
    if (await invoke<bool>('canDraw') != true) {
      return GameModeStart.needsPermission;
    }
    final media = _now();
    final floating = await invoke<bool>('start', {
          'trackId': media.trackId,
          'speaking': media.speaking,
        }) ??
        false;
    if (!floating) return GameModeStart.failed;
    _sent = media;
    state = true;
    _hook();
    return GameModeStart.floating;
  }

  /// Opens Settings at "Display over other apps", and floats the call when
  /// they come back with it switched on: they asked for game mode, and it
  /// should not take a second tap to get it.
  Future<void> askPermission() async {
    final opened = await invoke<bool>('requestPermission') ?? false;
    if (!opened) return;
    _waiting?.dispose();
    _waiting = AppLifecycleListener(onResume: () async {
      _waiting?.dispose();
      _waiting = null;
      if (await invoke<bool>('canDraw') == true) await start();
    });
  }

  /// Takes the circle away, as when the call ends.
  Future<void> stop() async {
    _waiting?.dispose();
    _waiting = null;
    if (!state) return;
    _unhook();
    state = false;
    await invoke<void>('stop');
  }

  void _ended() {
    _unhook();
    state = false;
  }

  void _hook() {
    _unhook();
    _media = remoteVideoChanges(ref.read(callTransportProvider));
    _media?.addListener(_push);
  }

  void _unhook() {
    _media?.removeListener(_push);
    _media = null;
    _sent = null;
  }

  /// Their camera's track, if it is on, and whether they are talking.
  ({String? trackId, bool speaking}) _now() {
    final session = ref.read(callNotifierProvider);
    return (
      trackId: session != null && session.isVideo
          ? remoteVideoTrackId(ref.read(callTransportProvider))
          : null,
      speaking: session?.partnerSpeaking ?? false,
    );
  }

  void _push() {
    if (!state) return;
    final media = _now();
    if (media == _sent) return;
    _sent = media;
    invoke<void>('update', {
      'trackId': media.trackId,
      'speaking': media.speaking,
    });
  }

  @visibleForTesting
  static Future<T?> invoke<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (e) {
      // An Android build whose native half has not been rebuilt yet, and
      // every other platform.
      debugPrint('game mode $method failed: $e');
      return null;
    }
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Recording and playing a voice message, over the channel VoiceNotes.kt
/// answers on.
///
/// ⚠️ Android only, and it says so rather than pretending. Every other
/// platform gets [supported] false, and the composer does not offer the
/// button at all.
class VoiceNotes {
  VoiceNotes._();

  static const _channel = MethodChannel('dayflower/voice');

  /// Longest a voice note may run. The recorder stops itself here too, so a
  /// phone that missed the timer still cannot produce a longer one.
  static const maxDuration = Duration(minutes: 2);

  /// Shorter than this and it was a mis-tap, not a message.
  static const minDuration = Duration(milliseconds: 700);

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static final _finished = StreamController<void>.broadcast();
  static bool _listening = false;

  /// Playback reached the end. Told rather than polled, so a bubble resets
  /// the instant it finishes.
  static Stream<void> get playbackFinished {
    if (!_listening && supported) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'finished') _finished.add(null);
      });
    }
    return _finished.stream;
  }

  static Future<void> startRecording() async {
    if (!supported) return;
    await _channel.invokeMethod<void>('start');
  }

  /// Stops and returns the file, or null when nothing usable was captured.
  static Future<({String path, Duration length})?> stopRecording() async {
    if (!supported) return null;
    final result = await _channel.invokeMapMethod<String, dynamic>('stop');
    final path = result?['path'];
    final ms = result?['ms'];
    if (path is! String || ms is! int) return null;
    return (path: path, length: Duration(milliseconds: ms));
  }

  /// Pauses the recording and returns how much has actually been captured.
  ///
  /// ⚠️ The length comes back from the recorder rather than being counted
  /// here: a paused recorder writes nothing, so a timer on this side would
  /// claim seconds of audio the file does not contain.
  static Future<Duration> pauseRecording() async {
    if (!supported) return Duration.zero;
    final ms = await _channel.invokeMethod<int>('pauseRecording');
    return Duration(milliseconds: ms ?? 0);
  }

  static Future<Duration> resumeRecording() async {
    if (!supported) return Duration.zero;
    final ms = await _channel.invokeMethod<int>('resumeRecording');
    return Duration(milliseconds: ms ?? 0);
  }

  static Future<void> cancelRecording() async {
    if (!supported) return;
    await _channel.invokeMethod<void>('cancel');
  }

  /// Loudness right now, 0 to 1, for the bar that moves while you speak.
  static Future<double> amplitude() async {
    if (!supported) return 0;
    final value = await _channel.invokeMethod<double>('amplitude');
    return value ?? 0;
  }

  /// Plays a local file. Returns how long it runs, as the file reports it.
  static Future<Duration?> play(String path) async {
    if (!supported) return null;
    final ms = await _channel.invokeMethod<int>('play', {'path': path});
    return ms == null ? null : Duration(milliseconds: ms);
  }

  static Future<void> pause() async {
    if (supported) await _channel.invokeMethod<void>('pause');
  }

  static Future<void> resume() async {
    if (supported) await _channel.invokeMethod<void>('resume');
  }

  static Future<void> seek(Duration to) async {
    if (supported) {
      await _channel.invokeMethod<void>('seek', {'ms': to.inMilliseconds});
    }
  }

  static Future<void> stopPlaying() async {
    if (supported) await _channel.invokeMethod<void>('stopPlay');
  }

  /// Where playback is, and whether it is running.
  static Future<({Duration at, bool playing})> position() async {
    if (!supported) return (at: Duration.zero, playing: false);
    final result = await _channel.invokeMapMethod<String, dynamic>('position');
    return (
      at: Duration(milliseconds: (result?['ms'] as int?) ?? 0),
      playing: result?['playing'] == true,
    );
  }
}

/// Voice notes downloaded for playback, kept for the session.
///
/// ⚠️ The player needs a real file on disk, not a URL: the bucket is
/// private, so there is no permanent address, and a signed URL would expire
/// mid-sentence. Downloading once and playing the file is also what makes
/// replaying one instant.
class VoiceNoteFiles {
  VoiceNoteFiles._();

  static final _files = <String, String>{};

  /// A local path for [storagePath], downloading it if this is the first
  /// time. [fetch] is what actually reads the bucket.
  static Future<String?> local(
    String storagePath,
    Future<Uint8List> Function() fetch,
  ) async {
    final known = _files[storagePath];
    if (known != null && await File(known).exists()) return known;
    try {
      final bytes = await fetch();
      final dir = await getTemporaryDirectory();
      final name = storagePath.split('/').last;
      final file = File('${dir.path}/voice-$name');
      await file.writeAsBytes(bytes);
      _files[storagePath] = file.path;
      return file.path;
    } catch (e) {
      debugPrint('voice note download failed: $e');
      return null;
    }
  }

  /// The sender already holds every byte of it, so their own voice note
  /// plays from the phone rather than downloading back what was just sent.
  static Future<void> prime(String storagePath, String localPath) async {
    _files[storagePath] = localPath;
  }

  @visibleForTesting
  static void clear() => _files.clear();
}

/// Which voice note is playing, if any. One at a time, everywhere: two
/// voices at once is nobody's intention.
final playingVoiceProvider = StateProvider<String?>((ref) => null);

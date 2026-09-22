import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// The caller's face, kept on disk so a ring never waits for it.
///
/// 🔴 **A ring is the worst possible moment to start a download.** The first
/// call after a cold start showed a green circle with a letter in it, and the
/// real photo only appeared once the app had been opened — because the
/// partner's profile had not resolved yet, so there was no path to fetch, so
/// the notification went out with no icon at all. By the time anything could
/// be fetched the notification had already been posted.
///
/// So the bytes are written down the moment the profile is known, and read
/// back from disk when the phone rings. Disk, not memory: the process is dead
/// far more often than it is alive, and a memory cache is empty in exactly
/// the case that was broken.
class CallerAvatar {
  CallerAvatar._();

  static const _fileName = 'caller_avatar';

  static Future<File?> _file() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('caller avatar dir failed: $e');
      return null;
    }
  }

  /// Whatever face was last saved, or null. Never throws, never blocks on a
  /// network — a call still rings without a picture.
  static Future<Uint8List?> cached() async {
    try {
      final file = await _file();
      if (file == null || !await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (e) {
      debugPrint('caller avatar read failed: $e');
      return null;
    }
  }

  /// Downloads [url] and keeps it for the next ring.
  ///
  /// ⚠️ Called when the profile loads, not when the phone rings. Returns the
  /// bytes so the caller can use them immediately if a ring is already
  /// happening.
  static Future<Uint8List?> remember(String url) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final response = await (await client.getUrl(Uri.parse(url))).close();
      if (response.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(response);
      if (bytes.isEmpty) return null;
      final file = await _file();
      // ⚠️ Written even though it is only ever a cache: losing it costs a
      // letter in a circle, not a call.
      await file?.writeAsBytes(bytes, flush: true);
      return bytes;
    } catch (e) {
      debugPrint('caller avatar fetch failed: $e');
      return null;
    }
  }

  /// They changed their photo, or unpaired.
  static Future<void> forget() async {
    try {
      final file = await _file();
      if (file != null && await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('caller avatar delete failed: $e');
    }
  }
}

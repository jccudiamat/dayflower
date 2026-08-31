import 'package:flutter/foundation.dart';

/// One published build, as described by the `latest.json` manifest that
/// `tool/publish_update.dart` writes into the `app-builds` storage bucket.
///
/// The manifest is a flat JSON object in Storage rather than a Postgres
/// table on purpose: the update check runs on a cold start, before login, so
/// it must not need a session, an RLS policy or a PostgREST round trip.
@immutable
class AppRelease {
  const AppRelease({
    required this.buildNumber,
    required this.versionName,
    required this.fileName,
    required this.sizeBytes,
    required this.notes,
    required this.minBuildNumber,
    this.publishedAt,
  });

  /// Android's versionCode — the `+N` half of pubspec's `version:` line, and
  /// the only thing that decides whether an update exists. The version *name*
  /// sits at "1.0.0" across a hundred dev builds, so comparing that would
  /// mean the sheet never fires.
  final int buildNumber;

  /// Shown to the user ("1.0.0"); never compared.
  final String versionName;

  /// APK object name inside the bucket, e.g. `dayflower-7.apk`.
  final String fileName;

  final int sizeBytes;

  /// One line per bullet in the sheet. Empty is fine — the sheet drops the
  /// list rather than showing an empty box.
  final List<String> notes;

  /// Installed builds below this cannot dismiss the update. The escape hatch
  /// for "that build corrupts data, nobody may stay on it". Normally 0.
  final int minBuildNumber;

  final DateTime? publishedAt;

  factory AppRelease.fromMap(Map<String, dynamic> map) {
    final rawNotes = map['notes'];
    return AppRelease(
      buildNumber: _asInt(map['buildNumber']),
      versionName: map['versionName'] as String? ?? '—',
      fileName: map['apk'] as String? ?? '',
      sizeBytes: _asInt(map['sizeBytes']),
      notes: rawNotes is List
          ? rawNotes
              .map((n) => '$n'.trim())
              .where((n) => n.isNotEmpty)
              .toList(growable: false)
          : const [],
      minBuildNumber: _asInt(map['minBuildNumber']),
      publishedAt:
          DateTime.tryParse(map['publishedAt'] as String? ?? '')?.toLocal(),
    );
  }

  static int _asInt(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  /// A manifest missing either half of "which build" and "which file" is
  /// treated as no manifest at all — better to stay quiet than to offer an
  /// update that can't be downloaded.
  bool get isUsable => buildNumber > 0 && fileName.isNotEmpty;

  /// Sizes here are always tens of megabytes, so MB with one decimal is the
  /// only unit worth printing.
  String get readableSize => sizeBytes <= 0
      ? ''
      : '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

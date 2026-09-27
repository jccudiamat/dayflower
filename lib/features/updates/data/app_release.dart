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
    this.sha256,
    this.patches = const {},
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

  /// The APK's SHA-256, which an APK rebuilt from a patch must match.
  /// Null in manifests from before patches, which then offer none.
  final String? sha256;

  /// Patches to this build, by the build they apply to: a phone on one of
  /// those downloads the patch (a few MB) rather than the whole APK.
  /// See ApkPatch.
  final Map<int, AppPatch> patches;

  /// The patch for a phone on [installedBuild], if there is one it can use.
  AppPatch? patchFrom(int installedBuild) =>
      sha256 == null ? null : patches[installedBuild];

  /// What a phone on [installedBuild] downloads: the patch, or the APK.
  int downloadBytesFor(int installedBuild) =>
      patchFrom(installedBuild)?.sizeBytes ?? sizeBytes;

  factory AppRelease.fromMap(Map<String, dynamic> map) {
    final rawNotes = map['notes'];
    final rawPatches = map['patches'];
    return AppRelease(
      buildNumber: _asInt(map['buildNumber']),
      versionName: map['versionName'] as String? ?? '?',
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
      sha256: map['sha256'] as String?,
      patches: {
        if (rawPatches is Map)
          for (final MapEntry(:key, :value) in rawPatches.entries)
            if (int.tryParse('$key') case final from?
                when value is Map && value['object'] is String)
              from: AppPatch(
                fileName: value['object'] as String,
                sizeBytes: _asInt(value['sizeBytes']),
              ),
      },
    );
  }

  static int _asInt(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  /// A manifest missing either half of "which build" and "which file" is
  /// treated as no manifest at all — better to stay quiet than to offer an
  /// update that can't be downloaded.
  bool get isUsable => buildNumber > 0 && fileName.isNotEmpty;

  /// Sizes here are megabytes, so MB with one decimal is the only unit
  /// worth printing.
  String get readableSize => readableBytes(sizeBytes);

  /// What a phone on [installedBuild] will download, readably.
  String readableSizeFor(int installedBuild) =>
      readableBytes(downloadBytesFor(installedBuild));

  static String readableBytes(int bytes) => bytes <= 0
      ? ''
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// One patch in the manifest: from an older build to this one.
@immutable
class AppPatch {
  const AppPatch({required this.fileName, required this.sizeBytes});

  /// Object name inside the bucket.
  final String fileName;
  final int sizeBytes;
}

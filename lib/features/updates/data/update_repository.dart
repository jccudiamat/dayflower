import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import 'app_release.dart';

/// Fetching the manifest, pulling the APK down, and handing it to Android.
///
/// Everything here talks to the `app-builds` bucket over plain HTTP rather
/// than through `supabase_flutter`'s storage client, for two reasons: the
/// bucket is public so there is no session to attach, and `StorageClient`'s
/// download buffers the whole object in memory with no progress callback —
/// useless for 50 MB behind a progress bar.
class UpdateRepository {
  const UpdateRepository();

  /// Android-only. iOS has no legal route to self-installing an IPA, and the
  /// desktop/web builds are run from source, so everywhere else the whole
  /// feature is a no-op rather than a button that fails.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _manifestObject = 'latest.json';

  /// The build number currently installed on this phone — pubspec's `+N`,
  /// read from the APK itself rather than from a constant in the source, so
  /// it can never drift from what is actually running.
  Future<int> installedBuild() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  Future<String> installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  }

  /// The newest published build, or null when nothing has been published yet.
  /// A 404 on the manifest is the normal state before the first publish, not
  /// an error worth showing anyone.
  Future<AppRelease?> fetchLatest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      // Supabase serves public objects through a CDN that will happily hand
      // back yesterday's manifest. The timestamp is what actually defeats it;
      // the no-cache header only covers the local HTTP stack.
      final url = _objectUrl(_manifestObject).replace(queryParameters: {
        't': '${DateTime.now().millisecondsSinceEpoch}',
      });
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close();

      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw HttpException('manifest returned ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final release =
          AppRelease.fromMap(jsonDecode(body) as Map<String, dynamic>);
      return release.isUsable ? release : null;
    } finally {
      client.close(force: true);
    }
  }

  /// Streams the APK to app-private external storage, reporting bytes as they
  /// land. Returns the finished file.
  Future<File> download(
    AppRelease release, {
    required void Function(int received, int total) onProgress,
  }) async {
    final dir = await _downloadDir();
    final file = File('${dir.path}/${release.fileName}');

    // A complete download from an earlier attempt is worth keeping: if the
    // app was killed between "downloaded" and "installed", the sheet goes
    // straight back to Install instead of re-pulling the whole APK.
    if (release.sizeBytes > 0 &&
        await file.exists() &&
        await file.length() == release.sizeBytes) {
      onProgress(release.sizeBytes, release.sizeBytes);
      return file;
    }

    final partial = File('${file.path}.part');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(_objectUrl(release.fileName));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('apk returned ${response.statusCode}');
      }

      // contentLength is -1 on a chunked response; the manifest's own figure
      // is the fallback so the bar still fills rather than spinning forever.
      final total = response.contentLength > 0
          ? response.contentLength
          : release.sizeBytes;

      var received = 0;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      // The rename is what makes a download "complete". Writing straight to
      // the final name would let a connection dropped at 90% look like a
      // finished APK on the next launch — and Android would reject that with
      // a parse error the user can do nothing about.
      if (await file.exists()) await file.delete();
      await partial.rename(file.path);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }

    await _purgeOtherBuilds(dir, keep: file.path);
    return file;
  }

  /// Hands the APK to Android's package installer. The user still confirms
  /// there, and the first time round Android also asks them to allow
  /// "Install unknown apps" for Dayflower — that prompt comes from the OS,
  /// which is why there is nothing to request up front.
  Future<void> install(File apk) async {
    final result = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }

  Uri _objectUrl(String object) {
    final base =
        (dotenv.env['SUPABASE_URL'] ?? '').replaceAll(RegExp(r'/+$'), '');
    return Uri.parse(
      '$base/storage/v1/object/public/${AppConstants.bucketBuilds}/$object',
    );
  }

  Future<Directory> _downloadDir() async {
    // App-private external storage: writable with no runtime permission, and
    // one of the roots open_filex's FileProvider is allowed to share out (see
    // `external-files-path` in its filepaths.xml). From a path it cannot
    // share, the installer would open on nothing.
    final base = await getExternalStorageDirectory() ??
        await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/updates');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Each APK is tens of megabytes and no old one is ever useful again, so
  /// keep exactly the one just downloaded.
  Future<void> _purgeOtherBuilds(Directory dir, {required String keep}) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path != keep) await entity.delete();
      }
    } catch (e) {
      debugPrint('update cache purge failed: $e');
    }
  }
}

/* ── State ──────────────────────────────────────────────────── */

enum UpdateStage {
  /// Nothing checked yet this session.
  idle,
  checking,
  upToDate,
  available,
  downloading,

  /// APK on disk, waiting for the user to tap Install.
  ready,
  failed,
}

@immutable
class UpdateState {
  const UpdateState({
    this.stage = UpdateStage.idle,
    this.release,
    this.installedBuild = 0,
    this.received = 0,
    this.total = 0,
    this.apkPath,
    this.error,
  });

  final UpdateStage stage;
  final AppRelease? release;
  final int installedBuild;
  final int received;
  final int total;
  final String? apkPath;
  final String? error;

  /// Null while the total is still unknown — the sheet then shows an
  /// indeterminate bar rather than one frozen at zero.
  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  bool get busy =>
      stage == UpdateStage.checking || stage == UpdateStage.downloading;

  /// A build the user is not allowed to stay on.
  bool get mandatory =>
      release != null && installedBuild < release!.minBuildNumber;

  UpdateState copyWith({
    UpdateStage? stage,
    AppRelease? release,
    int? installedBuild,
    int? received,
    int? total,
    String? apkPath,
    String? error,
    bool clearRelease = false,
    bool clearError = false,
  }) {
    return UpdateState(
      stage: stage ?? this.stage,
      release: clearRelease ? null : (release ?? this.release),
      installedBuild: installedBuild ?? this.installedBuild,
      received: received ?? this.received,
      total: total ?? this.total,
      apkPath: apkPath ?? this.apkPath,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/* ── Controller ─────────────────────────────────────────────── */

/// Drives check → download → install and holds the state the sheet renders.
/// One per app: `app.dart` kicks it on launch and on resume, Settings kicks
/// it on demand.
class UpdateController extends StateNotifier<UpdateState> {
  UpdateController(this._repo) : super(const UpdateState());

  final UpdateRepository _repo;

  static const _kSkippedBuild = 'update_skipped_build';

  /// How stale an automatic check may be before the next resume redoes it.
  /// Manual checks from Settings ignore this entirely.
  static const _autoInterval = Duration(hours: 3);

  DateTime? _lastAutoCheck;

  Future<void> check({bool manual = false}) async {
    if (!UpdateRepository.supported || state.busy) return;

    // Never re-offer an APK that is already on disk waiting to be tapped.
    if (state.stage == UpdateStage.ready) return;

    if (!manual) {
      final last = _lastAutoCheck;
      if (last != null && DateTime.now().difference(last) < _autoInterval) {
        return;
      }
    }

    state = state.copyWith(stage: UpdateStage.checking, clearError: true);
    try {
      final installed = await _repo.installedBuild();
      final release = await _repo.fetchLatest();
      _lastAutoCheck = DateTime.now();
      if (!mounted) return;

      if (release == null || release.buildNumber <= installed) {
        state = state.copyWith(
          stage: UpdateStage.upToDate,
          installedBuild: installed,
          clearRelease: true,
        );
        return;
      }

      // "Not now" silences one specific build, not updates in general — the
      // next publish gets a fresh chance to interrupt. A mandatory build
      // ignores the skip, and so does asking from Settings.
      final mandatory = installed < release.minBuildNumber;
      if (!manual && !mandatory && await _isSkipped(release.buildNumber)) {
        if (!mounted) return;
        state = state.copyWith(
          stage: UpdateStage.upToDate,
          installedBuild: installed,
          clearRelease: true,
        );
        return;
      }

      state = state.copyWith(
        stage: UpdateStage.available,
        release: release,
        installedBuild: installed,
        received: 0,
        total: release.sizeBytes,
      );
    } catch (e) {
      debugPrint('update check failed: $e');
      if (!mounted) return;
      state = state.copyWith(
        stage: UpdateStage.failed,
        error: 'Could not reach the update server.',
      );
    }
  }

  Future<void> download() async {
    final release = state.release;
    if (release == null || state.busy) return;

    state = state.copyWith(
      stage: UpdateStage.downloading,
      received: 0,
      total: release.sizeBytes,
      clearError: true,
    );
    try {
      final file = await _repo.download(
        release,
        onProgress: (received, total) {
          // The notifier outlives the sheet, and a write after dispose throws.
          if (!mounted) return;
          state = state.copyWith(received: received, total: total);
        },
      );
      if (!mounted) return;
      state = state.copyWith(stage: UpdateStage.ready, apkPath: file.path);
    } catch (e) {
      debugPrint('update download failed: $e');
      if (!mounted) return;
      state = state.copyWith(
        stage: UpdateStage.failed,
        error: 'Download failed. Check your connection and try again.',
      );
    }
  }

  Future<void> install() async {
    final path = state.apkPath;
    if (path == null) return;
    try {
      await _repo.install(File(path));
    } catch (e) {
      debugPrint('update install failed: $e');
      if (!mounted) return;
      state = state.copyWith(
        stage: UpdateStage.failed,
        error: 'Android would not open the installer. Allow '
            '"Install unknown apps" for Dayflower, then try again.',
      );
    }
  }

  /// Hide this build until the next one is published.
  Future<void> skip() async {
    final release = state.release;
    if (release == null || state.mandatory) return;
    state = state.copyWith(stage: UpdateStage.upToDate, clearRelease: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kSkippedBuild, release.buildNumber);
    } catch (e) {
      debugPrint('update skip save failed: $e');
    }
  }

  /// Back to a stage the sheet can retry from.
  void reset() => state = state.copyWith(
        stage: state.release == null ? UpdateStage.idle : UpdateStage.available,
        received: 0,
        clearError: true,
      );

  Future<bool> _isSkipped(int buildNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_kSkippedBuild) == buildNumber;
    } catch (e) {
      debugPrint('update skip read failed: $e');
      return false;
    }
  }
}

final updateRepositoryProvider =
    Provider<UpdateRepository>((ref) => const UpdateRepository());

final updateControllerProvider =
    StateNotifierProvider<UpdateController, UpdateState>(
  (ref) => UpdateController(ref.watch(updateRepositoryProvider)),
);

/// "1.0.0 (7)" — the real installed build, for the Settings version row.
/// Hardcoding it in [AppConstants] is what lets it drift from the APK; once
/// the build number decides whether an update exists, it has to be read from
/// the package itself.
final installedVersionProvider = FutureProvider<String>((ref) async {
  if (kIsWeb) return AppConstants.appVersion;
  return ref.watch(updateRepositoryProvider).installedVersion();
});

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dayflower/features/updates/data/apk_patch.dart';
import 'package:dayflower/features/updates/data/app_release.dart';
import 'package:dayflower/features/updates/data/update_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// An update downloads a patch when there is one for this phone's build,
/// and the whole APK otherwise, or whenever the patch does not work out.
/// Against a real HTTP server standing in for the bucket.
void main() {
  late Directory dir;
  late HttpServer server;
  final served = <String, List<int>>{};
  final asked = <String>[];

  Uint8List build(int seed, {int extra = 0}) {
    final r = Random(seed);
    final motif = List.generate(64, (_) => r.nextInt(256));
    return Uint8List.fromList([
      for (var i = 0; i < 200000; i++)
        motif[i % 64] ^ (r.nextInt(50) == 0 ? r.nextInt(256) : 0),
      for (var i = 0; i < extra; i++) r.nextInt(256),
    ]);
  }

  final oldApk = build(1);
  // The next build: much the same, a little new.
  final newApk = Uint8List.fromList(
      [...oldApk.sublist(0, 120000), ...build(2, extra: 3000).sublist(0, 4000),
       ...oldApk.sublist(120000)]);
  final patch = ApkPatch.create(oldApk, newApk);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('update_patch_');
    served
      ..clear()
      ..['dayflower-6.apk'] = newApk
      ..['dayflower-5-to-6.patch'] = patch;
    asked.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final name = req.uri.pathSegments.last;
      asked.add(name);
      final body = served[name];
      if (body == null) {
        req.response.statusCode = 404;
      } else {
        req.response.contentLength = body.length;
        req.response.add(body);
      }
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    dir.deleteSync(recursive: true);
  });

  AppRelease release({Map<int, AppPatch>? patches}) => AppRelease(
        buildNumber: 6,
        versionName: '1.0.0',
        fileName: 'dayflower-6.apk',
        sizeBytes: newApk.length,
        notes: const [],
        minBuildNumber: 0,
        sha256: sha256.convert(newApk).toString(),
        patches: patches ??
            {
              5: AppPatch(
                  fileName: 'dayflower-5-to-6.patch', sizeBytes: patch.length),
            },
      );

  UpdateRepository repo({bool knowsItsApk = true}) {
    final installed = File('${dir.path}/installed.apk')
      ..writeAsBytesSync(oldApk);
    final downloads = Directory('${dir.path}/updates')..createSync();
    return UpdateRepository(
      bucketBase: Uri.parse('http://127.0.0.1:${server.port}/bucket/'),
      downloadDir: () async => downloads,
      installedApk: () async => knowsItsApk ? installed.path : null,
    );
  }

  Future<(Uint8List, int)> download(UpdateRepository r, AppRelease rel,
      {int from = 5}) async {
    var total = 0;
    final file = await r.download(rel,
        installedBuild: from, onProgress: (_, t) => total = t);
    return (file.readAsBytesSync(), total);
  }

  test('a phone on the build a patch is from downloads only the patch',
      () async {
    final (apk, total) = await download(repo(), release());
    expect(apk, newApk, reason: 'the new build, exactly');
    expect(asked, ['dayflower-5-to-6.patch'], reason: 'not the whole APK');
    expect(total, patch.length);
    expect(patch.length, lessThan(newApk.length ~/ 5));
    // Nothing left behind but the APK itself.
    expect(Directory('${dir.path}/updates').listSync().map((f) => f.uri.pathSegments.last),
        ['dayflower-6.apk']);
  });

  test('a damaged patch falls back to the whole APK', () async {
    served['dayflower-5-to-6.patch'] =
        Uint8List.fromList(patch.toList()..[patch.length - 30] ^= 0xFF);
    final (apk, _) = await download(repo(), release());
    expect(apk, newApk);
    expect(asked, ['dayflower-5-to-6.patch', 'dayflower-6.apk']);
  });

  test('a missing patch falls back to the whole APK', () async {
    served.remove('dayflower-5-to-6.patch');
    final (apk, _) = await download(repo(), release());
    expect(apk, newApk);
    expect(asked.last, 'dayflower-6.apk');
  });

  test('another build, or a phone that cannot find its APK, takes it whole',
      () async {
    final (fromFour, _) = await download(repo(), release(), from: 4);
    expect(fromFour, newApk);
    expect(asked, ['dayflower-6.apk'], reason: 'no patch from build 4');

    asked.clear();
    // A finished download is kept and reused (so an app killed before it
    // installed does not fetch it again): clear it to download afresh.
    Directory('${dir.path}/updates').deleteSync(recursive: true);
    final (lost, _) = await download(repo(knowsItsApk: false), release());
    expect(lost, newApk);
    expect(asked, ['dayflower-6.apk']);
  });

  test('the manifest carries patches, and older manifests carry none', () {
    final rel = AppRelease.fromMap(const {
      'buildNumber': 6,
      'apk': 'dayflower-6.apk',
      'sizeBytes': 50000000,
      'sha256': 'abc',
      'patches': {
        '5': {'object': 'dayflower-5-to-6.patch', 'sizeBytes': 2000000},
        'junk': {'object': 'x'},
      },
    });
    expect(rel.patchFrom(5)?.fileName, 'dayflower-5-to-6.patch');
    expect(rel.downloadBytesFor(5), 2000000);
    expect(rel.downloadBytesFor(4), 50000000);
    expect(rel.readableSizeFor(5), '1.9 MB');

    final old = AppRelease.fromMap(const {
      'buildNumber': 6,
      'apk': 'dayflower-6.apk',
      'sizeBytes': 50000000,
    });
    expect(old.patchFrom(5), isNull);
    expect(old.downloadBytesFor(5), 50000000);
  });
}

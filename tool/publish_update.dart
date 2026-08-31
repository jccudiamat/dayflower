// Publishes a new build to the `app-builds` bucket, which is what makes the
// in-app updater offer it. Run it on the desktop; the phone picks it up on
// its next launch or resume.
//
//   dart run tool/publish_update.dart -n "Fixed the flower picker"
//
// Flags:
//   -n, --note <text>   Release note bullet. Repeat for several.
//   --build <n>         Build number to publish as. Default: current + 1.
//   --min <n>           Oldest build still allowed to keep running. Set this
//                       to <n> to make the update unskippable for anyone
//                       older. Default 0 (everything optional).
//   --abi <name>        Architecture to publish. Default arm64-v8a, which
//                       is every phone made since roughly 2016. Others:
//                       armeabi-v7a (old 32-bit), x86_64 (emulators).
//   --skip-build        Upload the APK already in build/, don't recompile.
//   --dry-run           Do everything except upload.
//
// Credentials come from `.publish.env` (gitignored, and NOT a Flutter asset
// — unlike `.env`, which is bundled into the APK where a service-role key
// would be readable by anyone who unzips it):
//
//   SUPABASE_SERVICE_ROLE_KEY=<the real service_role key>
//
// Two traps when creating it on Windows: paste the actual key rather than
// a placeholder, and do NOT use PowerShell's `>` redirect — Windows
// PowerShell writes UTF-16LE, which this script has to special-case to
// read at all. `cmd /c "echo KEY=value > .publish.env"` writes plain
// ASCII. Both mistakes are caught up front rather than after a build.
//
// The bucket and its read policy come from
// supabase/migrations/0014_app_builds.sql.

import 'dart:convert';
import 'dart:io';

const _bucket = 'app-builds';
/// Supabase's free plan caps a single object at 50 MB and refuses to let a
/// bucket raise its own limit past the plan's, so the 62 MB universal APK
/// simply cannot be published. `--split-per-abi` produces one APK per
/// architecture at roughly half that — which also halves what the phone pulls
/// down on every update, so it is the better build regardless.
const _defaultAbi = 'arm64-v8a';

/// `--split-per-abi` is the obvious way to get under the size limit, and it
/// is a trap: Flutter's Gradle plugin rewrites versionCode for split outputs
/// (`abiIndex * 1000 + versionCode`), so build 2 for arm64 ships as **2002**.
/// The phone then reports 2002 while the manifest says 2, the comparison says
/// "already newer", and the updater goes silent forever — no error, no sheet.
/// `--target-platform` gets the size down without touching versionCode.
///
/// It does not produce a strictly single-ABI APK — plugin JNI libs for the
/// other architectures still ride along — but the Flutter engine and Dart
/// snapshot, 19 of the 24 MB, are built only for the target. The practical
/// consequence: the APK runs on arm64-v8a, and on a 32-bit-only phone it
/// would install and then crash for want of libflutter.so. Publish with
/// `--abi armeabi-v7a` for one of those.
const _targetPlatforms = <String, String>{
  'arm64-v8a': 'android-arm64',
  'armeabi-v7a': 'android-arm',
  'x86_64': 'android-x64',
};

const _apkPath = 'build/app/outputs/flutter-apk/app-release.apk';

Future<void> main(List<String> args) async {
  try {
    await _publish(args);
  } on _PublishError catch (error) {
    stderr.writeln('');
    stderr.writeln('✗ ${error.message}');
    exitCode = 1;
  }
}

Future<void> _publish(List<String> args) async {
  final options = _Options.parse(args);

  final config = _loadConfig();
  final supabaseUrl = config['SUPABASE_URL'];
  final serviceKey = config['SUPABASE_SERVICE_ROLE_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    _fail('SUPABASE_URL not found in .env or .publish.env');
  }
  if (!options.dryRun) {
    final problem = _serviceKeyProblem(serviceKey);
    if (problem != null) {
      _fail(
        '$problem\n\n'
        'Get the real one from Supabase → Project Settings → API → '
        'service_role (Reveal, then copy).\n'
        "Write it WITHOUT PowerShell's > redirect, which writes UTF-16 and "
        'makes this file undecodable:\n'
        '  cmd /c "echo SUPABASE_SERVICE_ROLE_KEY=<paste> > .publish.env"',
      );
    }
  }

  // ── 1. Work out which build number we're publishing ──────────
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    _fail('Run this from the project root — no pubspec.yaml here.');
  }
  final originalPubspec = pubspec.readAsStringSync();
  final version = _Version.parse(originalPubspec);
  final newBuild = options.build ?? version.build + 1;

  if (newBuild <= version.build && !options.skipBuild) {
    _fail(
      'Build $newBuild is not newer than the current ${version.build}. '
      'Phones compare build numbers, so this would never be offered.',
    );
  }

  stdout.writeln('Publishing ${version.name}+$newBuild '
      '(was ${version.name}+${version.build})');

  // ── 2. Stamp it into pubspec and compile ─────────────────────
  var pubspecStamped = false;
  try {
    if (!options.skipBuild) {
      pubspec.writeAsStringSync(
        version.replacedWith(originalPubspec, build: newBuild),
      );
      pubspecStamped = true;

      stdout.writeln('');
      stdout.writeln('→ flutter build apk --release '
          '--target-platform=${_targetPlatforms[options.abi]}');
      final exitCode = await _run('flutter', [
        'build',
        'apk',
        '--release',
        '--target-platform=${_targetPlatforms[options.abi]}',
        '--build-number=$newBuild',
        '--build-name=${version.name}',
      ]);
      if (exitCode != 0) {
        _fail('flutter build failed (exit $exitCode).');
      }
    }

    final apk = File(_apkPath);
    if (!apk.existsSync()) {
      _fail('No APK at ${apk.path} — drop --skip-build and let it compile, '
          'or pick a different --abi.');
    }
    final bytes = apk.lengthSync();
    final objectName = 'dayflower-$newBuild-${options.abi}.apk';

    final manifest = <String, Object?>{
      'buildNumber': newBuild,
      'versionName': version.name,
      'apk': objectName,
      'sizeBytes': bytes,
      'abi': options.abi,
      'notes': options.notes,
      'minBuildNumber': options.minBuild,
      'publishedAt': DateTime.now().toUtc().toIso8601String(),
    };

    // Fail here rather than after pushing 50 MB up the wire. Supabase's free
    // plan rejects a larger object with a 413, and refuses to let the bucket
    // raise its own ceiling past the plan's.
    const uploadCeiling = 50 * 1024 * 1024;
    if (bytes > uploadCeiling) {
      _fail(
        '${apk.path} is ${_mb(bytes)}, over the 50 MB Supabase Storage limit.'
        ' Publish a per-architecture APK instead of a universal one, or move'
        ' the project off the free plan.',
      );
    }

    if (options.dryRun) {
      stdout.writeln('\n--dry-run — would upload:');
      stdout.writeln('  $objectName  (${_mb(bytes)})');
      stdout.writeln('  latest.json  ${jsonEncode(manifest)}');
      return;
    }

    // ── 3. Upload. APK first: a manifest pointing at an object that
    // isn't there yet would send every phone to a 404. ───────────
    stdout.writeln('\n→ uploading $objectName (${_mb(bytes)})');
    await _upload(
      supabaseUrl: supabaseUrl,
      serviceKey: serviceKey!,
      object: objectName,
      body: apk.openRead(),
      length: bytes,
      contentType: 'application/vnd.android.package-archive',
      // APKs are immutable — the name carries the build number — so let the
      // CDN hold them for a day.
      cacheControl: '86400',
    );

    stdout.writeln('→ uploading latest.json');
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    await _upload(
      supabaseUrl: supabaseUrl,
      serviceKey: serviceKey,
      object: 'latest.json',
      body: Stream.value(manifestBytes),
      length: manifestBytes.length,
      contentType: 'application/json',
      // This one changes every publish and is the whole signal, so no CDN
      // caching at all. The app also cache-busts with a query param.
      cacheControl: '0',
    );

    stdout.writeln(
      '\n✓ Published build $newBuild.\n'
      '  Phones on an older build will be offered it on their next launch\n'
      '  or resume, or immediately via Settings → Check for updates.',
    );
    pubspecStamped = false; // keep the bump, it's now the published truth
  } finally {
    // A half-finished publish must not leave pubspec claiming a build number
    // that was never uploaded — the next run would skip straight past it.
    if (pubspecStamped) {
      pubspec.writeAsStringSync(originalPubspec);
      stdout.writeln('Restored pubspec.yaml to +${version.build}.');
    }
  }
}

/* ── Upload ──────────────────────────────────────────────────── */

Future<void> _upload({
  required String supabaseUrl,
  required String serviceKey,
  required String object,
  required Stream<List<int>> body,
  required int length,
  required String contentType,
  required String cacheControl,
}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse(
      '${supabaseUrl.replaceAll(RegExp(r'/+$'), '')}'
      '/storage/v1/object/$_bucket/$object',
    );
    final request = await client.postUrl(uri);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $serviceKey')
      ..set('apikey', serviceKey)
      ..set(HttpHeaders.contentTypeHeader, contentType)
      ..set(HttpHeaders.cacheControlHeader, 'max-age=$cacheControl')
      // Republishing the same build number overwrites rather than 409s.
      ..set('x-upsert', 'true');
    request.contentLength = length;

    var sent = 0;
    await request.addStream(body.map((chunk) {
      sent += chunk.length;
      if (length > 1024 * 1024) {
        stdout.write('\r  ${(sent / length * 100).toStringAsFixed(0)}%   ');
      }
      return chunk;
    }));
    if (length > 1024 * 1024) stdout.writeln();

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 300) {
      if (response.statusCode == 404) {
        _fail(
          'Bucket "$_bucket" does not exist. Run '
          'supabase/migrations/0014_app_builds.sql in the SQL editor first.',
        );
      }
      _fail('Upload of $object failed (${response.statusCode}): $text');
    }
  } finally {
    client.close(force: true);
  }
}

/* ── Config, args, pubspec ───────────────────────────────────── */

/// `.env` supplies the project URL (it's already there and isn't secret);
/// `.publish.env` supplies the service-role key and wins on any overlap.
Map<String, String> _loadConfig() {
  final merged = <String, String>{};
  for (final name in ['.env', '.publish.env']) {
    final file = File(name);
    if (!file.existsSync()) continue;
    for (final line in LineSplitter.split(_readTextFile(file))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final split = trimmed.indexOf('=');
      if (split <= 0) continue;
      merged[trimmed.substring(0, split).trim()] =
          trimmed.substring(split + 1).trim();
    }
  }
  return merged;
}

/// Catches the two ways this goes wrong, before a three-minute APK build and
/// a 60 MB upload discover it for us: no key at all, and the placeholder from
/// this file's header pasted verbatim — `eyJ...` is six characters and reads
/// like a real key at a glance.
///
/// Shape-only on purpose. Supabase has issued both JWTs (`eyJ...`, three
/// dot-separated segments) and `sb_secret_...` keys, so anything long enough
/// to plausibly be real is passed through and left for the server to judge.
/// The floor is 24 rather than 40 because a real `sb_secret_` key measured
/// only 41 characters — 40 left a single character of margin, and rejecting
/// a valid key is a worse failure here than accepting a bad one.
String? _serviceKeyProblem(String? key) {
  if (key == null || key.isEmpty) {
    return 'SUPABASE_SERVICE_ROLE_KEY not found in .publish.env.';
  }
  if (key.endsWith('...') || key.length < 24) {
    return 'SUPABASE_SERVICE_ROLE_KEY in .publish.env is a placeholder, not a '
        'key (only ${key.length} characters).';
  }
  return null;
}

/// Reads a config file whatever encoding it landed in.
///
/// `echo KEY=value > .publish.env` in Windows PowerShell writes **UTF-16LE
/// with a BOM**, which is how this file tends to get created — and
/// `readAsLinesSync` throws outright on it. Honour the BOM instead of making
/// that the user's problem. Env files are ASCII in practice, so decoding
/// UTF-16 code units as code points is safe here.
String _readTextFile(File file) {
  final bytes = file.readAsBytesSync();
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16(bytes, littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16(bytes, littleEndian: false);
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3));
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = 2; i + 1 < bytes.length; i += 2) {
    units.add(littleEndian
        ? bytes[i] | (bytes[i + 1] << 8)
        : (bytes[i] << 8) | bytes[i + 1]);
  }
  return String.fromCharCodes(units);
}

class _Options {
  _Options({
    required this.notes,
    required this.build,
    required this.minBuild,
    required this.skipBuild,
    required this.dryRun,
    required this.abi,
  });

  /// Which architecture's APK to publish. Every Android phone made since
  /// roughly 2016 is arm64-v8a; the others exist for old hardware and
  /// emulators. An APK for the wrong one is refused at install time with
  /// INSTALL_FAILED_NO_MATCHING_ABIS.
  final String abi;

  final List<String> notes;
  final int? build;
  final int minBuild;
  final bool skipBuild;
  final bool dryRun;

  static _Options parse(List<String> args) {
    final notes = <String>[];
    int? build;
    var minBuild = 0;
    var skipBuild = false;
    var dryRun = false;
    var abi = _defaultAbi;

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '-n':
        case '--note':
          if (++i >= args.length) _fail('--note needs some text after it.');
          notes.add(args[i]);
        case '--build':
          if (++i >= args.length) _fail('--build needs a number after it.');
          build = int.tryParse(args[i]) ?? _fail('--build must be a number.');
        case '--min':
          if (++i >= args.length) _fail('--min needs a number after it.');
          minBuild = int.tryParse(args[i]) ?? _fail('--min must be a number.');
        case '--abi':
          if (++i >= args.length) _fail('--abi needs an architecture after it.');
          abi = args[i];
          if (!_targetPlatforms.containsKey(abi)) {
            _fail('Unknown --abi "$abi". '
                'One of: ${_targetPlatforms.keys.join(", ")}.');
          }
        case '--skip-build':
          skipBuild = true;
        case '--dry-run':
          dryRun = true;
        default:
          _fail('Unknown flag "${args[i]}". See the header of this file.');
      }
    }

    return _Options(
      notes: notes,
      build: build,
      minBuild: minBuild,
      skipBuild: skipBuild,
      dryRun: dryRun,
      abi: abi,
    );
  }
}

/// The `version: 1.0.0+1` line, split into its two halves.
class _Version {
  _Version(this.name, this.build);

  final String name;
  final int build;

  static final _pattern =
      RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$',
          multiLine: true);

  static _Version parse(String pubspec) {
    final match = _pattern.firstMatch(pubspec);
    if (match == null) {
      _fail('Could not find a "version: x.y.z+n" line in pubspec.yaml.');
    }
    return _Version(match.group(1)!, int.parse(match.group(2)!));
  }

  String replacedWith(String pubspec, {required int build}) =>
      pubspec.replaceFirst(_pattern, 'version: $name+$build');
}

Future<int> _run(String executable, List<String> args) async {
  final process = await Process.start(
    executable,
    args,
    // `flutter` is a .bat on Windows, which Process.start won't find without
    // a shell.
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

class _PublishError implements Exception {
  _PublishError(this.message);
  final String message;
}

/// Throws rather than calling `exit`. `exit` terminates the VM immediately
/// without unwinding, so the `finally` that restores pubspec.yaml never ran —
/// a failed publish left the version bumped for a build nobody ever received,
/// and the next run then computed its build number from that phantom.
Never _fail(String message) => throw _PublishError(message);

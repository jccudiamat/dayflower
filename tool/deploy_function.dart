// Deploys an edge function, the way `supabase functions deploy` would.
//
//   dart run tool/deploy_function.dart push
//   dart run tool/deploy_function.dart push --dry-run
//   dart run tool/deploy_function.dart push --verify-jwt
//
// ── Why this exists ─────────────────────────────────────────────────
// There is no Supabase CLI on this machine and `supabase/functions/push`
// is production infrastructure — every call, every message and now every
// heartbeat is announced through it. Editing the file without a way to ship
// it means the repo and the running function drift silently, which is worse
// than having no function at all: the source stops being evidence of what
// is deployed.
//
// So this posts the same multipart body the CLI does, to the Management API:
//
//   POST /v1/projects/{ref}/functions/deploy?slug={slug}
//     metadata = {"entrypoint_path": "index.ts", "name": ..., "verify_jwt": ...}
//     file     = the source
//
// ── Credentials ─────────────────────────────────────────────────────
// The same **Personal Access Token** `run_sql.dart` uses, from
// `.publish.env` (gitignored, and NOT a Flutter asset):
//
//   SUPABASE_ACCESS_TOKEN=sbp_...
//
// ⚠️ A PAT controls **every project in the account**, not just this one.
// Worth deleting from https://supabase.com/dashboard/account/tokens once
// you are done — this script will simply stop working, which is correct.
//
// ⚠️ `verify_jwt` defaults to **false**, matching how `push` is deployed:
// its caller is a Postgres trigger, which has no user JWT to present. It
// authenticates on the `x-push-secret` header instead (see 0031). Passing
// --verify-jwt on `push` would take production push down, so the default
// here is the value it already has rather than the safer-sounding one.
//
// The project ref comes from SUPABASE_URL in .env, like run_sql.dart.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _api = 'https://api.supabase.com';

Future<void> main(List<String> args) async {
  final slug = args.where((a) => !a.startsWith('-')).firstOrNull;
  if (slug == null) {
    stderr.writeln('usage: dart run tool/deploy_function.dart <slug> '
        '[--dry-run] [--verify-jwt]');
    exitCode = 64;
    return;
  }

  final dryRun = args.contains('--dry-run');
  final verifyJwt = args.contains('--verify-jwt');

  final root = Directory.current;
  final source = File('${root.path}/supabase/functions/$slug/index.ts');
  if (!source.existsSync()) {
    _fail('No such function: ${source.path}');
  }

  final token = _env('.publish.env')['SUPABASE_ACCESS_TOKEN'];
  if (token == null || !token.startsWith('sbp_')) {
    _fail('SUPABASE_ACCESS_TOKEN missing from .publish.env, or not a PAT.\n'
        '  It must be a Personal Access Token (sbp_...), not the service '
        'role key — the\n  Management API answers that with "JWT could not '
        'be decoded".');
  }

  final url = _env('.env')['SUPABASE_URL'];
  if (url == null) _fail('SUPABASE_URL missing from .env');
  final ref = RegExp(r'https://([a-z0-9]+)\.supabase\.co')
      .firstMatch(url)
      ?.group(1);
  if (ref == null) _fail('Could not read a project ref out of $url');

  final bytes = source.readAsBytesSync();
  stdout.writeln('→ $slug  (${bytes.length} bytes) → project $ref'
      '${verifyJwt ? '  verify_jwt' : ''}');

  if (dryRun) {
    stdout.writeln('✓ Dry run. Nothing was deployed.');
    return;
  }

  // Multipart by hand: one JSON part naming the entrypoint, one file part.
  // `http` is not a dependency of this repo and a 40-line builder is a
  // smaller thing to own than a package the app does not otherwise need.
  final boundary = 'dayflower${DateTime.now().microsecondsSinceEpoch}';
  final metadata = jsonEncode({
    'entrypoint_path': 'index.ts',
    'name': slug,
    'verify_jwt': verifyJwt,
  });

  final body = <int>[
    ...utf8.encode('--$boundary\r\n'
        'Content-Disposition: form-data; name="metadata"\r\n'
        'Content-Type: application/json\r\n\r\n$metadata\r\n'
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="index.ts"\r\n'
        'Content-Type: application/typescript\r\n\r\n'),
    ...bytes,
    ...utf8.encode('\r\n--$boundary--\r\n'),
  ];

  final client = HttpClient();
  try {
    final request = await client
        .postUrl(Uri.parse('$_api/v1/projects/$ref/functions/deploy?slug=$slug'));
    request.headers.set('Authorization', 'Bearer $token');
    request.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');
    request.add(body);

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 300) {
      _fail('Deploy failed: HTTP ${response.statusCode}\n  $text');
    }

    final json = jsonDecode(text) as Map<String, dynamic>;
    stdout.writeln('✓ Deployed $slug, now version ${json['version']} '
        '(${json['status']}).');
    // ⚠️ Live the moment this returns. There is no staging step and no
    // gradual rollout — the next trigger that fires hits the new code.
    stdout.writeln('  It is live. The next trigger to fire runs it.');
  } finally {
    client.close();
  }
}

/// Reads a `KEY=value` file. Tolerates the UTF-16LE that PowerShell's `>`
/// redirect writes, for the same reason run_sql.dart does.
Map<String, String> _env(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  Uint8List bytes = file.readAsBytesSync();
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    bytes = Uint8List.fromList([
      for (var i = 2; i < bytes.length; i += 2) bytes[i],
    ]);
  }
  final out = <String, String>{};
  for (final line in utf8.decode(bytes, allowMalformed: true).split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final at = trimmed.indexOf('=');
    if (at <= 0) continue;
    out[trimmed.substring(0, at).trim()] =
        trimmed.substring(at + 1).trim().replaceAll('\r', '');
  }
  return out;
}

Never _fail(String message) {
  stderr.writeln('');
  stderr.writeln('✗ $message');
  exit(1);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// Runs SQL against the Supabase project, the way the dashboard's SQL editor
// does — POST /v1/projects/{ref}/database/query on the Management API.
//
//   dart run tool/run_sql.dart supabase/migrations/0015_finance_v2.sql
//   dart run tool/run_sql.dart -c "select count(*) from finance_accounts;"
//   dart run tool/run_sql.dart --dry-run <file>   Print what would be sent.
//
// ── Credentials ─────────────────────────────────────────────────────
// Needs a **Personal Access Token**, not the service_role key. The two are
// not interchangeable: service_role speaks to PostgREST and Storage and has
// no way to run DDL, which is why this endpoint answers it with
// "JWT could not be decoded".
//
// Create one at https://supabase.com/dashboard/account/tokens and add it to
// `.publish.env` (gitignored, and NOT a Flutter asset):
//
//   SUPABASE_ACCESS_TOKEN=sbp_...
//
// ⚠️ A PAT is broader than the service_role key: it controls **every
// project in the account**, not just this one. Worth deleting from that page
// once the migrations are in — this script will simply stop working, which
// is the correct failure.
//
// The project ref is read from SUPABASE_URL in .env; nothing else here needs
// the app's own keys.

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  try {
    await _run(args);
  } on _SqlError catch (error) {
    stderr.writeln('');
    stderr.writeln('✗ ${error.message}');
    exitCode = 1;
  }
}

Future<void> _run(List<String> args) async {
  var dryRun = false;
  String? inline;
  String? path;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--dry-run':
        dryRun = true;
      case '-c':
      case '--command':
        if (++i >= args.length) _fail('-c needs SQL after it.');
        inline = args[i];
      default:
        path = args[i];
    }
  }

  final sql = inline ?? (path == null ? null : _readSqlFile(path));
  if (sql == null || sql.trim().isEmpty) {
    _fail('Nothing to run. Pass a .sql file path, or -c "select 1;".');
  }

  final config = _loadConfig();
  final token = config['SUPABASE_ACCESS_TOKEN'];
  if (token == null || token.isEmpty || !token.startsWith('sbp_')) {
    _fail(
      'SUPABASE_ACCESS_TOKEN missing from .publish.env, or not a personal '
      'access token (they start with "sbp_").\n\n'
      'The service_role key does NOT work here — it has no way to run DDL.\n'
      'Create one at https://supabase.com/dashboard/account/tokens, then:\n'
      '  notepad .publish.env\n'
      '  SUPABASE_ACCESS_TOKEN=sbp_...',
    );
  }

  final url = config['SUPABASE_URL'];
  if (url == null || url.isEmpty) _fail('SUPABASE_URL not found in .env.');
  final ref = RegExp(r'https://([a-z0-9]+)\.supabase\.co')
      .firstMatch(url)
      ?.group(1);
  if (ref == null) _fail('Could not read the project ref out of "$url".');

  final label = inline != null ? 'inline SQL' : path!;
  stdout.writeln('→ $label  (${sql.length} chars) → project $ref');

  if (dryRun) {
    stdout.writeln('\n--dry-run — not sent.');
    return;
  }

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    final request = await client.postUrl(
      Uri.parse('https://api.supabase.com/v1/projects/$ref/database/query'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode({'query': sql})));

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200 && response.statusCode != 201) {
      _fail('Supabase returned ${response.statusCode}:\n$body');
    }

    // A successful DDL batch comes back as an empty array; a select comes
    // back as rows. Printing both keeps this usable for checks as well as
    // migrations.
    final decoded = jsonDecode(body);
    if (decoded is List && decoded.isEmpty) {
      stdout.writeln('\n✓ Ran clean. No rows returned.');
    } else {
      stdout.writeln('\n✓ Ran clean.');
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(decoded));
    }
  } finally {
    client.close(force: true);
  }
}

String _readSqlFile(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('No file at $path');
  return _readTextFile(file);
}

/// Reads .env and .publish.env, later files winning.
Map<String, String> _loadConfig() {
  final merged = <String, String>{};
  for (final name in const ['.env', '.publish.env']) {
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

/// Honours a BOM. PowerShell's `>` redirect writes UTF-16LE, which plain
/// UTF-8 decoding throws on outright — the same trap `.publish.env` fell
/// into the first time it was created.
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

class _SqlError implements Exception {
  _SqlError(this.message);
  final String message;
}

Never _fail(String message) => throw _SqlError(message);

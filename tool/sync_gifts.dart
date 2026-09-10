// Pushes a gift catalogue into `gift_products`.
//
//   dart run tool/sync_gifts.dart --from-app     Seed from the bundled list.
//   dart run tool/sync_gifts.dart gifts.json     Push a JSON file.
//   dart run tool/sync_gifts.dart --dump         Print the live table as JSON.
//   dart run tool/sync_gifts.dart --dry-run ...  Show what would be sent.
//
// ⚠️ **Upsert, never delete.** A product missing from the file is left alone,
// not removed: this is a bulk editor, and a truncate-and-replace turns one
// forgotten line into a catalogue that silently lost half its listings. Retire
// a product by setting `"active": false`, which keeps its click history.
//
// The JSON is a list of objects with the table's own column names:
//
//   [{"id": "crochet-bouquet", "url": "https://...", "price": 116}]
//
// Only the keys present are written, so a file of `{"id": ..., "url": ...}`
// pairs is a perfectly good way to update ten affiliate links at once.
//
// ── Credentials ─────────────────────────────────────────────────────
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY from `.publish.env` — writes are
// deliberately closed to everyone else, including the app. See migration 0038.
import 'dart:convert';
import 'dart:io';

const _table = 'gift_products';

/// Columns this tool is allowed to write. Anything else in the JSON is a
/// typo, and saying so beats writing a column that silently does nothing.
const _columns = {
  'id', 'name', 'merchant', 'category', 'price', 'price_max', 'voucher',
  'recipients', 'url', 'image_url', 'image_source', 'sort', 'active',
};

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final rest = args.where((a) => a != '--dry-run').toList();

  final env = _readEnv();
  final url = env['SUPABASE_URL'];
  final key = env['SUPABASE_SERVICE_ROLE_KEY'];
  if (url == null || key == null) {
    _fail('Need SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .publish.env');
  }
  // _fail returns Never, so both are non-null past here — but the analyser
  // only knows that if it is said.

  if (rest.contains('--dump')) {
    await _dump(url, key);
    return;
  }

  final List<Map<String, dynamic>> rows;
  if (rest.contains('--from-app')) {
    rows = _fromBundledCatalog();
    stdout.writeln('Read ${rows.length} products from gift_catalog.dart');
  } else if (rest.isNotEmpty) {
    final file = File(rest.first);
    if (!file.existsSync()) _fail('No such file: ${rest.first}');
    final parsed = jsonDecode(file.readAsStringSync());
    if (parsed is! List) _fail('Expected a JSON list of products.');
    rows = parsed.cast<Map<String, dynamic>>();
    stdout.writeln('Read ${rows.length} products from ${rest.first}');
  } else {
    _fail('Give it --from-app, --dump, or a JSON file. See the header.');
  }

  for (final row in rows) {
    if (row['id'] == null) _fail('Every product needs an "id". Got: $row');
    final unknown = row.keys.toSet().difference(_columns);
    if (unknown.isNotEmpty) {
      _fail('Unknown column(s) on ${row['id']}: ${unknown.join(', ')}\n'
          'Allowed: ${_columns.join(', ')}');
    }
  }

  if (dryRun) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(rows));
    stdout.writeln('\n--dry-run: nothing sent.');
    return;
  }

  final client = HttpClient();
  final req = await client.postUrl(
      Uri.parse('$url/rest/v1/$_table?on_conflict=id'));
  req.headers
    ..set('apikey', key)
    ..set('Authorization', 'Bearer $key')
    ..set('Content-Type', 'application/json')
    // merge-duplicates is the upsert; without it a re-run is a 409 on every
    // row that already exists.
    ..set('Prefer', 'resolution=merge-duplicates,return=representation');
  req.add(utf8.encode(jsonEncode(rows)));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  client.close();

  if (res.statusCode >= 300) {
    _fail('Supabase returned ${res.statusCode}:\n$body');
  }
  final written = (jsonDecode(body) as List).length;
  stdout.writeln('✓ Wrote $written products.');
  stdout.writeln('  The app picks them up on its next open — no build needed.');
}

Future<void> _dump(String url, String key) async {
  final client = HttpClient();
  final req = await client
      .getUrl(Uri.parse('$url/rest/v1/$_table?select=*&order=sort,name'));
  req.headers
    ..set('apikey', key)
    ..set('Authorization', 'Bearer $key');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  client.close();
  if (res.statusCode >= 300) _fail('Supabase returned ${res.statusCode}:\n$body');
  final rows = (jsonDecode(body) as List)
      .map((r) => Map<String, dynamic>.from(r as Map)..remove('updated_at'))
      .toList();
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(rows));
}

/// Scrapes the bundled `const giftProducts` list.
///
/// ⚠️ Parsed out of the Dart source rather than imported, because importing it
/// pulls in Flutter and this is a plain `dart run` script. It only has to work
/// once — after the seed, the table is the source of truth and this path is a
/// way to re-seed a fresh project.
List<Map<String, dynamic>> _fromBundledCatalog() {
  final src = File('lib/features/gifts/data/gift_catalog.dart');
  if (!src.existsSync()) _fail('Run this from the project root.');
  final text = src.readAsStringSync();
  final start = text.indexOf('const giftProducts = <GiftProduct>[');
  if (start < 0) _fail('Could not find `const giftProducts` in the catalogue.');

  final rows = <Map<String, dynamic>>[];
  var sort = 0;
  for (final block in text.substring(start).split('GiftProduct(').skip(1)) {
    String? str(String field) =>
        RegExp('$field:\\s*(?:"((?:[^"\\\\]|\\\\.)*)"|\'((?:[^\'\\\\]|\\\\.)*)\')')
            .firstMatch(block)
            ?.let((m) => m.group(1) ?? m.group(2))
            ?.replaceAll(r"\'", "'")
            .replaceAll(r'\"', '"');
    int? num_(String field) => int.tryParse(
        RegExp('$field:\\s*(\\d+)').firstMatch(block)?.group(1) ?? '');

    final id = str('id');
    if (id == null) continue;
    final recipients = RegExp(r'recipients:\s*\[([^\]]*)\]')
            .firstMatch(block)
            ?.group(1)
            ?.split(',')
            .map((s) => s.trim().replaceAll(RegExp('''^["']|["']\$'''), ''))
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    rows.add({
      'id': id,
      'name': str('name'),
      'merchant': str('merchant'),
      'category': str('category'),
      'price': num_('price') ?? 0,
      // ⚠️ Always present, null when there is no range. PostgREST rejects a
      // bulk insert whose objects do not all carry the same keys —
      // "All object keys must match", which does not obviously mean this.
      'price_max': num_('priceMax'),
      'voucher': block.contains('voucher: true'),
      'recipients': recipients,
      'url': str('url'),
      'image_source': str('imageSource'),
      'sort': sort++,
      'active': true,
    });
  }
  if (rows.isEmpty) _fail('Parsed no products — has the catalogue changed shape?');
  return rows;
}

Map<String, String> _readEnv() {
  final out = <String, String>{};
  for (final name in ['.publish.env', '.env']) {
    final file = File(name);
    if (!file.existsSync()) continue;
    for (final line in file.readAsLinesSync()) {
      final i = line.indexOf('=');
      if (i <= 0 || line.trimLeft().startsWith('#')) continue;
      out.putIfAbsent(
          line.substring(0, i).trim(), () => line.substring(i + 1).trim());
    }
  }
  return out;
}

Never _fail(String message) {
  stderr.writeln('✗ $message');
  exit(1);
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

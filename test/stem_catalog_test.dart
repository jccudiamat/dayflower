import 'dart:io';

import 'package:dayflower/features/tulip/domain/flower_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// The stems in the app are cut from the website's sprite sheets by
/// `tool/slice_stems.py`, and their names come from the website's own list.
/// Two copies of one catalogue drift — that is what copies do — and the
/// failure is quiet: a flower the website offers simply is not in the chat,
/// or an id changes and every message sent with the old one orphans.
///
/// So the app's copy is checked against the source it was generated from.
/// ⚠️ If this fails, the fix is to re-run the generator, never to edit the
/// Dart by hand:
///
///     python tool/slice_stems.py

final _entry = RegExp(r'\{\s*name:\s*"([^"]+)",\s*detail:\s*"([^"]+)"');

List<(String, String)> websiteFlowers() {
  final file = File('website/app/bouquet/model.ts');
  if (!file.existsSync()) return const [];
  final source = file.readAsStringSync();
  final start = source.indexOf('export const flowers = [');
  final end = source.indexOf('] as const;', start);
  return [
    for (final m in _entry.allMatches(source.substring(start, end)))
      (m.group(1)!, m.group(2)!),
  ];
}

String slugFor(String name) => name
    .toLowerCase()
    .replaceAll('’', '')
    .replaceAll(RegExp(r"[^a-z0-9]+"), '_')
    .replaceAll(RegExp(r'_+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

void main() {
  final website = websiteFlowers();
  final stems = FlowerCatalog.all
      .where((f) => f.category == FlowerCategory.stem)
      .toList();

  test('the website list is readable at all', () {
    // Guards the guard. A regex that silently matches nothing would make
    // every check below pass by being empty.
    expect(website.length, greaterThan(6),
        reason: 'model.ts did not parse — the shape of the source changed');
  });

  test('every flower the website offers is sendable in the chat', () {
    // The direction that matters for "available in the chat too": a stem
    // added to the builder and never sliced is invisible here.
    final ids = {for (final f in stems) f.id};
    final missing = [
      for (final (name, _) in website)
        if (!ids.contains('stem_${slugFor(name)}')) name,
    ];
    expect(missing, isEmpty, reason: 'run: python tool/slice_stems.py');
  });

  test('no stem has an id the website no longer backs', () {
    // The other direction: a rename on the website orphans every message
    // already sent under the old id. Retire it, never rename it.
    final ids = {for (final (name, _) in website) 'stem_${slugFor(name)}'};
    expect([for (final f in stems) if (!ids.contains(f.id)) f.id], isEmpty);
  });

  test('names and meanings match the website word for word', () {
    final byId = {for (final f in stems) f.id: f};
    for (final (name, detail) in website) {
      final flower = byId['stem_${slugFor(name)}'];
      if (flower == null) continue; // already reported above
      // Curly apostrophes are straightened on the way into Dart; compare
      // like for like rather than pretending the two strings are identical.
      expect(flower.name, name.replaceAll('’', "'"), reason: name);
      expect(flower.meaning, detail.replaceAll('’', "'"), reason: name);
    }
  });

  test('stems are cut-outs, and nothing else is', () {
    // 🔴 Drives how they are drawn, not just how they look: `cover` on a
    // tall transparent stem crops the bloom clean out of the frame.
    expect(stems.every((f) => f.cutout), isTrue);
    expect(
      FlowerCatalog.all
          .where((f) => f.category != FlowerCategory.stem)
          .every((f) => !f.cutout),
      isTrue,
    );
  });

  test('every stem is offered in the picker', () {
    expect(
      FlowerCatalog.pickable
          .where((f) => f.category == FlowerCategory.stem)
          .length,
      stems.length,
    );
  });
}

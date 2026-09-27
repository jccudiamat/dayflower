import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dayflower/features/updates/data/apk_patch.dart';
import 'package:flutter_test/flutter_test.dart';

/// An update patch rebuilds exactly the new build from the old one, or
/// refuses and leaves nothing behind. Real files: the applier reads and
/// writes them, which is the path a phone takes.
void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('apk_patch_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Uint8List noise(int n, int seed) {
    final r = Random(seed);
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  /// Code-like: long stretches that repeat with a few bytes changed, the
  /// way compiled code shifts its addresses between builds.
  Uint8List codeLike(int n, int seed) {
    final r = Random(seed);
    final out = Uint8List(n);
    final motif = noise(64, seed + 1);
    for (var i = 0; i < n; i++) {
      out[i] = motif[i % 64] ^ (r.nextInt(40) == 0 ? r.nextInt(256) : 0);
    }
    return out;
  }

  Future<(Uint8List, int)> roundTrip(Uint8List old, Uint8List neu) async {
    final patch = ApkPatch.create(old, neu);
    final oldFile = File('${dir.path}/old')..writeAsBytesSync(old);
    final patchFile = File('${dir.path}/patch')..writeAsBytesSync(patch);
    final out = File('${dir.path}/out');
    await ApkPatch.apply(old: oldFile, patch: patchFile, out: out);
    return (out.readAsBytesSync(), patch.length);
  }

  test('the cases an update meets, each rebuilt exactly', () async {
    final base = codeLike(300000, 1);
    Uint8List edit(void Function(List<int> b) change) {
      final b = base.toList();
      change(b);
      return Uint8List.fromList(b);
    }

    final cases = <String, Uint8List>{
      'unchanged': base,
      'a few bytes changed': edit((b) {
        for (var i = 0; i < b.length; i += 997) {
          b[i] ^= 0x5A;
        }
      }),
      'bytes inserted early': edit((b) => b.insertAll(1000, noise(5000, 2))),
      'bytes removed': edit((b) => b.removeRange(50000, 90000)),
      'a new file appended': edit((b) => b.addAll(noise(40000, 3))),
      'halves swapped': Uint8List.fromList(
          [...base.sublist(150000), ...base.sublist(0, 150000)]),
      'nothing in common': noise(120000, 4),
      'empty': Uint8List(0),
      'tiny': Uint8List.fromList([1, 2, 3]),
    };
    for (final MapEntry(key: name, value: neu) in cases.entries) {
      final (rebuilt, size) = await roundTrip(base, neu);
      expect(rebuilt, neu, reason: name);
      if (name == 'unchanged' || name == 'a few bytes changed') {
        expect(size, lessThan(neu.length ~/ 20),
            reason: '$name: a patch is a small fraction of the file');
      }
    }
    // From nothing, too.
    final (fromEmpty, _) = await roundTrip(Uint8List(0), noise(5000, 5));
    expect(fromEmpty, noise(5000, 5));
  });

  test('another build as the old file is refused, and nothing is written',
      () async {
    final old = codeLike(100000, 6);
    final neu = codeLike(100000, 7);
    final patch = File('${dir.path}/patch')
      ..writeAsBytesSync(ApkPatch.create(old, neu));
    final wrong = old.toList()..[500] ^= 1;
    final wrongFile = File('${dir.path}/wrong')
      ..writeAsBytesSync(wrong);
    final out = File('${dir.path}/out');
    await expectLater(
        ApkPatch.apply(old: wrongFile, patch: patch, out: out),
        throwsA(isA<ApkPatchException>()));
    expect(out.existsSync(), isFalse);
  });

  test('a damaged patch is refused, and nothing is written', () async {
    final old = codeLike(100000, 8);
    final neu = Uint8List.fromList(old.toList()..insertAll(3000, noise(900, 9)));
    final bytes = ApkPatch.create(old, neu);
    final oldFile = File('${dir.path}/old')..writeAsBytesSync(old);
    final out = File('${dir.path}/out');
    for (final damage in <String, Uint8List Function()>{
      'cut short': () => Uint8List.sublistView(bytes, 0, bytes.length - 10),
      'a byte flipped': () =>
          Uint8List.fromList(bytes.toList()..[bytes.length - 40] ^= 0xFF),
      'not a patch': () => noise(400, 10),
    }.entries) {
      final patch = File('${dir.path}/patch')
        ..writeAsBytesSync(damage.value());
      await expectLater(
          ApkPatch.apply(old: oldFile, patch: patch, out: out),
          throwsA(anything),
          reason: damage.key);
      expect(out.existsSync(), isFalse, reason: damage.key);
    }
  });
}

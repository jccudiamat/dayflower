// Makes an update patch from one APK to another, and checks it.
//
//   dart run tool/make_patch.dart <old.apk> <new.apk> <out.patch>
//
// tool/publish_update.dart does this for every publish; this is for trying
// it by hand. The patch is applied back to the old APK and the result
// compared with the new one before this reports success.
import 'dart:io';

import 'package:dayflower/features/updates/data/apk_patch.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    stderr.writeln('usage: dart run tool/make_patch.dart <old.apk> <new.apk> <out.patch>');
    exitCode = 64;
    return;
  }
  final old = File(args[0]), neu = File(args[1]), out = File(args[2]);
  final watch = Stopwatch()..start();
  final patch = ApkPatch.create(old.readAsBytesSync(), neu.readAsBytesSync());
  out.writeAsBytesSync(patch);
  final made = watch.elapsed;

  watch.reset();
  final rebuilt = File('${out.path}.check');
  await ApkPatch.apply(old: old, patch: out, out: rebuilt);
  final applied = watch.elapsed;
  final same = rebuilt.readAsBytesSync();
  final want = neu.readAsBytesSync();
  var ok = same.length == want.length;
  for (var i = 0; ok && i < same.length; i++) {
    ok = same[i] == want[i];
  }
  rebuilt.deleteSync();
  if (!ok) {
    stderr.writeln('✗ the patch does not rebuild ${neu.path}');
    exitCode = 1;
    return;
  }
  String mb(int n) => '${(n / 1048576).toStringAsFixed(2)} MB';
  stdout.writeln('✓ ${mb(patch.length)} patch for a ${mb(want.length)} APK '
      '(${(patch.length / want.length * 100).toStringAsFixed(1)}%), '
      'made in ${made.inSeconds}s, applied and checked in '
      '${applied.inMilliseconds} ms');
}

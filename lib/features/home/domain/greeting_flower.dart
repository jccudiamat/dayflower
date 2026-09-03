import 'dart:math';

import '../../tulip/domain/flower_catalog.dart';

/// The flower beside your name in the greeting, chosen once per app launch.
///
/// It used to be a hardcoded 🌷 — correct for the app's name and completely
/// static, which after the twentieth morning is furniture rather than a
/// greeting. A different bloom each time you open the app costs nothing and
/// makes the top of the screen worth looking at again.
///
/// ⚠️ **Once per launch, not once per build.** `_chosen` is a lazily
/// initialised top-level, so the first read picks and every read after
/// returns the same one for the life of the process. Picking inside `build`
/// would reshuffle the flower on every keystroke, scroll and rebuild — a
/// greeting that flickers, which is worse than one that never changes.
///
/// Retired flowers are excluded: they are retired precisely so they stop
/// appearing, and a greeting is the most visible place in the app.
String get greetingFlower => _chosen;

final String _chosen = _pick();

String _pick() {
  final pickable = FlowerCatalog.pickable;
  if (pickable.isEmpty) return '🌷';
  // Seeded from the clock rather than a fixed seed, so two launches a
  // second apart still differ.
  return pickable[Random(DateTime.now().microsecondsSinceEpoch)
          .nextInt(pickable.length)]
      .emoji;
}

import 'package:dayflower/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 🔴 **Why `const` and a global palette do not mix.**
///
/// The palette is global state swapped under ~950 `AppColors.x` call sites.
/// That is cheap, and it has one sharp edge: Flutter skips a subtree whose
/// widget instance is `identical` to the last one. A `const` widget is always
/// identical to itself, so its `build` never re-runs and it keeps painting
/// the colours of the mode it was first inflated in.
///
/// The app works around this by keying the whole `MaterialApp` on the mode,
/// which throws the element tree away. This file pins both halves of that:
/// the failure is real when nothing forces the rebuild, and the key is what
/// fixes it. Without the first test the second proves nothing.
void main() {
  tearDown(() => AppColors.use(AppMode.light));

  /// Colour of the one painted box on screen.
  Color surfaceOf(WidgetTester tester) {
    // Scoped to the card: MaterialApp paints ColoredBoxes of its own.
    final box = tester.widget<ColoredBox>(find.descendant(
        of: find.byType(_ConstCard), matching: find.byType(ColoredBox)));
    return box.color;
  }

  testWidgets('a const card keeps the palette it was first built in',
      (tester) async {
    AppColors.use(AppMode.light);
    var mode = AppMode.light;

    await tester.pumpWidget(StatefulBuilder(builder: (context, setState) {
      AppColors.use(mode);
      return MaterialApp(
          home: Column(children: [
        const _ConstCard(),
        TextButton(
            onPressed: () => setState(() => mode = AppMode.dark),
            child: const Text('switch')),
      ]));
    }));
    final light = surfaceOf(tester);

    await tester.tap(find.text('switch'));
    await tester.pumpAndSettle();

    // ⚠️ This is the bug, asserted as fact: the global palette moved, the
    // parent rebuilt, and the const child did not notice.
    expect(AppColors.isDark, isTrue);
    expect(surfaceOf(tester), light,
        reason: 'a const subtree is skipped, so it should still be stale');
  });

  testWidgets('keying the tree on the mode is what repaints it',
      (tester) async {
    AppColors.use(AppMode.light);
    var mode = AppMode.light;

    await tester.pumpWidget(StatefulBuilder(builder: (context, setState) {
      AppColors.use(mode);
      return MaterialApp(
          // The fix app.dart applies: a new key discards the elements, so
          // every widget under it is inflated again and reads the new
          // palette however deeply it is nested and however const it is.
          key: ValueKey(mode),
          home: Column(children: [
            const _ConstCard(),
            TextButton(
                onPressed: () => setState(() => mode = AppMode.dark),
                child: const Text('switch')),
          ]));
    }));
    final light = surfaceOf(tester);

    await tester.tap(find.text('switch'));
    await tester.pumpAndSettle();

    expect(surfaceOf(tester), isNot(light),
        reason: 'the keyed tree should have repainted the const card');
  });
}

/// Stands in for `_Card` in the settings screen: const, and reading the
/// global palette in its build.
class _ConstCard extends StatelessWidget {
  const _ConstCard();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: AppColors.surface, child: const SizedBox(height: 20));
}

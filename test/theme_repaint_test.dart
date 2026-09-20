import 'package:dayflower/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 🔴 **Why a const widget must not read the global palette.**
///
/// The palette is global state swapped under ~950 `AppColors.x` call sites.
/// That is cheap, and it has one sharp edge: `Element.updateChild` returns
/// the existing child untouched when the new widget is identical to the old
/// one, and a const widget is always identical to itself. Its `build` never
/// runs again, so a colour it read from the global palette is read exactly
/// once — it keeps painting the mode it was first inflated in.
///
/// Settings shipped four `const _Card`s and they stayed white on a black
/// screen, with correctly-switched dividers inside them, because `Divider`
/// reads the theme.
///
/// ⚠️ The MaterialApp is keyed on the mode to force that rebuild, and it is
/// not enough on its own: GoRouter's delegate outlives the rekey and keeps
/// the page's elements alive, so the const subtree under it is never thrown
/// away. These tests model the element being preserved, which is the case
/// that actually bites.
void main() {
  tearDown(() => AppColors.use(AppMode.light));

  Color colourOf(WidgetTester tester, Type card) {
    final box = tester.widget<ColoredBox>(
        find.descendant(of: find.byType(card), matching: find.byType(ColoredBox)));
    return box.color;
  }

  /// Rebuilds its child without ever changing its key, the way a preserved
  /// route does.
  Future<void> pump(WidgetTester tester, ValueNotifier<AppMode> mode) =>
      tester.pumpWidget(ValueListenableBuilder<AppMode>(
        valueListenable: mode,
        builder: (context, value, _) {
          AppColors.use(value);
          return MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFFE8618C),
                  surface: AppColors.surface,
                  brightness: value == AppMode.dark
                      ? Brightness.dark
                      : Brightness.light),
            ),
            home: const Column(children: [_GlobalCard(), _ThemedCard()]),
          );
        },
      ));

  testWidgets('a const card reading the global palette goes stale',
      (tester) async {
    AppColors.use(AppMode.light);
    final mode = ValueNotifier(AppMode.light);
    addTearDown(mode.dispose);
    await pump(tester, mode);
    final before = colourOf(tester, _GlobalCard);

    mode.value = AppMode.dark;
    await tester.pumpAndSettle();

    expect(AppColors.isDark, isTrue);
    // 🔴 The bug, pinned as fact: the palette moved, the parent rebuilt, and
    // this card did not notice because nothing ever called its build again.
    expect(colourOf(tester, _GlobalCard), before,
        reason: 'a const subtree is skipped, so this should still be stale');
  });

  testWidgets('a const card reading Theme repaints', (tester) async {
    AppColors.use(AppMode.light);
    final mode = ValueNotifier(AppMode.light);
    addTearDown(mode.dispose);
    await pump(tester, mode);
    final before = colourOf(tester, _ThemedCard);

    mode.value = AppMode.dark;
    await tester.pumpAndSettle();

    // ⚠️ Same const widget, same preserved element, different result: an
    // InheritedWidget notifies its dependents whether or not the widget that
    // registered the dependency is const. That is the whole fix.
    expect(colourOf(tester, _ThemedCard), isNot(before),
        reason: 'depending on Theme should have repainted it');
  });
}

/// How `_Card` used to read its colour.
class _GlobalCard extends StatelessWidget {
  const _GlobalCard();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: AppColors.surface, child: const SizedBox(height: 20));
}

/// How it reads its colour now.
class _ThemedCard extends StatelessWidget {
  const _ThemedCard();

  @override
  Widget build(BuildContext context) => ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: const SizedBox(height: 20));
}

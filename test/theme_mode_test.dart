import 'package:dayflower/core/theme/app_colors.dart';
import 'package:dayflower/core/theme/theme_mode_prefs.dart';
import 'package:dayflower/features/settings/presentation/screens/settings_screen.dart';
import 'package:dayflower/features/tulip/domain/flower_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dark mode is one global palette swapped under ~950 call sites, which is
/// the cheap way to do it and the easy way to get quietly wrong: nothing
/// fails, a screen just becomes unreadable for whoever is using that mode.
/// So the properties that would actually hurt are pinned here.

/// Rough perceived brightness, 0 (black) to 1 (white).
double _luminance(Color c) =>
    (0.299 * (c.r * 255) + 0.587 * (c.g * 255) + 0.114 * (c.b * 255)) / 255;

void main() {
  // ⚠️ The palette is global. A test that leaves it dark hands the next
  // file a dark app, and the failure would look like anything but this.
  tearDown(() => AppColors.use(AppMode.light));

  group('the swap', () {
    test('changes the canvas and the ink', () {
      AppColors.use(AppMode.light);
      final lightBackground = AppColors.background;
      final lightInk = AppColors.ink;

      AppColors.use(AppMode.dark);
      expect(AppColors.background, isNot(lightBackground));
      expect(AppColors.ink, isNot(lightInk));
      expect(AppColors.isDark, isTrue);
    });

    test('leaves the brand alone', () {
      // The gradient is the one thing on screen that says "Dayflower". A
      // brand that changes colour when the lights go out is not a brand.
      AppColors.use(AppMode.light);
      const brand = AppColors.brand;
      const pink = AppColors.gradientPink;
      AppColors.use(AppMode.dark);
      expect(AppColors.brand, brand);
      expect(AppColors.gradientPink, pink);
    });

    test('never leaves a neutral shared between the two', () {
      // 🔴 A copy-paste that left one line at its light value would be a
      // single unreadable strip on every screen, and nothing would fail.
      AppColors.use(AppMode.light);
      final light = [
        AppColors.background,
        AppColors.surface,
        AppColors.surfaceSubtle,
        AppColors.ink,
        AppColors.body,
        AppColors.muted,
        AppColors.border,
        AppColors.blush,
        AppColors.blushMid,
        AppColors.dangerSubtle,
      ];
      AppColors.use(AppMode.dark);
      final dark = [
        AppColors.background,
        AppColors.surface,
        AppColors.surfaceSubtle,
        AppColors.ink,
        AppColors.body,
        AppColors.muted,
        AppColors.border,
        AppColors.blush,
        AppColors.blushMid,
        AppColors.dangerSubtle,
      ];
      for (var i = 0; i < light.length; i++) {
        expect(dark[i], isNot(light[i]), reason: 'neutral $i did not move');
      }
    });
  });

  group('readability', () {
    test('ink stands well clear of the canvas in both modes', () {
      for (final mode in AppMode.values) {
        AppColors.use(mode);
        final gap =
            (_luminance(AppColors.ink) - _luminance(AppColors.background)).abs();
        expect(gap, greaterThan(0.5), reason: '${mode.name}: ink on canvas');
      }
    });

    test('the mode decides which way round that is', () {
      // Catches the palettes being wired up backwards, which reads as
      // "dark mode does nothing" on a phone and as nothing at all here.
      AppColors.use(AppMode.light);
      expect(_luminance(AppColors.background), greaterThan(0.5));
      AppColors.use(AppMode.dark);
      expect(_luminance(AppColors.background), lessThan(0.2));
    });

    test('secondary text sits between the ink and the canvas', () {
      // Not brighter than the ink and not lost in the canvas — the whole
      // job of a middle step.
      for (final mode in AppMode.values) {
        AppColors.use(mode);
        final ink = _luminance(AppColors.ink);
        final canvas = _luminance(AppColors.background);
        final body = _luminance(AppColors.body);
        final muted = _luminance(AppColors.muted);
        for (final (name, value) in [('body', body), ('muted', muted)]) {
          expect(
            value > (ink < canvas ? ink : canvas) &&
                value < (ink < canvas ? canvas : ink),
            isTrue,
            reason: '${mode.name}: $name is outside ink..canvas',
          );
        }
      }
    });

    test('your own bubble is still distinguishable from a card', () {
      // Which side said what is carried by fill. If blush ever equals the
      // surface, both halves of the conversation become one colour.
      for (final mode in AppMode.values) {
        AppColors.use(mode);
        expect(AppColors.blush, isNot(AppColors.surface), reason: mode.name);
      }
    });
  });

  group('the flowers on the switch', () {
    test('both resolve to the flower they name', () {
      // FlowerCatalog.byId falls back to the classic tulip for an unknown
      // id, so a typo here would not throw — it would just quietly put two
      // identical tulips on the setting.
      for (final mode in AppMode.values) {
        final flower = FlowerCatalog.byId(mode.flowerId);
        expect(flower.id, mode.flowerId, reason: mode.name);
      }
    });

    test('they are two different flowers', () {
      expect(
        AppMode.light.flowerId,
        isNot(AppMode.dark.flowerId),
      );
    });

    test('each mode points at the other one', () {
      expect(AppMode.light.other, AppMode.dark);
      expect(AppMode.dark.other, AppMode.light);
    });
  });

  group('what was saved', () {
    test('a stored name comes back', () {
      expect(ThemeModePrefs.decode('system'), Appearance.system);
      expect(ThemeModePrefs.decode('dark'), Appearance.dark);
      expect(ThemeModePrefs.decode('light'), Appearance.light);
    });

    test('what the old Dark mode switch saved still means the same', () {
      // Same key, same two names: somebody who turned dark mode on before
      // there were three choices must not be moved to System by an update.
      expect(ThemeModePrefs.decode(AppMode.dark.name), Appearance.dark);
      expect(ThemeModePrefs.decode(AppMode.light.name), Appearance.light);
    });

    test('nothing saved, or a value this build has never heard of, is System',
        () {
      // System is the default. And a newer build that adds a choice must
      // not land a downgrade on a crash.
      expect(ThemeModePrefs.decode(null), Appearance.system);
      expect(ThemeModePrefs.decode(''), Appearance.system);
      expect(ThemeModePrefs.decode('sepia'), Appearance.system);
    });
  });

  group('System, Light, Dark', () {
    test('System is first, and the default', () {
      expect(Appearance.values.first, Appearance.system);
      expect(ThemeModePrefs.startingChoice, Appearance.system);
    });

    test('System follows the phone; Light and Dark do not', () {
      for (final phone in Brightness.values) {
        expect(Appearance.light.resolve(phone), AppMode.light);
        expect(Appearance.dark.resolve(phone), AppMode.dark);
      }
      expect(Appearance.system.resolve(Brightness.light), AppMode.light);
      expect(Appearance.system.resolve(Brightness.dark), AppMode.dark);
    });

    test('the palette moves when the phone does, only on System', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final phone = container.read(phoneBrightnessProvider.notifier);

      phone.state = Brightness.light;
      expect(container.read(themeModeProvider), AppMode.light);
      // Sunset, on a phone set to go dark on a schedule.
      phone.state = Brightness.dark;
      expect(container.read(themeModeProvider), AppMode.dark);

      await container.read(appearanceProvider.notifier).use(Appearance.light);
      expect(container.read(themeModeProvider), AppMode.light,
          reason: 'Light means light, whatever the phone says');

      await container.read(appearanceProvider.notifier).use(Appearance.dark);
      phone.state = Brightness.light;
      expect(container.read(themeModeProvider), AppMode.dark);
    });

    test('a choice is kept for the next launch', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(appearanceProvider.notifier).use(Appearance.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
      await ThemeModePrefs.restore();
      expect(ThemeModePrefs.startingChoice, Appearance.dark);
      expect(AppColors.isDark, isTrue,
          reason: 'restored before the first frame, so no white flash');
      ThemeModePrefs.startingChoice = Appearance.system;
    });

    testWidgets('Settings shows the three, System chosen until another is',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      late WidgetRef seen;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(builder: (_, ref, __) {
              seen = ref;
              return const AppearanceRows();
            }),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      bool chosen(Appearance choice) => tester
          .widget<Semantics>(find.byKey(ValueKey('appearance-${choice.name}')))
          .properties
          .selected!;

      for (final choice in Appearance.values) {
        expect(find.text(choice.title), findsOneWidget);
        expect(find.text(choice.line), findsOneWidget);
      }
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Matches your phone (default)'), findsOneWidget);
      expect(chosen(Appearance.system), isTrue);
      expect(chosen(Appearance.dark), isFalse);
      for (final choice in Appearance.values) {
        for (final line in [choice.title, choice.line]) {
          expect(line.contains('—'), isFalse, reason: 'no em dash: $line');
        }
      }

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(chosen(Appearance.dark), isTrue);
      expect(chosen(Appearance.system), isFalse);
      expect(seen.read(themeModeProvider), AppMode.dark);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(chosen(Appearance.light), isTrue);
      expect(seen.read(themeModeProvider), AppMode.light);
    });
  });
}

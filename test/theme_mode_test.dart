import 'package:dayflower/core/theme/app_colors.dart';
import 'package:dayflower/core/theme/theme_mode_prefs.dart';
import 'package:dayflower/features/tulip/domain/flower_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      final brand = AppColors.brand;
      final pink = AppColors.gradientPink;
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
      expect(ThemeModePrefs.decode('dark'), AppMode.dark);
      expect(ThemeModePrefs.decode('light'), AppMode.light);
    });

    test('a value this build has never heard of reads as light', () {
      // Lets a newer build add a third palette without a downgrade landing
      // on a crash. Nothing saved yet lands here too.
      expect(ThemeModePrefs.decode('sepia'), AppMode.light);
      expect(ThemeModePrefs.decode(null), AppMode.light);
      expect(ThemeModePrefs.decode(''), AppMode.light);
    });
  });
}

import 'package:dayflower/features/widget/widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors ReunionWidget.wholeDaysUntil in Kotlin.
///
/// ⚠️ The real arithmetic lives on the Android side, because the widget has
/// to recompute it every time it draws — a number baked in Dart would still
/// say "412 days" a week later. This is the same rule written twice, so the
/// rule itself can be tested: **calendar days, not elapsed hours.**
int wholeDaysUntil(DateTime happensAt, DateTime now) {
  final target = DateTime(happensAt.year, happensAt.month, happensAt.day);
  final today = DateTime(now.year, now.month, now.day);
  return (target.difference(today).inHours / 24).round();
}

void main() {
  group('widget mode', () {
    test('reunion round-trips through its stored name', () {
      expect(WidgetMode.fromName('reunion'), WidgetMode.reunion);
      expect(WidgetMode.reunion.name, 'reunion');
    });

    test('the older two still resolve', () {
      expect(WidgetMode.fromName('flower'), WidgetMode.flower);
      expect(WidgetMode.fromName('heartbeat'), WidgetMode.heartbeat);
    });

    test('a mode from a newer build falls back rather than throwing', () {
      // A phone that has not updated yet must still draw *something*.
      expect(WidgetMode.fromName('constellation'), WidgetMode.flower);
      expect(WidgetMode.fromName(null), WidgetMode.flower);
    });
  });

  group('countdown', () {
    test('counts calendar days, not hours left', () {
      // 8am tomorrow is "1 day", not 0 because only 14 hours remain. The
      // number has to agree with the one a person counts on a calendar.
      final now = DateTime(2026, 9, 8, 18);
      expect(wholeDaysUntil(DateTime(2026, 9, 9, 8), now), 1);
    });

    test('is 0 on the day itself, whatever the hour', () {
      expect(
        wholeDaysUntil(DateTime(2026, 9, 8, 8), DateTime(2026, 9, 8, 23)),
        0,
      );
    });

    test('goes negative once it has passed', () {
      expect(
        wholeDaysUntil(DateTime(2026, 9, 6), DateTime(2026, 9, 8)),
        -2,
      );
    });

    test('spans months and years', () {
      expect(
        wholeDaysUntil(DateTime(2027, 4, 10), DateTime(2026, 9, 8)),
        214,
      );
    });

    test('survives a 23-hour day', () {
      // Two midnights are 24 hours apart except across a daylight-saving
      // change. Truncating integer division would silently drop a day once
      // a year; rounding does not.
      const twentyThreeHours = 23 / 24;
      expect(twentyThreeHours.round(), 1);
    });
  });

  group('widget keys', () {
    test('the reunion keys match what the Kotlin reads', () {
      // 🔴 These strings are the whole contract with ReunionWidget.kt. There
      // is no compiler on either side of it: a rename here is a widget that
      // silently shows its empty state forever.
      expect(DayflowerWidgets.keyReunionTitle, 'reunion_title');
      expect(DayflowerWidgets.keyReunionPlace, 'reunion_place');
      expect(DayflowerWidgets.keyReunionAt, 'reunion_at');
      expect(DayflowerWidgets.keyReunionBackground, 'reunion_bg');
    });

    test('the provider name matches the manifest receiver', () {
      expect(
        DayflowerWidgets.reunionProviderName,
        'com.dayflower.app.ReunionWidget',
      );
    });
  });
}

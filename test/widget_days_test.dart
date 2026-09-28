import 'dart:io';

import 'package:dayflower/features/settings/presentation/screens/settings_sections.dart';
import 'package:dayflower/features/widget/widget_mode_provider.dart';
import 'package:dayflower/features/widget/widget_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// My Day's days on the home screen: held still, rotating, or a list to
/// scroll, and the Android side that has to agree with what Dart writes.
void main() {
  String read(String path) => File(path).readAsStringSync();
  const kotlin = 'android/app/src/main/kotlin/com/dayflower/app/';

  group('the setting', () {
    test('rotating and scrolling are one choice, and the rotation is kept',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final days = container.read(widgetDaysProvider.notifier);
      expect(container.read(widgetDaysProvider),
          (scroll: false, seconds: 0),
          reason: 'holding still is the default');

      await days.rotate(3);
      expect(container.read(widgetDaysProvider), (scroll: false, seconds: 3));

      await days.scroll();
      // Still 3 underneath, for when they go back to rotating.
      expect(container.read(widgetDaysProvider), (scroll: true, seconds: 3));

      await days.rotate(0);
      expect(container.read(widgetDaysProvider), (scroll: false, seconds: 0));
    });

    testWidgets('one row is chosen, and Scroll is one of them',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Column(children: [
              WidgetDaysRow(
                  title: 'Newest only', subtitle: 'still', seconds: 0),
              WidgetDaysRow(
                  title: 'Rotate every 3 seconds',
                  subtitle: 'rotate',
                  seconds: 3),
              WidgetDaysRow(title: 'Scroll', subtitle: 'list', scroll: true),
            ]),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rotate every 3 seconds'));
      await tester.pumpAndSettle();
      expect(container.read(widgetDaysProvider), (scroll: false, seconds: 3));

      await tester.tap(find.text('Scroll'));
      await tester.pumpAndSettle();
      expect(container.read(widgetDaysProvider).scroll, isTrue);

      // The chosen row is the one drawn with the thick outline.
      double outline(String title) {
        final row = find.ancestor(
            of: find.text(title), matching: find.byType(WidgetDaysRow));
        final ring = tester.widget<AnimatedContainer>(find.descendant(
            of: row, matching: find.byType(AnimatedContainer)));
        final border = (ring.decoration as BoxDecoration).border as Border;
        return border.top.width;
      }

      expect(outline('Scroll'), 6);
      expect(outline('Rotate every 3 seconds'), 1.5,
          reason: 'its seconds are remembered, but it is not the choice');
      expect(outline('Newest only'), 1.5);
    });
  });

  group('the Android side', () {
    test('Kotlin reads the key and value Dart writes', () {
      final widget = read('${kotlin}TodaysTulipWidget.kt');
      expect(
          RegExp(r'const val KEY_DAYS_STYLE = "(\w+)"')
              .firstMatch(widget)
              ?.group(1),
          DayflowerWidgets.keyDaysStyle);
      expect(
          RegExp(r'const val DAYS_SCROLL = "(\w+)"')
              .firstMatch(widget)
              ?.group(1),
          DayflowerWidgets.daysScroll);
    });

    test('the list is declared, and only the launcher can bind it', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      final service = RegExp(r'<service\s+android:name="\.DayListService"[^>]*>')
          .firstMatch(manifest)
          ?.group(0);
      expect(service, isNotNull);
      expect(service, contains('android.permission.BIND_REMOTEVIEWS'));
      expect(service, contains('android:exported="false"'));
    });

    // 🔴 On API 37 the rows' photos, sent with setImageViewBitmap, were each
    // one along: the first day showed the header's avatar, and every day
    // after it the photo of the day before.
    test('a row sends its photo as an Icon, not a numbered bitmap', () {
      final service = read('${kotlin}DayListService.kt')
          // The comment explaining why names the call it replaced.
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(service, contains('setImageViewIcon'));
      expect(service, isNot(contains('setImageViewBitmap')));
    });

    test('a row fills in its taps rather than carrying its own', () {
      final service = read('${kotlin}DayListService.kt');
      expect(service, contains('dayflower://like?id='));
      expect(service, contains('dayflower://open?day='));
      expect(service, isNot(contains('setOnClickPendingIntent')));
      // And the template they fill in can be filled in.
      final receiver = read('${kotlin}DayLikeReceiver.kt');
      expect(receiver, contains('FLAG_MUTABLE'));
      expect(receiver, contains('"open"'));
    });
  });

  // 🔴 Every widget tap blinked every Dayflower widget: home_widget hands
  // the tap to WorkManager, which switched a receiver on and off around the
  // work, and each switch made Android reset all of the app's widgets.
  group('widgets do not blink', () {
    test('the app is the one that keeps WorkManager steady', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android:name=".DayflowerApplication"'));
      final app = read('${kotlin}DayflowerApplication.kt');
      expect(app, contains('ExistingWorkPolicy.KEEP'));
      expect(app, contains('setInitialDelay'));
    });
  });
}

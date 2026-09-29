import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/features/settings/presentation/screens/settings_sections.dart';
import 'package:dayflower/features/widget/heartbeat_themes.dart';
import 'package:dayflower/features/widget/widget_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// The heartbeat widget: its scenes (one free, the rest Premium), the
/// Android side that has to agree with Dart, and the ripple.
void main() {
  String read(String path) => File(path).readAsStringSync();
  const kotlin = 'android/app/src/main/kotlin/com/dayflower/app/';
  const res = 'android/app/src/main/res/';

  group('the scenes', () {
    test('the moon is the default and free; the others are Premium', () {
      expect(HeartbeatTheme.fallback, HeartbeatTheme.moon);
      expect(HeartbeatTheme.moon.premium, isFalse);
      for (final t in HeartbeatTheme.values.where((t) => t != HeartbeatTheme.moon)) {
        expect(t.premium, isTrue, reason: t.name);
      }
      // Anything unknown, including a newer build's theme, is the moon.
      expect(HeartbeatTheme.fromName(null), HeartbeatTheme.moon);
      expect(HeartbeatTheme.fromName('sloth'), HeartbeatTheme.moon);
      expect(HeartbeatTheme.fromName('puppy'), HeartbeatTheme.puppy);
    });

    test('every scene is on both sides, at 4:5', () {
      for (final t in HeartbeatTheme.values) {
        for (final path in [
          '${res}drawable-nodpi/hb_art_${t.name}.webp',
          t.thumbnail,
        ]) {
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: path);
          final image = img.decodeWebP(file.readAsBytesSync())!;
          expect(image.width * 5, image.height * 4, reason: '$path is 4:5');
        }
      }
    });

    test('Kotlin draws the scene Dart names', () {
      final widget = read('${kotlin}HeartbeatWidget.kt');
      for (final t in HeartbeatTheme.values.where((t) => t != HeartbeatTheme.fallback)) {
        expect(widget, contains('"${t.name}" -> R.drawable.hb_art_${t.name}'),
            reason: t.name);
      }
      expect(widget, contains('else -> R.drawable.hb_art_moon'));
      expect(
          RegExp(r'const val KEY_THEME = "(\w+)"').firstMatch(widget)?.group(1),
          DayflowerWidgets.keyBeatTheme);
    });

    test('a Premium scene is refused without Premium', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(premiumProvider), isFalse,
          reason: 'nothing can be bought yet');
      final themes = container.read(heartbeatThemeProvider.notifier);
      expect(await themes.choose(HeartbeatTheme.cat), isFalse);
      expect(container.read(heartbeatThemeProvider), HeartbeatTheme.moon);
    });

    test('and taken with it', () async {
      final container =
          ProviderContainer(overrides: [premiumProvider.overrideWithValue(true)]);
      addTearDown(container.dispose);
      final themes = container.read(heartbeatThemeProvider.notifier);
      expect(await themes.choose(HeartbeatTheme.capybara), isTrue);
      expect(container.read(heartbeatThemeProvider), HeartbeatTheme.capybara);
    });
  });

  group('the widget', () {
    test('is 4:5 by default', () {
      final info = read('${res}xml/heartbeat_widget_info.xml');
      int dp(String attr) => int.parse(
          RegExp('android:$attr="(\\d+)dp"').firstMatch(info)!.group(1)!);
      expect(dp('minWidth') * 5, dp('minHeight') * 4);
      expect(info, contains('android:previewLayout="@layout/heartbeat_widget"'));
    });

    test('shows no counts', () {
      final layout = read('${res}layout/heartbeat_widget.xml');
      final widget = read('${kotlin}HeartbeatWidget.kt');
      for (final gone in ['beat_mine', 'beat_partner', 'beat_date']) {
        expect(layout, isNot(contains(gone)), reason: gone);
        expect(widget, isNot(contains(gone)), reason: gone);
      }
    });

    // 🔴 The ripple was five whole-widget redraws 80ms apart, which
    // launchers applied unevenly. Now each moving part is a flipper whose
    // in-animation is its move, played by the launcher.
    test('ripples with the launcher\'s own animations', () {
      final layout = read('${res}layout/heartbeat_widget.xml');
      for (final (flip, anim) in [
        ('beat_art_flip', 'hb_thump'),
        ('beat_glow_flip', 'hb_glow'),
        ('beat_ring_flip', 'hb_ring'),
        ('beat_echo_flip', 'hb_echo'),
      ]) {
        final at = layout.indexOf('@+id/$flip"');
        expect(at, isNot(-1), reason: flip);
        final tag = layout.substring(layout.lastIndexOf('<ViewFlipper', at),
            layout.indexOf('>', at));
        expect(tag, contains('android:inAnimation="@anim/$anim"'), reason: flip);
        expect(File('${res}anim/$anim.xml').existsSync(), isTrue, reason: anim);
      }
      final ripple = read('${kotlin}HeartbeatRipple.kt');
      expect(ripple, contains('setDisplayedChild'));
      expect(ripple, isNot(contains('FRAMES')), reason: 'no frame-by-frame');
      for (final old in ['ripple_ring_1', 'ripple_ring_5']) {
        expect(File('${res}drawable/$old.xml').existsSync(), isFalse);
      }
    });

    test('a tap ripples at once, then sends', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android:name=".HeartbeatTapReceiver"'));
      final widget = read('${kotlin}HeartbeatWidget.kt');
      expect(widget, contains('HeartbeatTapReceiver.pendingIntent(context)'));
      final tap = read('${kotlin}HeartbeatTapReceiver.kt');
      expect(
          RegExp(r'const val KEY_READY = "(\w+)"').firstMatch(tap)?.group(1),
          DayflowerWidgets.keyBeatReady);
      expect(tap, contains('dayflower://heartbeat'));
      final ripple = read('${kotlin}HeartbeatRipple.kt');
      expect(RegExp(r'const val KEY_AT = "(\w+)"').firstMatch(ripple)?.group(1),
          DayflowerWidgets.keyBeatPulseAt);
      expect(RegExp(r'const val KEY_DIR = "(\w+)"').firstMatch(ripple)?.group(1),
          DayflowerWidgets.keyBeatPulseDir);
    });

    test('a heartbeat reported twice ripples once', () {
      const t0 = 1000000;
      bool same(bool sent, String? dir, int? at, int now) =>
          DayflowerWidgets.isSamePulse(
              sent: sent, lastDir: dir, lastAt: at, now: now);
      // The widget's own tap, then the app hearing of the same heartbeat
      // after the background send.
      expect(same(true, 'sent', t0, t0 + 12000), isTrue);
      expect(same(true, 'sent', t0, t0 + 31000), isFalse);
      // A push and the app's stream both reporting an arrival.
      expect(same(false, 'received', t0, t0 + 2000), isTrue);
      expect(same(false, 'received', t0, t0 + 5000), isFalse);
      // The other way is another pulse; nothing marked yet is a pulse.
      expect(same(false, 'sent', t0, t0 + 100), isFalse);
      expect(same(true, null, null, t0), isFalse);
    });
  });

  group('Settings', () {
    setUpAll(() async {
      for (final (family, asset) in [
        ('TikTokSans', 'assets/fonts/tiktok/TikTokSans.ttf'),
        (
          'packages/cupertino_icons/CupertinoIcons',
          'packages/cupertino_icons/assets/CupertinoIcons.ttf'
        ),
      ]) {
        await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      }
    });

    testWidgets('the moon is on, and a locked scene says why',
        (tester) async {
      tester.view.physicalSize = const Size(420, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.current,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: HeartbeatThemePicker(),
              ),
            ),
          ),
        ),
      ));
      // The thumbnails are real images: let them decode.
      await tester.runAsync(() async {
        for (final t in HeartbeatTheme.values) {
          await precacheImage(AssetImage(t.thumbnail), tester.element(find.byType(HeartbeatThemePicker)));
        }
      });
      await tester.pumpAndSettle();

      if (const bool.fromEnvironment('CAPTURE_REVIEW')) {
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/review/heartbeat-themes.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      expect(find.text('Moonlight'), findsOneWidget);
      expect(find.text('On your widget'), findsOneWidget);
      expect(find.bySemanticsLabel('Kitten, Premium, locked'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Kitten, Premium, locked'));
      await tester.pump();
      expect(find.textContaining('Kitten comes with Dayflower Premium'),
          findsOneWidget);
      expect(container.read(heartbeatThemeProvider), HeartbeatTheme.moon,
          reason: 'still the moon');
    });
  });
}

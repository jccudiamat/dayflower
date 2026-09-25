import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/features/feedback/data/feedback_repository.dart';
import 'package:dayflower/features/feedback/data/screenshot_events.dart';
import 'package:dayflower/features/feedback/presentation/feedback_screen.dart';
import 'package:dayflower/features/feedback/presentation/screenshot_report.dart';
import 'package:dayflower/features/updates/data/update_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screenshot of the card, opt in:
//   flutter test test/screenshot_report_test.dart --dart-define=CAPTURE_REVIEW=true
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');

class _NoSend implements FeedbackRepository {
  @override
  Future<void> send({
    required String userId,
    required FeedbackKind kind,
    required String message,
    List<FeedbackImage> images = const [],
    String? appVersion,
  }) async {}
}

Finder _labelled(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
    description: 'labelled "$label"');

final _card = find.byType(ScreenshotReportCard);

Future<(StreamController<void>, GoRouter)> _pump(WidgetTester tester,
    {bool prompt = true, GlobalKey? boundary}) async {
  SharedPreferences.setMockInitialValues(
      {'feedback_screenshot_prompt': prompt});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final events = StreamController<void>.broadcast();
  addTearDown(events.close);
  final router = GoRouter(initialLocation: Routes.home, routes: [
    GoRoute(
        path: Routes.home,
        builder: (_, __) => const Scaffold(
            backgroundColor: Color(0xFFF7F2FA),
            body: Center(child: Text('Home')))),
    GoRoute(
        path: Routes.feedback,
        builder: (_, state) => FeedbackScreen(initialImages: [
              if (state.extra case final FeedbackImage shot) shot,
            ])),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      screenshotEventsProvider.overrideWithValue(events.stream),
      routerProvider.overrideWithValue(router),
      feedbackRepositoryProvider.overrideWithValue(_NoSend()),
      installedVersionProvider.overrideWith((ref) async => '1.0.0 (112)'),
    ],
    child: RepaintBoundary(
      key: boundary,
      child: MaterialApp.router(
        theme: AppTheme.current,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        builder: (context, child) => ScreenshotReportGate(child: child),
      ),
    ),
  ));
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
  return (events, router);
}

/// A screenshot, and the real time the capture needs to happen in.
Future<void> _screenshot(WidgetTester tester, StreamController<void> events) async {
  await tester.runAsync(() async {
    events.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  // A frame for the capture to wait on, if it asked for one, then real time
  // for the picture itself.
  await tester.pump();
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    for (final (family, asset) in [
      ('TikTokSans', 'assets/fonts/tiktok/TikTokSans.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      (
        'packages/cupertino_icons/CupertinoIcons',
        'packages/cupertino_icons/assets/CupertinoIcons.ttf'
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });

  testWidgets('Report opens the form with the screen already attached',
      (tester) async {
    final boundary = GlobalKey();
    final (events, _) = await _pump(tester, boundary: boundary);
    expect(_card, findsNothing);

    await _screenshot(tester, events);
    expect(_card, findsOneWidget);
    expect(find.text('Screenshot taken'), findsOneWidget);
    if (_capture) {
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/review/screenshot-report.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
      });
    }

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(_card, findsNothing);
    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(_labelled('Remove screenshot 1'), findsOneWidget,
        reason: 'the screen as it was, attached');

    // Taken again while writing: that one is for this report, no offer.
    await _screenshot(tester, events);
    expect(_card, findsNothing);
  });

  testWidgets('Not now puts it away, and a burst is one offer', (tester) async {
    final (events, _) = await _pump(tester);
    await _screenshot(tester, events);
    await tester.tap(_labelled('Not now'));
    await tester.pumpAndSettle();
    expect(_card, findsNothing);
    expect(find.byType(FeedbackScreen), findsNothing);

    // A second screenshot straight after is the same burst: one offer.
    await _screenshot(tester, events);
    expect(_card, findsNothing);
  });

  testWidgets('switched off in Settings, a screenshot is just a screenshot',
      (tester) async {
    final (events, _) = await _pump(tester, prompt: false);
    await _screenshot(tester, events);
    expect(_card, findsNothing);
  });
}

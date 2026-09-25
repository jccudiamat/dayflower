import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/frames/photo_frames.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/features/booth/domain/strip_templates.dart';
import 'package:dayflower/features/tulip/presentation/screens/templates_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The Templates page is where the photo-booth strips went when the camera's
/// row became the frames, so it has to hold both and hand either back.
Future<TemplateChoice?> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  TemplateChoice? picked;
  final router = GoRouter(initialLocation: '/here', routes: [
    GoRoute(
      path: '/here',
      builder: (context, _) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              picked = await context.push<TemplateChoice>(Routes.templates);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
    GoRoute(
        path: Routes.templates, builder: (_, __) => const TemplatesScreen()),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp.router(
      theme: AppTheme.current,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return picked;
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

  testWidgets('it holds the frames and the booth strips, grouped',
      (tester) async {
    await _pump(tester);
    expect(find.byType(TemplatesScreen), findsOneWidget);
    expect(find.text('ONE PHOTO'), findsOneWidget);
    expect(find.text('TWO PHOTOS'), findsOneWidget);

    // 🔴 The strips used to be the camera's own row. This page is where
    // they live now, so if this section goes, they are unreachable.
    // ⚠️ Dragged rather than scrollUntilVisible, which ends in
    // ensureVisible and scrolls the page out from under the finder.
    for (var i = 0; i < 12 && find.text('PHOTO BOOTH').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(find.text('PHOTO BOOTH'), findsOneWidget);
    expect(find.text(StripTemplate.all.first.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking a frame hands it back to what opened it',
      (tester) async {
    await _pump(tester);
    final frame = photoFrames.firstWhere((f) => f.slots == 1);
    await tester.tap(find.bySemanticsLabel(frame.name).first);
    await tester.pumpAndSettle();
    expect(find.byType(TemplatesScreen), findsNothing, reason: 'it closes');
  });

  testWidgets('search narrows it, and says so when nothing matches',
      (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'kraft');
    await tester.pumpAndSettle();
    expect(find.text('PHOTO BOOTH'), findsNothing,
        reason: 'no strip is called kraft');
    expect(find.text('ONE PHOTO'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing called'), findsOneWidget);
  });

  test('the row under the shutter only offers one-photo frames', () {
    // One press of the shutter is one photo, so a frame that needs two
    // cannot be filled from there — those live on the Templates page.
    final quick = framesForPhotos(1);
    expect(quick, isNotEmpty);
    expect(quick.every((f) => f.slots == 1), isTrue);
    expect(quick.any((f) => f.id == 'torn_note'), isFalse);
  });
}

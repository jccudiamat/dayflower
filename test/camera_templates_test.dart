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
/// What the page handed back, once it closes.
TemplateChoice? picked;

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  picked = null;
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

    // Each section in turn, further down: with a few dozen frames the page
    // is several screens long, and only what is near the screen is built.
    // ⚠️ Dragged rather than scrollUntilVisible, which ends in
    // ensureVisible and scrolls the page out from under the finder.
    Future<void> scrollTo(String heading) async {
      for (var i = 0; i < 30 && find.text(heading).evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
    }

    await scrollTo('TWO PHOTOS');
    expect(find.text('TWO PHOTOS'), findsOneWidget);
    // 🔴 The strips used to be the camera's own row. This page is where
    // they live now, so if this section goes, they are unreachable.
    await scrollTo('PHOTO BOOTH');
    expect(find.text('PHOTO BOOTH'), findsOneWidget);
    expect(find.text(StripTemplate.all.first.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking a frame hands it back to what opened it',
      (tester) async {
    await _pump(tester);
    final frame = photoFrames.firstWhere((f) => f.slots == 1);
    await tester.tap(find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == frame.name));
    await tester.pumpAndSettle();
    expect(find.byType(TemplatesScreen), findsNothing, reason: 'it closes');
    // And hands back that frame, not merely something.
    expect(picked, isA<FrameChoice>());
    expect((picked! as FrameChoice).frame.id, frame.id);
  });

  testWidgets('it offers only what a photo can go into', (tester) async {
    // 🔴 In build 114 the torn note was here, and shooting onto it sent a
    // blank sheet: it has no window, so the photo had nowhere to go.
    await _pump(tester);
    // The whole page, which is several screens long.
    for (var i = 0; i < 40; i++) {
      expect(find.text('Torn note'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(find.text('PAPER'), findsNothing);
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

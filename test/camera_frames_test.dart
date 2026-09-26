import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/models/pair.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/core/widgets/app_snack_bars.dart';
import 'package:dayflower/features/booth/data/strip_repository.dart';
import 'package:dayflower/features/pairing/data/pair_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/tulip/presentation/screens/messages_screen.dart';
import 'package:dayflower/features/tulip/presentation/screens/templates_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Screenshots, opt in:
//   flutter test test/camera_frames_test.dart --dart-define=CAPTURE_REVIEW=true
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');

/// The camera with no camera: the plugin has no answer in a test, which is
/// the same path a phone with a refused permission takes. Everything this
/// file is about is the paper and the controls, not the sensor.
Future<GoRouter> _pump(WidgetTester tester, {GlobalKey? boundary}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(initialLocation: Routes.flowers, routes: [
    GoRoute(path: Routes.flowers, builder: (_, __) => const MessagesScreen()),
    GoRoute(
        path: Routes.templates, builder: (_, __) => const TemplatesScreen()),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      currentPairProvider.overrideWith((ref) async =>
          const Pair(id: 'pair', userA: 'me', userB: 'them', inviteCode: 'T')),
      openStripsProvider.overrideWith((ref) => Stream.value(const [])),
      flowerMessagesProvider.overrideWith((ref) => Stream.value(const [])),
    ],
    child: RepaintBoundary(
      key: boundary,
      child: MaterialApp.router(
        theme: AppTheme.current,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  ));
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _shoot(WidgetTester tester, GlobalKey boundary, String name) =>
    tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/review/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    });

/// Real time for asset images to decode. They never finish on a widget
/// test's fake clock, and a screenshot taken without this shows no paper.
Future<void> _settleImages(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pumpAndSettle();
}

Finder _labelled(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
    description: 'labelled "$label"');

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

  testWidgets('frames sit beside the shutter, modes below it, room under',
      (tester) async {
    final boundary = GlobalKey();
    await _pump(tester, boundary: boundary);
    if (_capture) await _shoot(tester, boundary, 'camera-plain');

    final upload = tester.getRect(find.byTooltip('Upload a photo'));
    final shutter = tester.getRect(_labelled('Take photo'));
    final plain = tester.getRect(_labelled('Plain'));
    // 🔴 The shutter stays in the middle of the screen, where every camera
    // puts it. The first cut let the frames push it off to the left.
    expect(shutter.center.dx, closeTo(390 / 2, 1));
    // Upload to its left, the frames to its right, all on one line.
    expect(upload.right, lessThan(shutter.left));
    // Upload 24pt in from the edge, where it sat before the frames came.
    expect(upload.left, closeTo(24, 1));
    expect(plain.left, greaterThan(shutter.right));
    expect(plain.center.dy, closeTo(shutter.center.dy, 12));

    final camera = tester.getRect(_labelled('CAMERA'));
    final templates = tester.getRect(_labelled('TEMPLATES'));
    expect(camera.top, greaterThan(shutter.bottom), reason: 'modes below');
    expect(templates.left, greaterThanOrEqualTo(camera.right));
    // 🔴 The chosen mode sits directly under the shutter, not the pair.
    expect(camera.center.dx, closeTo(shutter.center.dx, 1));
    // 🔴 The space asked for: the mode row is not against the bottom edge.
    expect(844 - camera.bottom, greaterThan(10));
    // "No flash on this camera" is lifted above the shutter, not put on it.
    expect(find.ancestor(
            of: _labelled('Take photo'),
            matching: find.byType(SnackBarObstacle)),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing a frame shows it on the viewfinder', (tester) async {
    final boundary = GlobalKey();
    await _pump(tester, boundary: boundary);
    expect(find.byWidgetPredicate((w) =>
        w is Image && w.image is AssetImage &&
        (w.image as AssetImage).assetName.contains('frames/polaroid_kraft')),
        findsNothing);

    await tester.tap(_labelled('Kraft polaroid'));
    await tester.pumpAndSettle();
    await _settleImages(tester);
    if (_capture) await _shoot(tester, boundary, 'camera-framed');

    // 🔴 Build 114 showed the bare viewfinder whatever frame was chosen, so
    // the paper was first seen once it had already been sent.
    final paper = find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage)
            .assetName
            .endsWith('frames/polaroid_kraft.webp') &&
        w.fit == BoxFit.fill);
    expect(paper, findsOneWidget, reason: 'the paper, over the viewfinder');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the viewfinder is cut to the hole, not to its box',
      (tester) async {
    final boundary = GlobalKey();
    await _pump(tester, boundary: boundary);
    // The cloud is a way along the row beside the shutter.
    for (var i = 0;
        i < 10 && _labelled('Cloud & moon').hitTestable().evaluate().isEmpty;
        i++) {
      await tester.drag(find.byType(ListView), const Offset(-200, 0));
      await tester.pumpAndSettle();
    }
    await tester.tap(_labelled('Cloud & moon'));
    await tester.pumpAndSettle();
    await _settleImages(tester);
    if (_capture) await _shoot(tester, boundary, 'camera-cloud');

    // 🔴 Build 115 clipped the live feed to the box around the cloud's
    // hole, so the camera showed in the box's corners, outside the cloud.
    final clip = tester.widget<ClipPath>(find.byWidgetPredicate((w) =>
        w is ClipPath && '${w.clipper.runtimeType}' == '_WindowClip'));
    final size = tester.getSize(find.byWidget(clip));
    final path = clip.clipper!.getClip(size);
    expect(path.contains(size.center(Offset.zero)), isTrue,
        reason: 'the middle of the hole shows the camera');
    for (final corner in [
      const Offset(2, 2),
      Offset(size.width - 2, 2),
      Offset(2, size.height - 2),
      Offset(size.width - 2, size.height - 2),
    ]) {
      expect(path.contains(corner), isFalse,
          reason: 'the box corner at $corner is outside the cloud');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a two-photo frame from Templates asks for each photo',
      (tester) async {
    final boundary = GlobalKey();
    await _pump(tester, boundary: boundary);
    await tester.tap(_labelled('TEMPLATES'));
    await tester.pumpAndSettle();
    expect(find.byType(TemplatesScreen), findsOneWidget);

    // Below the one-photo frames, so scroll to it first. ⚠️ Dragged rather
    // than scrollUntilVisible, which ends in ensureVisible and scrolls the
    // page out from under the finder.
    for (var i = 0; i < 10 && _labelled('Two, offset').hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.tap(_labelled('Two, offset'));
    await tester.pumpAndSettle();
    expect(find.byType(TemplatesScreen), findsNothing);
    await _settleImages(tester);
    if (_capture) await _shoot(tester, boundary, 'camera-two-photos');

    // It is lit beside the shutter even though it is not one of the quick
    // ones, and the camera says which photo is next.
    expect(_labelled('Two, offset'), findsOneWidget);
    expect(find.text('Photo 1 of 2'), findsOneWidget);
    // Back from Templates, Camera slides back under the shutter.
    expect(tester.getRect(_labelled('CAMERA')).center.dx,
        closeTo(tester.getRect(_labelled('Take photo')).center.dx, 1));
  });
}

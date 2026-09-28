import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/core/theme/app_colors.dart';
import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:dayflower/features/calls/data/call_transport.dart';
import 'package:dayflower/features/calls/domain/call.dart';
import 'package:dayflower/features/calls/presentation/screens/call_screen.dart';
import 'package:dayflower/features/calls/presentation/widgets/call_video.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Your own picture in a video call: its two buttons along the bottom, big
/// enough for a thumb, and out of the way after a few seconds untouched.
void main() {
  setUpAll(() async {
    for (final (family, asset) in [
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      (
        'packages/cupertino_icons/CupertinoIcons',
        'packages/cupertino_icons/assets/CupertinoIcons.ttf'
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });

  const session = CallSession(
    messageId: 'm',
    room: 'r',
    mode: CallMode.video,
    status: CallStatus.live,
    isCaller: true,
  );

  final boundary = GlobalKey();
  var flips = 0;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    flips = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        callTransportProvider.overrideWithValue(UnconfiguredCallTransport()),
      ],
      child: MaterialApp(
        home: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: const Color(0xFF3A3050),
            child: Stack(children: [
              CallSelfView(session: session, onSwitchCamera: () => flips++),
            ]),
          ),
        ),
      ),
    ));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_REVIEW')) return;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/review/self-view-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Finder flip() => find.bySemanticsLabel('Switch camera');
  Finder hide() => find.bySemanticsLabel('Hide your self-view');
  double opacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(find
          .ancestor(of: flip(), matching: find.byType(AnimatedOpacity))
          .first)
      .opacity;

  testWidgets('the buttons sit along the bottom, and are thumb-sized',
      (tester) async {
    AppColors.use(AppMode.dark);
    addTearDown(() => AppColors.use(AppMode.light));
    await pump(tester);
    await tester.pump();
    await shot(tester, 'controls');

    final tile = tester.getRect(find.byType(LocalVideo));
    for (final button in [flip(), hide()]) {
      final rect = tester.getRect(button);
      expect(rect.height, greaterThanOrEqualTo(40), reason: 'a thumb target');
      expect(rect.center.dy, greaterThan(tile.center.dy),
          reason: 'in the bottom half of the tile');
    }
    // One each side, not a single target to a thumb.
    expect(tester.getRect(hide()).right, lessThan(tester.getRect(flip()).left));
    // Hide shows a picture struck through; the camera flip is the camera.
    expect(
        find.descendant(
            of: hide(),
            matching: find.byWidgetPredicate((w) =>
                w is AppIcon && w.icon == Icons.hide_image_outlined)),
        findsOneWidget);

    await tester.tap(flip());
    await tester.pump();
    expect(flips, 1);
    await tester.pump(CallSelfView.controlsFor * 2);
  });

  testWidgets('they fade untouched, and a tap on the tile brings them back',
      (tester) async {
    await pump(tester);
    await tester.pump();
    expect(opacity(tester), 1);

    await tester.pump(CallSelfView.controlsFor);
    await tester.pumpAndSettle();
    expect(opacity(tester), 0, reason: 'gone after a few seconds');

    // 🔴 A faded button is not pressed. The first tap only brings them back.
    await tester.tap(flip(), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(flips, 0, reason: 'nothing pressed that could not be seen');
    expect(opacity(tester), 1);

    await tester.tap(flip());
    await tester.pump();
    expect(flips, 1);
    await tester.pump(CallSelfView.controlsFor * 2);
  });

  testWidgets('hidden, it is a picture to bring it back', (tester) async {
    await pump(tester);
    await tester.pump();
    await tester.tap(hide());
    await tester.pumpAndSettle();
    await shot(tester, 'hidden');

    final show = find.bySemanticsLabel('Show your self-view');
    expect(show, findsOneWidget);
    expect(
        find.descendant(
            of: show,
            matching: find.byWidgetPredicate(
                (w) => w is AppIcon && w.icon == CupertinoIcons.photo)),
        findsOneWidget);

    await tester.tap(show);
    await tester.pumpAndSettle();
    expect(flip(), findsOneWidget);
    expect(opacity(tester), 1, reason: 'back with its buttons up');
    await tester.pump(CallSelfView.controlsFor * 2);
  });
}

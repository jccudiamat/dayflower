import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dayflower/features/calls/data/ring_light_prefs.dart';
import 'package:dayflower/features/calls/presentation/widgets/ring_light.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The light alone on black, as pixels: alpha is how lit a point is.
Future<ByteData> _render(WidgetTester tester, double thickness) async {
  final boundary = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: RepaintBoundary(
        key: boundary,
        child: SizedBox(
          width: 200,
          height: 400,
          child: ColoredBox(
            color: const Color(0xFF000000),
            child: RingLight(thickness: thickness),
          ),
        ),
      ),
    ),
  ));
  return (await tester.runAsync(() async {
    final image = await (boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary)
        .toImage();
    return image.toByteData(format: ui.ImageByteFormat.rawRgba);
  }))!;
}

/// How bright the red channel is at (x, y), 0 to 255.
int _lit(ByteData pixels, int x, int y) => pixels.getUint8((y * 200 + x) * 4);

/// ⚠️ The light is painted, so a widget test cannot see it look right. What
/// it can hold is the two properties that would make it a bug rather than a
/// feature: that it never swallows a touch, and that it leaves the middle of
/// the screen alone.
void main() {
  testWidgets('it never takes a touch', (tester) async {
    // 🔴 It covers the whole screen, including End. A light that ate the
    // hang-up button would be a call you cannot get out of.
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => tapped = true,
          ),
        ),
        const Positioned.fill(child: RingLight()),
      ]),
    ));

    // Straight through the middle of the light, into the button beneath.
    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);

    // And through a corner, where the glow is at its brightest.
    tapped = false;
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('it lights the rim, not the screen', (tester) async {
    // ⚠️ Pinned as a number because "edges only" is the whole feature. A
    // reach past half the short side would meet in the middle and become a
    // white overlay over the person you called.
    const light = RingLight(thickness: 32);
    await tester.pumpWidget(const MaterialApp(
      home: Stack(children: [Positioned.fill(child: light)]),
    ));
    final size = tester.getSize(find.byType(RingLight));
    expect(light.thickness, lessThan(size.shortestSide / 2));
  });

  testWidgets('a dark intensity paints nothing at all', (tester) async {
    // The off state is genuinely off, not a faint wash.
    await tester.pumpWidget(const MaterialApp(
      home: Stack(
          children: [Positioned.fill(child: RingLight(intensity: 0))]),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('it lights the corners, not only the sides', (tester) async {
    // 🔴 Rounded all the way out, the four corners were dark wedges on a
    // phone whose own corners are tighter than the guess, and the light
    // looked like a frame that stopped short of the edge.
    final pixels = await _render(tester, 40);
    final side = _lit(pixels, 1, 200);
    expect(side, greaterThan(200), reason: 'the rim is bright');
    for (final (x, y) in [(1, 1), (198, 1), (1, 398), (198, 398)]) {
      expect(_lit(pixels, x, y), greaterThan(side * .8),
          reason: 'corner ($x, $y) is as lit as the side');
    }
    expect(_lit(pixels, 100, 200), 0, reason: 'the middle is untouched');
  });

  testWidgets('wider reaches further in', (tester) async {
    final narrow = await _render(tester, RingLight.minThickness);
    final wide = await _render(tester, RingLight.maxThickness);
    expect(_lit(narrow, 30, 200), 0);
    expect(_lit(wide, 30, 200), greaterThan(40));
  });

  test('the width stays between the ends of its slider', () {
    expect(RingLightWidth.clamp(2), RingLight.minThickness);
    expect(RingLightWidth.clamp(500), RingLight.maxThickness);
    expect(RingLightWidth.clamp(60), 60);
  });
}

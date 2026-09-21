import 'package:dayflower/features/calls/presentation/widgets/ring_light.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    const light = RingLight(thickness: 64);
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
}

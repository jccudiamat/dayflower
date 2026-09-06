import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/core/util/clamp_offset.dart';

/// 🔴 Pressing Home during a call put "Dayflower hit a snag" in the floating
/// window. `num.clamp` **throws** an ArgumentError — in release too, it is
/// not an assertion — when the upper bound falls below the lower one, and
/// every draggable tile in this app computes its upper bound from the window
/// size. Picture-in-picture hands the same widget tree a window a couple of
/// hundred points wide, and the arithmetic inverts.

void main() {
  const tile = Size(116, 164);

  group('a window with room in it', () {
    const phone = Size(390, 844);

    test('leaves a position that already fits alone', () {
      final at = clampToBox(
          value: const Offset(200, 400), box: phone, tile: tile);
      expect(at, const Offset(200, 400));
    });

    test('pulls a position back inside', () {
      final at =
          clampToBox(value: const Offset(9999, 9999), box: phone, tile: tile);
      expect(at.dx, 390 - 116 - 12);
      expect(at.dy, 844 - 164 - 12);
    });

    test('respects the insets it is given', () {
      final at = clampToBox(
        value: const Offset(-50, -50),
        box: phone,
        tile: tile,
        topInset: 47,
        bottomInset: 96,
      );
      expect(at.dy, 12 + 47);
    });
  });

  group('a window with no room', () {
    // 🔴 The case that threw. A PiP window is smaller than the tile plus its
    // margins, so `bounds.width - tile.width - margin` lands *below* the
    // margin and clamp(low, high) has low > high.
    const pip = Size(150, 267);

    test('the minimised call, with the tab-bar inset that broke it', () {
      // ⚠️ These are the real numbers from _CallMiniBar: 96 points reserved
      // at the foot for the tab bar. 267 - 164 - 96 = 7, which is *below*
      // the 12-point margin — and that is the inversion that threw.
      expect(
        () => clampToBox(
          value: const Offset(20, 20),
          box: pip,
          tile: tile,
          bottomInset: 96,
        ),
        returnsNormally,
      );
      final at = clampToBox(
        value: const Offset(20, 20),
        box: pip,
        tile: tile,
        bottomInset: 96,
      );
      // Pressed against the top margin: there is nowhere else for it to be.
      expect(at.dy, 12);
    });

    test('the self-view, whose tile is wider than the window', () {
      // _SelfView is 150 wide with a 14 margin. In a 150-wide window the
      // upper bound is -14.
      final at = clampToBox(
        value: const Offset(20, 20),
        box: pip,
        tile: const Size(150, 210),
        margin: 14,
        bottomInset: 120,
      );
      expect(at, const Offset(14, 14));
    });

    test('holds even when the box is smaller than the margins', () {
      expect(
        () => clampToBox(
            value: Offset.zero, box: const Size(4, 4), tile: tile),
        returnsNormally,
      );
    });

    test('an inset alone can invert the range', () {
      // Tall enough for the tile, until 96 points are reserved at the foot.
      expect(
        () => clampToBox(
          value: const Offset(20, 20),
          box: const Size(390, 200),
          tile: tile,
          bottomInset: 96,
        ),
        returnsNormally,
      );
    });
  });
}

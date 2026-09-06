import 'dart:ui';

/// Keeps a floating tile inside a box that might be smaller than the tile.
///
/// 🔴 **`num.clamp` throws when the upper bound is below the lower one.** Not
/// an assertion — a real `ArgumentError`, in release as well as debug. Every
/// draggable thing in this app clamps itself with an upper bound computed
/// from the window:
///
/// ```dart
/// value.dx.clamp(margin, bounds.width - size.width - margin)
/// ```
///
/// which is fine on a phone and inverted the moment the window is smaller
/// than the tile plus its margins. That is exactly what
/// **picture-in-picture** does: the same widget tree, suddenly a couple of
/// hundred points wide. Pressing Home during a call threw, and because the
/// throw was at the top of the tree it filled the floating window with
/// `CrashScreen`.
///
/// ⚠️ When there is not enough room, this pins to the lower bound rather
/// than throwing. A tile pressed against the edge of a window too small for
/// it is the right answer; there is nowhere else for it to be.
Offset clampToBox({
  required Offset value,
  required Size box,
  required Size tile,
  double margin = 12,
  double topInset = 0,
  double bottomInset = 0,
}) {
  return Offset(
    _between(value.dx, margin, box.width - tile.width - margin),
    _between(
      value.dy,
      margin + topInset,
      // ⚠️ The margin counts on this edge too. Subtracting it from the top
      // and not the bottom means a tile dragged to the foot sits flush
      // against whatever the inset was reserving space for.
      box.height - tile.height - bottomInset - margin,
    ),
  );
}

double _between(double value, double low, double high) =>
    high <= low ? low : value.clamp(low, high);

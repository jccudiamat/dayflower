import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// The line drawn between two people on a map.
///
/// 🔴 **The curve is the real path, not a decorative bow.** Two points make a
/// straight line on the projection, which is not how anybody flies: the
/// shortest route over a sphere bends poleward, and drawing it honestly gives
/// the arc the design wants for free. Bending a straight line by an arbitrary
/// amount would look the same at one zoom and be a lie at every other.
///
/// Lives in core because both maps draw it, and a curve on one screen with a
/// straight line on the other would read as two different products.
class FlightPath {
  const FlightPath._();

  /// Points along the great circle from [a] to [b], ends included.
  ///
  /// ⚠️ Does not split at the antimeridian. A pair either side of the Pacific
  /// draws the long way round the map rather than the short way across the
  /// edge. `CameraFit.bounds` has the same blind spot, so at least the two
  /// agree; fixing it means splitting the line and the bounds together.
  static List<LatLng> between(LatLng a, LatLng b, {int segments = 48}) {
    assert(segments > 0);
    final f1 = a.latitudeInRad, l1 = a.longitudeInRad;
    final f2 = b.latitudeInRad, l2 = b.longitudeInRad;

    final d = 2 *
        math.asin(math.sqrt(math.pow(math.sin((f1 - f2) / 2), 2) +
            math.cos(f1) *
                math.cos(f2) *
                math.pow(math.sin((l1 - l2) / 2), 2)));
    // The same place, or near enough that interpolating would divide by zero.
    if (d.abs() < 1e-9) return [a, b];

    final points = <LatLng>[];
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final x = math.sin((1 - t) * d) / math.sin(d);
      final y = math.sin(t * d) / math.sin(d);
      final px =
          x * math.cos(f1) * math.cos(l1) + y * math.cos(f2) * math.cos(l2);
      final py =
          x * math.cos(f1) * math.sin(l1) + y * math.cos(f2) * math.sin(l2);
      final pz = x * math.sin(f1) + y * math.sin(f2);
      points.add(LatLng(
        math.atan2(pz, math.sqrt(px * px + py * py)) * 180 / math.pi,
        math.atan2(py, px) * 180 / math.pi,
      ));
    }
    return points;
  }

  /// The route split in two, with a hole in the middle for the aircraft.
  ///
  /// ⚠️ A gap, not a shorter line. Drawing the dashes straight through the
  /// plane leaves them crossing the fuselage, which reads as a line with a
  /// sticker on it rather than an aircraft flying a route. Both halves keep
  /// their own end so the path still meets both people.
  static (List<LatLng>, List<LatLng>) splitAtMidpoint(List<LatLng> route,
      {int gap = 3}) {
    final i = route.length ~/ 2;
    final before = route.sublist(0, math.max(2, i - gap + 1));
    final after = route.sublist(math.min(route.length - 2, i + gap));
    return (before, after);
  }

  /// The point halfway along a route.
  static LatLng midpoint(List<LatLng> route) => route[route.length ~/ 2];

  /// Which way an aircraft at the midpoint is facing, in radians clockwise
  /// from north.
  ///
  /// ⚠️ Read from the two points either side of it, not from end to end. On a
  /// curve those differ: the endpoint bearing is the heading you set off on,
  /// and using it leaves the aircraft crabbing across its own flight path in
  /// the middle. Material's `Icons.flight` is drawn nose-north, so this needs
  /// no further offset.
  static double headingAtMidpoint(List<LatLng> route) {
    final i = route.length ~/ 2;
    return bearing(route[math.max(0, i - 1)],
        route[math.min(route.length - 1, i + 1)]);
  }

  /// Initial great-circle bearing from [a] to [b], clockwise from north.
  static double bearing(LatLng a, LatLng b) {
    final f1 = a.latitudeInRad, f2 = b.latitudeInRad;
    final dl = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dl) * math.cos(f2);
    final x = math.cos(f1) * math.sin(f2) -
        math.sin(f1) * math.cos(f2) * math.cos(dl);
    return math.atan2(y, x);
  }
}

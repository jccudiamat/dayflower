import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// The line drawn between two people on a map: one even arc.
///
/// 🔴 **It was the great circle, and it read as a kink.** The true flown
/// path between two cities at different latitudes is lopsided on the
/// projection: Dubai to Manila runs nearly flat for half its length, then
/// bends down, and the bend sat right under the aircraft. What people saw
/// was two straight lines meeting at an angle. This is the arc route maps
/// actually draw: symmetric, bowed north, with its peak halfway, where the
/// aircraft sits.
///
/// ⚠️ Built on the Web Mercator projection the maps use, not on raw
/// degrees. Mercator scales evenly at every zoom, so an arc even on the
/// projection is even on screen however far in you pinch; bent in degrees,
/// it would lean the further from the equator it ran.
///
/// Lives in core because both maps draw it, and a curve on one screen with
/// a different one on the other would read as two different products.
class FlightPath {
  const FlightPath._();

  /// How far the arc rises above the straight line, as a share of that
  /// line's length: enough to read as a flight, not so much it loops.
  static const bow = .18;

  /// Points along an even arc from [a] to [b], ends included, peaking
  /// halfway ([midpoint]).
  ///
  /// ⚠️ Does not split at the antimeridian. A pair either side of the Pacific
  /// draws the long way round the map rather than the short way across the
  /// edge. `CameraFit.bounds` has the same blind spot, so at least the two
  /// agree; fixing it means splitting the line and the bounds together.
  static List<LatLng> between(LatLng a, LatLng b, {int segments = 48}) {
    assert(segments > 0);
    final (ax, ay) = _project(a);
    final (bx, by) = _project(b);
    final dx = bx - ax, dy = by - ay;
    final length = math.sqrt(dx * dx + dy * dy);
    // The same place, or near enough that there is no line to bow.
    if (length < 1e-9) return [a, b];

    // The perpendicular that points north, so every arc bows the same way
    // up; due east for a line running straight north-south.
    var nx = -dy / length, ny = dx / length;
    if (ny < 0 || (ny == 0 && nx < 0)) {
      nx = -nx;
      ny = -ny;
    }
    // A quadratic curve peaks halfway between its chord and its control
    // point, so the control sits twice the rise out.
    final cx = (ax + bx) / 2 + nx * 2 * bow * length;
    final cy = (ay + by) / 2 + ny * 2 * bow * length;

    return [
      for (var i = 0; i <= segments; i++)
        () {
          final t = i / segments, u = 1 - t;
          return _unproject(u * u * ax + 2 * u * t * cx + t * t * bx,
              u * u * ay + 2 * u * t * cy + t * t * by);
        }(),
    ];
  }

  /// Web Mercator, in radians: x is longitude, y the stretched latitude.
  static (double, double) _project(LatLng p) {
    final lat = p.latitude.clamp(-_maxLatitude, _maxLatitude) * math.pi / 180;
    return (
      p.longitude * math.pi / 180,
      math.log(math.tan(math.pi / 4 + lat / 2)),
    );
  }

  static LatLng _unproject(double x, double y) {
    final lat = (2 * math.atan(math.exp(y)) - math.pi / 2) * 180 / math.pi;
    final lon = x * 180 / math.pi;
    return LatLng(lat.clamp(-_maxLatitude, _maxLatitude),
        ((lon + 180) % 360 + 360) % 360 - 180);
  }

  /// Where Web Mercator stops: the top and bottom edge of every tile set.
  static const _maxLatitude = 85.05112878;

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

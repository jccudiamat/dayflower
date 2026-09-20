import 'dart:math' as math;

import 'package:dayflower/core/map/flight_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _dubai = LatLng(25.2048, 55.2708);
const _manila = LatLng(14.5995, 120.9842);
const _london = LatLng(51.5072, -0.1276);

double _deg(double radians) => radians * 180 / math.pi;

void main() {
  test('the route starts and ends exactly where the people are', () {
    final route = FlightPath.between(_dubai, _manila);
    expect(route.first.latitude, closeTo(_dubai.latitude, 1e-6));
    expect(route.first.longitude, closeTo(_dubai.longitude, 1e-6));
    expect(route.last.latitude, closeTo(_manila.latitude, 1e-6));
    expect(route.last.longitude, closeTo(_manila.longitude, 1e-6));
  });

  test('the line bows away from the straight one, which is the whole point',
      () {
    // A great circle between two points at similar latitudes passes nearer
    // the pole than the straight line on the projection does. If this ever
    // comes out flat, the curve has quietly become a two-point line again.
    final route = FlightPath.between(_dubai, _manila);
    final mid = FlightPath.midpoint(route);
    final straight = (_dubai.latitude + _manila.latitude) / 2;
    expect(mid.latitude, greaterThan(straight + 0.5),
        reason: 'the flown path should ride north of the straight line');
  });

  test('the plane faces along the curve, not at the far end', () {
    // The heading you set off on and the heading halfway are different on a
    // curve. Using the first leaves the aircraft crabbing across its own path.
    final route = FlightPath.between(_dubai, _manila);
    final atMid = _deg(FlightPath.headingAtMidpoint(route));
    final endToEnd = _deg(FlightPath.bearing(_dubai, _manila));
    expect((atMid - endToEnd).abs(), greaterThan(1.0),
        reason: 'a curved route should not reuse the departure bearing');
    // Dubai to Manila runs broadly east-south-east.
    expect(atMid, inInclusiveRange(90, 150));
  });

  test('a long route is drawn with enough points to look curved', () {
    expect(FlightPath.between(_london, _manila).length, greaterThan(20));
    expect(FlightPath.between(_london, _manila, segments: 4), hasLength(5));
  });

  test('two people in the same place do not divide by zero', () {
    // Same city is an ordinary state — they are together — and it used to be
    // the one input that makes the interpolation blow up.
    final route = FlightPath.between(_dubai, _dubai);
    expect(route, hasLength(2));
    for (final p in route) {
      expect(p.latitude.isFinite, isTrue);
      expect(p.longitude.isFinite, isTrue);
    }
  });

  test('every point on a route is a real coordinate', () {
    for (final pair in [
      [_dubai, _manila],
      [_london, _manila],
      [_london, _dubai],
    ]) {
      for (final p in FlightPath.between(pair[0], pair[1])) {
        expect(p.latitude, inInclusiveRange(-90, 90));
        expect(p.longitude, inInclusiveRange(-180, 180));
      }
    }
  });

  test('the midpoint sits on the line, not beside it', () {
    final route = FlightPath.between(_london, _manila);
    expect(route, contains(FlightPath.midpoint(route)));
  });
}

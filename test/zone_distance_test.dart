import 'package:flutter_test/flutter_test.dart';
import 'package:dayflower/core/utils/zone_distance.dart';

/// Real great-circle distances, from an independent source, so the haversine
/// is checked against the world rather than against itself.
void main() {
  test('London to Dubai is about 3,400 miles', () {
    final miles = milesBetweenZones('Europe/London', 'Asia/Dubai');
    expect(miles, isNotNull);
    expect(miles!, closeTo(3410, 60));
  });

  test('London to Manila is about 6,700 miles', () {
    expect(milesBetweenZones('Europe/London', 'Asia/Manila')!,
        closeTo(6690, 100));
  });

  test('New York to Los Angeles is about 2,450 miles', () {
    expect(milesBetweenZones('America/New_York', 'America/Los_Angeles')!,
        closeTo(2450, 50));
  });

  test('distance is symmetric', () {
    final a = milesBetweenZones('Asia/Tokyo', 'Australia/Sydney')!;
    final b = milesBetweenZones('Australia/Sydney', 'Asia/Tokyo')!;
    expect(a, closeTo(b, 0.0001));
  });

  test('an unknown zone yields null rather than a guess', () {
    expect(milesBetweenZones('Mars/Olympus', 'Europe/London'), isNull);
    expect(milesBetweenZones(null, 'Europe/London'), isNull);
  });

  group('label', () {
    test('formats with a thousands separator', () {
      expect(distanceLabel('Europe/London', 'Asia/Manila'),
          matches(r'^6,\d{3} miles apart ✈️$'));
    });

    test('same city reads as together, not "0 miles apart"', () {
      expect(distanceLabel('Europe/London', 'Europe/London'), 'Together 💛');
    });

    test('null when either zone is unknown, so the line is simply hidden', () {
      expect(distanceLabel('Europe/London', 'Nowhere/Real'), isNull);
    });
  });
}

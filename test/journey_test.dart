import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/features/travel/domain/journey.dart';
import 'package:flutter_test/flutter_test.dart';

/// The line on the travel map makes two claims — how far, and how long.
/// The first has to agree with the home screen; the second is an estimate
/// and has to stay obviously one.

UserProfile person({double? lat, double? lon, String zone = 'Asia/Manila'}) =>
    UserProfile(
      id: 'u',
      displayName: 'Someone',
      timezone: zone,
      city: lat == null ? null : 'Somewhere',
      cityLat: lat,
      cityLon: lon,
    );

// The real pair, from the database.
final dubai = person(lat: 25.07725, lon: 55.30927, zone: 'Asia/Dubai');
final manila = person(lat: 14.5995, lon: 120.9842);

void main() {
  group('when there is a line to draw', () {
    test('needs a real city on both sides', () {
      // 🔴 Unlike the home screen's label, which falls back to the
      // timezone's namesake city. A line on a map is a claim about a
      // *place*: drawing someone on Manila because that is their zone puts
      // their face somewhere they are not.
      expect(journeyBetween(dubai, person()), isNull);
      expect(journeyBetween(person(), manila), isNull);
      expect(journeyBetween(null, manila), isNull);
      expect(journeyBetween(dubai, manila), isNotNull);
    });
  });

  group('how far', () {
    test('Dubai to Manila is about 4,300 miles', () {
      // The number the home screen already prints for this pair. If these
      // two ever disagree, one screen is lying about the same gap.
      final journey = journeyBetween(dubai, manila)!;
      expect(journey.miles, closeTo(4300, 100));
      expect(journey.distanceLabel, matches(r'^4,\d{3} miles$'));
    });

    test('the label groups thousands', () {
      expect(journeyBetween(dubai, manila)!.distanceLabel, contains(','));
    });
  });

  group('how long', () {
    test('a long haul lands in the right few hours', () {
      // ~4,300 miles at 500 mph is 8h36m, plus 45 minutes on the ground.
      final flight = journeyBetween(dubai, manila)!.flight;
      expect(flight.inMinutes, greaterThan(8 * 60));
      expect(flight.inMinutes, lessThan(11 * 60));
    });

    test('never claims a journey takes no time', () {
      // ⚠️ Two cities a few miles apart still cost the ground allowance.
      // "0 min in the air" under a drawn line would read as a bug.
      final close = journeyBetween(
        person(lat: 14.60, lon: 120.98),
        person(lat: 14.65, lon: 121.03),
      )!;
      expect(close.flight, greaterThanOrEqualTo(Journey.onTheGround));
      expect(close.flightLabel, isNot(contains('0 min')));
    });

    test('reads as hours and minutes, not decimals', () {
      expect(journeyBetween(dubai, manila)!.flightLabel,
          matches(r'^\d+h( \d+m)? in the air$'));
    });

    test('a short hop reads in minutes alone', () {
      final close = journeyBetween(
        person(lat: 14.60, lon: 120.98),
        person(lat: 14.65, lon: 121.03),
      )!;
      expect(close.flightLabel, endsWith('min in the air'));
    });
  });
}

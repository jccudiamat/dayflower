import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/services/city_search.dart';
import 'package:dayflower/core/utils/zone_distance.dart';
import 'package:dayflower/features/dates/presentation/screens/events_screen.dart';
import 'package:dayflower/features/home/domain/greeting_flower.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dubai and Tuguegarao City — the two ends of the couple this was built for.
const _dubai = (lat: 25.07725, lon: 55.30927);
const _tuguegarao = (lat: 17.61577, lon: 121.72285);

UserProfile _profile({
  String timezone = 'UTC',
  String? city,
  double? lat,
  double? lon,
  DateTime? birthday,
}) =>
    UserProfile(
      id: 'u',
      displayName: 'Someone',
      timezone: timezone,
      city: city,
      cityLat: lat,
      cityLon: lon,
      birthday: birthday,
    );

void main() {
  group('greeting emoji', () {
    test('is only hearts, plants, sky, scenery and warm faces', () {
      // The exact things that were showing up and should not: every one of
      // them is a real FlowerCatalog entry's emoji, which is where the
      // greeting used to draw from.
      const banned = ['🪑', '🦊', '🐢', '🦅', '🦌', '🦜', '🕊️', '🏜️', '🌫️'];
      for (final b in banned) {
        expect(greetingEmojis, isNot(contains(b)), reason: '$b is not warm');
      }
    });

    test('has enough of them to be worth changing', () {
      expect(greetingEmojis.length, greaterThan(20));
      expect(greetingEmojis.toSet().length, greetingEmojis.length,
          reason: 'a duplicate is twice as likely to show as anything else');
    });

    test('what the greeting shows comes from that list', () {
      expect(greetingEmojis, contains(greetingFlower));
    });
  });

  group('distance', () {
    test('measures between two picked cities, not their timezones', () {
      final me = _profile(
        timezone: 'Asia/Dubai',
        city: 'Dubai',
        lat: _dubai.lat,
        lon: _dubai.lon,
      );
      final them = _profile(
        timezone: 'Asia/Manila',
        city: 'Tuguegarao City',
        lat: _tuguegarao.lat,
        lon: _tuguegarao.lon,
      );

      final miles = haversineMiles(
        _dubai.lat,
        _dubai.lon,
        _tuguegarao.lat,
        _tuguegarao.lon,
      );
      expect(miles, greaterThan(4000));
      expect(miles, lessThan(5000));
      expect(profileDistanceLabel(me, them), contains('miles apart'));
    });

    test('two people in the same town read as together, not as a number', () {
      final a = _profile(city: 'Tuguegarao City', lat: 17.61, lon: 121.72);
      final b = _profile(city: 'Tuguegarao City', lat: 17.62, lon: 121.73);
      expect(profileDistanceLabel(a, b), 'Together 💛');
    });

    test('falls back to the zone estimate when one has no city', () {
      final me = _profile(
        timezone: 'Asia/Dubai',
        city: 'Dubai',
        lat: _dubai.lat,
        lon: _dubai.lon,
      );
      final them = _profile(timezone: 'Asia/Manila');

      // Approximate rather than absent: the estimate measures from Manila,
      // ~300 miles from Tuguegarao, and that is still worth saying.
      final label = profileDistanceLabel(me, them);
      expect(label, isNotNull);
      expect(label, contains('miles apart'));
    });

    test('says nothing at all when there is no partner', () {
      expect(profileDistanceLabel(_profile(), null), isNull);
    });
  });

  group('birthday', () {
    test('is the one still ahead this year', () {
      final from = DateTime(2026, 3, 1);
      expect(
        nextBirthday(DateTime(1998, 4, 12), from),
        DateTime(2026, 4, 12),
      );
    });

    test('rolls to next year once it has passed', () {
      final from = DateTime(2026, 9, 7);
      expect(
        nextBirthday(DateTime(1998, 4, 12), from),
        DateTime(2027, 4, 12),
      );
    });

    test('counts today as still ahead', () {
      final from = DateTime(2026, 4, 12, 23, 59);
      expect(
        nextBirthday(DateTime(1998, 4, 12), from),
        DateTime(2026, 4, 12),
      );
    });

    test('a 29 February birthday lands on 1 March in a common year', () {
      // Deliberate: better a day out than gone for three years running.
      expect(
        nextBirthday(DateTime(2000, 2, 29), DateTime(2027, 1, 1)),
        DateTime(2027, 3, 1),
      );
    });

    test('survives the round trip through a Postgres date', () {
      final profile = _profile(birthday: DateTime(1998, 4, 12));
      expect(profile.toInsertMap()['birthday'], '1998-04-12');
      expect(
        UserProfile.fromMap({
          'id': 'u',
          'display_name': 'Someone',
          'birthday': '1998-04-12',
        }).birthday,
        DateTime(1998, 4, 12),
      );
    });
  });

  group('city results', () {
    test('carry the timezone, so a pick sets the clock too', () {
      final city = CityResult.fromJson(const {
        'name': 'Tuguegarao City',
        'latitude': 17.61577,
        'longitude': 121.72285,
        'timezone': 'Asia/Manila',
        'admin1': 'Cagayan Valley',
        'country': 'Philippines',
      });
      expect(city.timezone, 'Asia/Manila');
      expect(city.label, 'Tuguegarao City, Cagayan Valley, Philippines');
    });

    test('do not repeat a region that is just the city again', () {
      final city = CityResult.fromJson(const {
        'name': 'Dubai',
        'latitude': 25.07725,
        'longitude': 55.30927,
        'timezone': 'Asia/Dubai',
        'admin1': 'Dubai',
        'country': 'United Arab Emirates',
      });
      expect(city.label, 'Dubai, United Arab Emirates');
    });

    test('a profile without coordinates cannot claim a real place', () {
      expect(_profile(city: 'Somewhere').hasPlace, isFalse);
      expect(_profile(city: 'Dubai', lat: 25.0, lon: 55.3).hasPlace, isTrue);
    });
  });
}

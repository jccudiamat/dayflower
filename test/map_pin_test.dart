import 'package:dayflower/features/travel/data/map_pin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// A pin is a row a person typed into, read back off the wire. The ways it
/// goes wrong are all "a field was missing and the map lost a place".

Map<String, dynamic> row({
  String? label,
  String? place,
  Object? lat = 25.07725,
  Object? lon = 55.30927,
  bool? visited,
  String? messageId,
  String? createdAt,
}) =>
    {
      'id': 'p1',
      'pair_id': 'pair',
      'created_by': 'u1',
      'label': label,
      'place': place,
      'lat': lat,
      'lon': lon,
      'visited': visited,
      'message_id': messageId,
      'created_at': createdAt ?? DateTime.now().toUtc().toIso8601String(),
    };

void main() {
  group('rows off the wire', () {
    test('a full row maps across', () {
      final pin = MapPin.fromMap(row(
        label: 'Beach day',
        place: 'Dubai, United Arab Emirates',
        messageId: 'm1',
        visited: true,
      ));
      expect(pin.label, 'Beach day');
      expect(pin.place, 'Dubai, United Arab Emirates');
      expect(pin.lat, closeTo(25.077, 0.001));
      expect(pin.lon, closeTo(55.309, 0.001));
      expect(pin.messageId, 'm1');
      expect(pin.visited, isTrue);
    });

    test('an integer coordinate is still a coordinate', () {
      // 🔴 Postgres hands back a whole number as an int, not a double, and
      // `as double` on it throws. A pin dropped exactly on a meridian would
      // have taken the whole map down with it.
      final pin = MapPin.fromMap(row(lat: 0, lon: 51));
      expect(pin.lat, 0);
      expect(pin.lon, 51);
    });

    test('a pin with no photo is normal, not broken', () {
      // Most pins have none — "somewhere we want to go" never will.
      expect(MapPin.fromMap(row()).messageId, isNull);
    });

    test('visited defaults to somewhere you have been', () {
      // Matches the column default in 0047. A null here means a row written
      // before that column existed, and treating it as a wish rather than a
      // memory would silently redraw history as plans.
      expect(MapPin.fromMap(row(visited: null)).visited, isTrue);
    });

    test('created_at comes back local, not UTC', () {
      // Same rule as every other timestamp in the app — compared against
      // DateTime.now(), which is local.
      final pin = MapPin.fromMap(row());
      expect(pin.createdAt.isUtc, isFalse);
    });

    test('a missing label or place reads as empty, never as a crash', () {
      // The column is `not null`, so this is defence against a hand-edited
      // row rather than something the app can produce — and an empty pin is
      // a better outcome than a map that will not open.
      final pin = MapPin.fromMap(row());
      expect(pin.label, isEmpty);
      expect(pin.place, isEmpty);
    });
  });
}

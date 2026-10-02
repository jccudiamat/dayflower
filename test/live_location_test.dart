import 'dart:io';

import 'package:dayflower/core/models/pair.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/features/location/data/live_location.dart';
import 'package:dayflower/features/pairing/data/pair_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stands in for the live_locations table.
class _Table extends LiveLocationRepository {
  _Table()
      : super(SupabaseClient('https://example.invalid', 'offline',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));

  final shared = <({String userId, String pairId, DeviceFix fix})>[];
  final stopped = <String>[];

  @override
  Future<void> share(
      {required String userId,
      required String pairId,
      required DeviceFix fix}) async {
    shared.add((userId: userId, pairId: pairId, fix: fix));
  }

  @override
  Future<void> stop(String userId) async => stopped.add(userId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a spot', () {
    test('reads off the wire', () {
      final spot = LiveLocation.fromMap({
        'user_id': 'them',
        'pair_id': 'pair',
        'lat': 24,
        'lon': 54.37,
        'accuracy_m': 6.5,
        'place': 'Abu Dhabi',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      expect(spot.lat, 24, reason: 'an int coordinate is still one');
      expect(spot.place, 'Abu Dhabi');
      expect(spot.updatedAt.isUtc, isFalse);
      expect(spot.fresh, isTrue);
    });

    LiveLocation at(Duration ago, {String? place = 'Abu Dhabi'}) =>
        LiveLocation(
            userId: 'them',
            lat: 24.45,
            lon: 54.38,
            place: place,
            updatedAt: DateTime.now().subtract(ago));

    const hubby = UserProfile(
        id: 'them',
        displayName: 'Hubby',
        city: 'Dubai, United Arab Emirates',
        cityLat: 25.2,
        cityLon: 55.27,
        timezone: 'Asia/Dubai',
        petName: 'Hubs');

    test('places them where their phone said, with its town', () {
      final placed =
          placedProfile(hubby, {'them': at(const Duration(minutes: 5))})!;
      expect((placed.cityLat, placed.cityLon), (24.45, 54.38));
      expect(placed.city, 'Abu Dhabi');
      // Everything else is still them.
      expect(placed.petName, 'Hubs');
      expect(placed.timezone, 'Asia/Dubai');
    });

    test('keeps their city name when the phone could not say', () {
      final placed = placedProfile(
          hubby, {'them': at(const Duration(minutes: 5), place: null)})!;
      expect(placed.city, 'Dubai, United Arab Emirates');
      expect(placed.cityLat, 24.45);
    });

    // A spot from yesterday presented as where somebody is now would be a
    // false claim about exactly what this map is trusted for.
    test('goes back to their picked city once the spot is old', () {
      expect(placedProfile(hubby, {'them': at(const Duration(hours: 13))}),
          same(hubby));
      expect(placedProfile(hubby, const {}), same(hubby));
    });
  });

  group('sharing', () {
    const channel = MethodChannel('dayflower/location');
    late List<String> calls;
    late String permission;
    late Map<String, Object?>? fix;
    late _Table table;

    ProviderContainer make({String user = 'me'}) {
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue(user),
        currentPairProvider.overrideWith((ref) async =>
            const Pair(id: 'pair', userA: 'me', userB: 'them', inviteCode: 'X')),
        liveLocationRepositoryProvider.overrideWithValue(table),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DeviceLocation.debugSupported = true;
      calls = [];
      permission = 'none';
      fix = {
        'lat': 25.0761,
        'lon': 55.1324,
        'accuracy': 8.0,
        'place': 'Dubai',
        'precise': true,
      };
      table = _Table();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'permission' => permission,
          'request' => permission = 'precise',
          'current' => fix,
          _ => null,
        };
      });
    });

    tearDown(() {
      DeviceLocation.debugSupported = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('is off until you turn it on, and asks before it shares', () async {
      final container = make();
      await container.read(currentPairProvider.future);
      final sharing = container.read(locationSharingProvider.notifier);
      expect(container.read(locationSharingProvider), isFalse);

      // Off: opening the app sends nothing, and asks the phone nothing.
      await sharing.refresh();
      expect(calls, isEmpty);
      expect(table.shared, isEmpty);

      expect(await sharing.turnOn(), ShareStart.on);
      expect(calls.take(2), ['permission', 'request'],
          reason: "Android's prompt, the first time");
      expect(container.read(locationSharingProvider), isTrue);
      final sent = table.shared.single;
      expect((sent.userId, sent.pairId), ('me', 'pair'));
      expect((sent.fix.lat, sent.fix.lon, sent.fix.place),
          (25.0761, 55.1324, 'Dubai'));
    });

    // The ceiling: one send per five minutes from a phone, however often the
    // app is opened.
    test('sends again only after five minutes', () async {
      final container = make();
      await container.read(currentPairProvider.future);
      final sharing = container.read(locationSharingProvider.notifier);
      permission = 'precise';
      await sharing.turnOn();
      for (var i = 0; i < 5; i++) {
        await sharing.refresh();
      }
      expect(table.shared, hasLength(1));
      expect(LocationSharing.minInterval, const Duration(minutes: 5));
    });

    test('off takes the spot off their map', () async {
      final container = make();
      await container.read(currentPairProvider.future);
      final sharing = container.read(locationSharingProvider.notifier);
      permission = 'precise';
      await sharing.turnOn();
      await sharing.turnOff();
      expect(container.read(locationSharingProvider), isFalse);
      expect(table.stopped, ['me']);
      await sharing.refresh();
      expect(table.shared, hasLength(1), reason: 'nothing more once off');
    });

    test('says why when it cannot start', () async {
      final container = make();
      await container.read(currentPairProvider.future);
      final sharing = container.read(locationSharingProvider.notifier);

      // Refused at the prompt.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => 'none');
      expect(await sharing.turnOn(), ShareStart.noPermission);
      expect(container.read(locationSharingProvider), isFalse);

      // Allowed, but location is switched off on the phone.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              channel,
              (call) async => call.method == 'current'
                  ? {'off': true}
                  : 'precise');
      expect(await sharing.turnOn(), ShareStart.locationOff);
      expect(table.shared, isEmpty);
    });

    // One phone can sign in as either of a couple: turning it on for one
    // must not turn it on for the other.
    test('is kept per account', () async {
      final mine = make();
      await mine.read(currentPairProvider.future);
      permission = 'precise';
      await mine.read(locationSharingProvider.notifier).turnOn();

      final theirs = make(user: 'them');
      theirs.read(locationSharingProvider);
      await Future<void>.delayed(Duration.zero);
      expect(theirs.read(locationSharingProvider), isFalse);

      final mineAgain = make();
      mineAgain.read(locationSharingProvider);
      await Future<void>.delayed(Duration.zero);
      expect(mineAgain.read(locationSharingProvider), isTrue);
    });
  });

  group('Android', () {
    String read(String path) => File(path).readAsStringSync();

    test('asks for location only while the app is in use', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
      expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
      expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')),
          reason: 'never in the background');
      expect(manifest, isNot(contains('FOREGROUND_SERVICE_LOCATION')));
      final native =
          read('android/app/src/main/kotlin/com/dayflower/app/LocationShare.kt');
      expect(
          RegExp(r'const val CHANNEL = "([\w/]+)"').firstMatch(native)?.group(1),
          'dayflower/location');
      expect(
          read('android/app/src/main/kotlin/com/dayflower/app/MainActivity.kt'),
          contains('LocationShare.CHANNEL'));
    });

    test('the table keeps the latest spot and only for the pair', () {
      final sql = read(
          'supabase/migrations/0055_live_location_and_pin_photos.sql');
      expect(sql, contains('user_id uuid primary key'),
          reason: 'one row a person: no history');
      expect(sql, contains('enable row level security'));
      expect(sql, contains('replica identity full'));
      expect(sql, contains('supabase_realtime add table public.live_locations'));
    });
  });
}

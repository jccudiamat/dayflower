import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../onboarding/data/user_repository.dart';
import '../../pairing/data/pair_repository.dart';

/// "Share my exact location": where each of you actually is on the map,
/// rather than the city you picked.
///
/// ## What it is, and what it is not
///
/// - **Opt in, per person.** Off until you turn it on in Settings, and only
///   your own: turning it on shares yours, never asks for theirs.
/// - **While the app is open.** A spot is taken when you open Dayflower or
///   come back to it, and every [refreshEvery] while it stays open. No
///   background location, nothing when the app is closed (LocationShare.kt).
/// - **The latest spot, no history.** One row per person, overwritten each
///   time; turning it off, or signing out, deletes it (migration 0055).
/// - **Only your partner sees it.** Row-level security on the pair.
///
/// ## The ceiling (PROGRESS.md § Cost exposure)
///
/// Each update is one small upsert and one realtime message to one phone:
/// metered by use, so it gets a floor of [minInterval] between sends from a
/// phone, however often the app is opened. At most a dozen an hour.
@immutable
class LiveLocation {
  const LiveLocation({
    required this.userId,
    required this.lat,
    required this.lon,
    required this.updatedAt,
    this.accuracyM,
    this.place,
  });

  final String userId;
  final double lat, lon;
  final double? accuracyM;

  /// The town the phone's geocoder named ("Abu Dhabi"), or null.
  final String? place;
  final DateTime updatedAt;

  /// A spot this old is not "where they are" any more: the map goes back to
  /// their picked city rather than present yesterday's as now.
  static const freshFor = Duration(hours: 12);

  bool get fresh => DateTime.now().difference(updatedAt) < freshFor;

  factory LiveLocation.fromMap(Map<String, dynamic> map) => LiveLocation(
        userId: map['user_id'] as String,
        lat: (map['lat'] as num).toDouble(),
        lon: (map['lon'] as num).toDouble(),
        accuracyM: (map['accuracy_m'] as num?)?.toDouble(),
        place: map['place'] as String?,
        updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      );
}

/// One fix from the phone (LocationShare.kt).
@immutable
class DeviceFix {
  const DeviceFix(
      {required this.lat,
      required this.lon,
      this.accuracyM,
      this.place,
      required this.precise});

  final double lat, lon;
  final double? accuracyM;
  final String? place;

  /// False when only Android's "approximate" was allowed: a couple of
  /// kilometres, not the spot.
  final bool precise;
}

/// What asking the phone came to.
enum FixOutcome { found, noPermission, locationOff, unavailable }

/// The phone's side: its permission, and one fix. Android only.
class DeviceLocation {
  DeviceLocation._();

  static const _channel = MethodChannel('dayflower/location');

  static bool get supported =>
      debugSupported ?? (!kIsWeb && Platform.isAndroid);

  @visibleForTesting
  static bool? debugSupported;

  /// "precise", "approximate" or "none".
  static Future<String> permission() => _call<String>('permission', 'none');

  /// Android's "while using the app" prompt; what was granted.
  static Future<String> request() => _call<String>('request', 'none');

  static Future<void> openSettings() => _call<void>('openSettings', null);

  static Future<(FixOutcome, DeviceFix?)> current() async {
    if (!supported) return (FixOutcome.unavailable, null);
    if (await permission() == 'none') return (FixOutcome.noPermission, null);
    final raw = await _call<Map<Object?, Object?>?>('current', null);
    if (raw == null) return (FixOutcome.unavailable, null);
    if (raw['off'] == true) return (FixOutcome.locationOff, null);
    final lat = raw['lat'], lon = raw['lon'];
    if (lat is! num || lon is! num) return (FixOutcome.unavailable, null);
    return (
      FixOutcome.found,
      DeviceFix(
        lat: lat.toDouble(),
        lon: lon.toDouble(),
        accuracyM: (raw['accuracy'] as num?)?.toDouble(),
        place: raw['place'] as String?,
        precise: raw['precise'] == true,
      ),
    );
  }

  static Future<T> _call<T>(String method, T fallback) async {
    if (!supported) return fallback;
    try {
      return await _channel.invokeMethod<T>(method) ?? fallback;
    } on PlatformException catch (e) {
      debugPrint('location $method failed: $e');
      return fallback;
    } on MissingPluginException {
      return fallback;
    }
  }
}

class LiveLocationRepository {
  LiveLocationRepository(this._client);

  final SupabaseClient _client;

  /// Your spot, replacing the last one.
  Future<void> share(
      {required String userId,
      required String pairId,
      required DeviceFix fix}) async {
    await _client.from('live_locations').upsert({
      'user_id': userId,
      'pair_id': pairId,
      'lat': fix.lat,
      'lon': fix.lon,
      'accuracy_m': fix.accuracyM,
      'place': fix.place,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Sharing off: the spot is gone from their map, not left there.
  Future<void> stop(String userId) async {
    await _client.from('live_locations').delete().eq('user_id', userId);
  }

  Stream<List<LiveLocation>> watchPair(String pairId) => _client
      .from('live_locations')
      .stream(primaryKey: ['user_id'])
      .eq('pair_id', pairId)
      .map((rows) => rows.map(LiveLocation.fromMap).toList());
}

final liveLocationRepositoryProvider = Provider<LiveLocationRepository>(
    (ref) => LiveLocationRepository(ref.watch(supabaseClientProvider)));

/// Both of your spots, by user id, live. Empty until paired, and while
/// neither of you shares (or before migration 0055 is applied).
final liveLocationsProvider =
    StreamProvider.autoDispose<Map<String, LiveLocation>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const {});
  return ref
      .watch(liveLocationRepositoryProvider)
      .watchPair(pair.id)
      .map((rows) => {for (final r in rows) r.userId: r})
      .handleError((Object e) => debugPrint('live locations: $e'));
});

/// [profile], placed where they are right now when they share it and the
/// spot is fresh; as they are otherwise.
UserProfile? placedProfile(
    UserProfile? profile, Map<String, LiveLocation> live) {
  if (profile == null) return null;
  final spot = live[profile.id];
  if (spot == null || !spot.fresh) return profile;
  return profile.placedAt(lat: spot.lat, lon: spot.lon, city: spot.place);
}

/// You, where your phone last said you were (or your picked city).
final placedMeProvider = Provider.autoDispose<AsyncValue<UserProfile?>>((ref) {
  final live = ref.watch(liveLocationsProvider).valueOrNull ?? const {};
  return ref
      .watch(userProfileProvider)
      .whenData((p) => placedProfile(p, live));
});

/// Your partner, where their phone last said they were (or their city).
final placedPartnerProvider =
    Provider.autoDispose<AsyncValue<UserProfile?>>((ref) {
  final live = ref.watch(liveLocationsProvider).valueOrNull ?? const {};
  return ref
      .watch(partnerProfileProvider)
      .whenData((p) => placedProfile(p, live));
});

/// What turning sharing on came to.
enum ShareStart { on, noPermission, locationOff, unavailable, failed }

/// Whether you share your exact location, and the sending of it.
///
/// ⚠️ The switch is kept per account on this phone, because one phone can
/// sign in as either of a couple (as the user's own testing does), and one
/// person turning it on must not turn it on for the other.
class LocationSharing extends StateNotifier<bool> {
  LocationSharing(this._ref, this._userId) : super(false) {
    _load();
  }

  final Ref _ref;
  final String? _userId;

  /// The floor between two sends from this phone: the ceiling.
  static const minInterval = Duration(minutes: 5);

  /// How often a spot is taken while the app stays open.
  static const refreshEvery = Duration(minutes: 15);

  DateTime? _lastSent;
  bool _sending = false;

  String get _key => 'live_location_on_$_userId';

  Future<void> _load() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) state = prefs.getBool(_key) ?? false;
    } catch (_) {}
  }

  Future<void> _save(bool on) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, on);
    } catch (_) {}
  }

  /// Asks for the permission if it has not been given, takes a spot and
  /// shares it. On only when that worked.
  Future<ShareStart> turnOn() async {
    if (_userId == null) return ShareStart.failed;
    var permission = await DeviceLocation.permission();
    if (permission == 'none') permission = await DeviceLocation.request();
    if (permission == 'none') return ShareStart.noPermission;
    final outcome = await _send(force: true);
    switch (outcome) {
      case FixOutcome.found:
        state = true;
        await _save(true);
        return ShareStart.on;
      case FixOutcome.noPermission:
        return ShareStart.noPermission;
      case FixOutcome.locationOff:
        return ShareStart.locationOff;
      case FixOutcome.unavailable:
        return _sendFailed ? ShareStart.failed : ShareStart.unavailable;
    }
  }

  /// Off, and the spot taken off their map.
  Future<void> turnOff() async {
    state = false;
    await _save(false);
    final userId = _userId;
    if (userId == null) return;
    try {
      await _ref.read(liveLocationRepositoryProvider).stop(userId);
    } catch (e) {
      debugPrint('live location stop failed: $e');
    }
  }

  /// Sends a fresh spot if sharing is on and the last was long enough ago.
  /// Called as the app opens and comes back, and on [refreshEvery].
  Future<void> refresh() async {
    if (!state) return;
    await _send();
  }

  bool _sendFailed = false;

  Future<FixOutcome> _send({bool force = false}) async {
    final userId = _userId;
    final pair = _ref.read(currentPairProvider).valueOrNull;
    if (userId == null || pair == null || !pair.isLinked) {
      return FixOutcome.unavailable;
    }
    final now = DateTime.now();
    if (!force && _lastSent != null && now.difference(_lastSent!) < minInterval) {
      return FixOutcome.found;
    }
    if (_sending) return FixOutcome.found;
    _sending = true;
    _sendFailed = false;
    try {
      final (outcome, fix) = await DeviceLocation.current();
      if (fix == null) return outcome;
      await _ref
          .read(liveLocationRepositoryProvider)
          .share(userId: userId, pairId: pair.id, fix: fix);
      _lastSent = now;
      return FixOutcome.found;
    } catch (e) {
      // Offline, or migration 0055 not applied yet.
      debugPrint('live location send failed: $e');
      _sendFailed = true;
      return FixOutcome.unavailable;
    } finally {
      _sending = false;
    }
  }
}

final locationSharingProvider =
    StateNotifierProvider<LocationSharing, bool>((ref) {
  return LocationSharing(ref, ref.watch(currentUserIdProvider));
});

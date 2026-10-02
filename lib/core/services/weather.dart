import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/home/domain/home_moments.dart';

/// The weather where somebody is, right now.
@immutable
class Weather {
  const Weather({required this.celsius, required this.symbol});

  final double celsius;

  /// MET Norway's symbol code: `clearsky_day`, `lightrainshowers_night`,
  /// `fog`... See [emoji].
  final String symbol;

  /// The symbol as one emoji, the size of a word beside a clock.
  String get emoji {
    final day = !symbol.endsWith('_night');
    final s = symbol.split('_').first;
    if (s.contains('thunder')) return '⛈️';
    if (s.contains('snow') || s.contains('sleet')) return '🌨️';
    if (s.contains('rain')) return s.contains('showers') && day ? '🌦️' : '🌧️';
    if (s == 'fog') return '🌫️';
    if (s == 'cloudy') return '☁️';
    if (s == 'partlycloudy') return day ? '⛅' : '☁️';
    if (s == 'fair') return day ? '🌤️' : '🌙';
    if (s == 'clearsky') return day ? '☀️' : '🌙';
    return '🌡️';
  }

  /// Words for a screen reader: "clear", "light rain showers".
  String get description => symbol
      .split('_')
      .first
      .replaceAll('clearsky', 'clear')
      .replaceAll('partlycloudy', 'partly cloudy')
      .replaceAll('showers', ' showers')
      .replaceAll('andthunder', ' and thunder')
      .replaceAllMapped(RegExp(r'^(light|heavy)'), (m) => '${m[1]} ')
      .replaceAll('  ', ' ')
      .trim();

  /// "34°", in Fahrenheit where people read it that way.
  String temperature({required bool fahrenheit}) =>
      '${(fahrenheit ? celsius * 9 / 5 + 32 : celsius).round()}°';

  Map<String, Object> toJson() => {'c': celsius, 's': symbol};

  static Weather? fromJson(Object? json) {
    if (json is! Map) return null;
    final c = json['c'], s = json['s'];
    if (c is! num || s is! String) return null;
    return Weather(celsius: c.toDouble(), symbol: s);
  }
}

/// Where to ask about, rounded to two decimals: about a kilometre, which is
/// finer than a city and coarser than a street. MET Norway refuses more
/// than four decimals and caches better on fewer, and nothing more precise
/// than the profile's city leaves the phone.
@immutable
class WeatherSpot {
  WeatherSpot(double lat, double lon)
      : lat = (lat * 100).roundToDouble() / 100,
        lon = (lon * 100).roundToDouble() / 100;

  final double lat, lon;

  String get key => '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';

  @override
  bool operator ==(Object other) => other is WeatherSpot && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Current weather from MET Norway's Locationforecast (api.met.no).
///
/// ⚠️ **Why MET Norway and not Open-Meteo**, which city search already uses:
/// Open-Meteo's free API is for non-commercial use, and Dayflower is heading
/// for a paid Premium. MET Norway's is free for any use, on three terms,
/// all kept here:
/// - **Say who is asking**: a User-Agent with the app and a contact. The
///   website, never a person's address. (A browser will not let the web
///   build set one; MET takes the page's origin there.)
/// - **Cache, and do not ask again before the answer expires.** Each answer
///   is kept, on disk too, until its `Expires`, and never asked for again
///   within [minRefresh] of the last time, whatever the header says. That
///   is the ceiling (PROGRESS.md § Cost exposure): free, but metered by
///   MET's fair use, at most two places per phone every half hour while
///   Home is open.
/// - **Credit them** (CC BY 4.0): [credit], in the map card's ⓘ.
///
/// What leaves the phone: the two cities' coordinates, rounded
/// ([WeatherSpot]). No account, no identifier.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const credit = 'Weather: MET Norway';
  static const minRefresh = Duration(minutes: 30);
  static const _maxAge = Duration(hours: 3);
  static const _userAgent = 'Dayflower/1.0 +https://mydayflower.com';
  static const _prefsPrefix = 'weather_';

  final _memory = <WeatherSpot, _Entry>{};
  final _inFlight = <WeatherSpot, Future<Weather?>>{};

  /// What is already known about [spot], without waiting: for drawing the
  /// last answer while a fresh one is fetched.
  Weather? peek(WeatherSpot spot) => _memory[spot]?.weather;

  /// The weather at [spot]: from memory or disk while it is fresh, from MET
  /// Norway otherwise. Null when it cannot be had (offline, an error) and
  /// nothing recent is known; the card then shows no weather, not a guess.
  Future<Weather?> current(WeatherSpot spot) {
    final now = DateTime.now();
    final known = _memory[spot];
    if (known != null && known.fresh(now)) return Future.value(known.weather);
    return _inFlight[spot] ??= _load(spot, now).whenComplete(() {
      _inFlight.remove(spot);
    });
  }

  Future<Weather?> _load(WeatherSpot spot, DateTime now) async {
    var entry = _memory[spot] ?? await _readDisk(spot);
    if (entry != null) _memory[spot] = entry;
    if (entry != null && entry.fresh(now)) return entry.weather;

    try {
      final uri =
          Uri.https('api.met.no', '/weatherapi/locationforecast/2.0/compact', {
        'lat': spot.lat.toStringAsFixed(2),
        'lon': spot.lon.toStringAsFixed(2),
      });
      final response = await _client.get(uri, headers: {
        if (!kIsWeb) 'User-Agent': _userAgent,
        if (entry?.lastModified != null)
          'If-Modified-Since': entry!.lastModified!,
      }).timeout(const Duration(seconds: 10));

      final expires = _expiry(response.headers['expires'], now);
      if (response.statusCode == 304 && entry != null) {
        entry = entry.copyWith(fetchedAt: now, expires: expires);
      } else if (response.statusCode == 200) {
        final weather = parse(response.body, now);
        if (weather == null) return _stale(entry, now);
        entry =
            _Entry(weather, now, expires, response.headers['last-modified']);
      } else {
        debugPrint('weather ${response.statusCode} for ${spot.key}');
        return _stale(entry, now);
      }
      _memory[spot] = entry;
      unawaited(_writeDisk(spot, entry));
      return entry.weather;
    } catch (e) {
      debugPrint('weather failed for ${spot.key}: $e');
      return _stale(entry, now);
    }
  }

  /// An old answer is still worth showing for a while, not forever.
  Weather? _stale(_Entry? entry, DateTime now) =>
      entry != null && now.difference(entry.fetchedAt) < _maxAge
          ? entry.weather
          : null;

  /// The header's expiry, but never sooner than [minRefresh].
  static DateTime _expiry(String? header, DateTime now) {
    final floor = now.add(minRefresh);
    if (header == null) return floor;
    try {
      // "Thu, 02 Oct 2026 17:30:00 GMT". Not dart:io's HttpDate, which the
      // web build cannot import.
      final at = DateFormat('EEE, dd MMM yyyy HH:mm:ss', 'en_US')
          .parseUtc(header.replaceAll(' GMT', '').trim());
      return at.isAfter(floor) ? at : floor;
    } catch (_) {
      return floor;
    }
  }

  @visibleForTesting
  static DateTime expiryForTest(String? header, DateTime now) =>
      _expiry(header, now);

  /// The hour that contains [now] in a Locationforecast answer: its
  /// temperature, and the sky for the hour ahead.
  @visibleForTesting
  static Weather? parse(String body, DateTime now) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final series = (json['properties']['timeseries'] as List)
          .cast<Map<String, dynamic>>();
      Map<String, dynamic>? pick;
      for (final step in series) {
        final at = DateTime.parse(step['time'] as String);
        if (at.isAfter(now.toUtc())) break;
        pick = step;
      }
      pick ??= series.isEmpty ? null : series.first;
      if (pick == null) return null;
      final data = pick['data'] as Map<String, dynamic>;
      final celsius =
          (data['instant']['details']['air_temperature'] as num).toDouble();
      final symbol = (data['next_1_hours'] ?? data['next_6_hours'])?['summary']
          ?['symbol_code'] as String?;
      if (symbol == null) return null;
      return Weather(celsius: celsius, symbol: symbol);
    } catch (e) {
      debugPrint('weather parse failed: $e');
      return null;
    }
  }

  Future<_Entry?> _readDisk(WeatherSpot spot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefsPrefix${spot.key}');
      return raw == null ? null : _Entry.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(WeatherSpot spot, _Entry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '$_prefsPrefix${spot.key}', jsonEncode(entry.toJson()));
    } catch (_) {
      // A cache, not a record: losing it costs one more request.
    }
  }
}

@immutable
class _Entry {
  const _Entry(this.weather, this.fetchedAt, this.expires, this.lastModified);

  final Weather weather;
  final DateTime fetchedAt;
  final DateTime expires;
  final String? lastModified;

  bool fresh(DateTime now) => now.isBefore(expires);

  _Entry copyWith({required DateTime fetchedAt, required DateTime expires}) =>
      _Entry(weather, fetchedAt, expires, lastModified);

  Map<String, Object?> toJson() => {
        'w': weather.toJson(),
        'f': fetchedAt.millisecondsSinceEpoch,
        'e': expires.millisecondsSinceEpoch,
        'm': lastModified,
      };

  static _Entry? fromJson(Object? json) {
    if (json is! Map) return null;
    final weather = Weather.fromJson(json['w']);
    final f = json['f'], e = json['e'];
    if (weather == null || f is! int || e is! int) return null;
    return _Entry(weather, DateTime.fromMillisecondsSinceEpoch(f),
        DateTime.fromMillisecondsSinceEpoch(e), json['m'] as String?);
  }
}

final weatherServiceProvider =
    Provider<WeatherService>((ref) => WeatherService());

/// The weather at [WeatherSpot], checked again each minute Home's clock
/// ticks: from the cache until its answer expires, so a tick is a lookup,
/// not a request.
final weatherProvider =
    FutureProvider.autoDispose.family<Weather?, WeatherSpot>((ref, spot) {
  ref.watch(homeClockProvider);
  return ref.watch(weatherServiceProvider).current(spot);
});

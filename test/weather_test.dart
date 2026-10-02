import 'dart:convert';

import 'package:dayflower/core/services/weather.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MET Norway's answer, cut down to what is read: hourly steps, each with
/// the temperature then and the sky for the hour ahead.
String _forecast(DateTime first, List<(double, String)> hours) => jsonEncode({
      'properties': {
        'timeseries': [
          for (final (i, (c, symbol)) in hours.indexed)
            {
              'time': first.add(Duration(hours: i)).toUtc().toIso8601String(),
              'data': {
                'instant': {
                  'details': {'air_temperature': c}
                },
                'next_1_hours': {
                  'summary': {'symbol_code': symbol}
                },
              },
            },
        ],
      },
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reads the hour that is now, not the first one listed', () {
    final now = DateTime.utc(2026, 10, 2, 14, 20);
    final body = _forecast(DateTime.utc(2026, 10, 2, 12), [
      (30, 'fair_day'),
      (32, 'clearsky_day'),
      (34, 'partlycloudy_day'),
      (33, 'rain')
    ]);
    final w = WeatherService.parse(body, now)!;
    expect(w.celsius, 34);
    expect(w.symbol, 'partlycloudy_day');
  });

  test('a symbol as an emoji, and in words', () {
    String e(String s) => Weather(celsius: 0, symbol: s).emoji;
    expect(e('clearsky_day'), '☀️');
    expect(e('clearsky_night'), '🌙');
    expect(e('fair_day'), '🌤️');
    expect(e('partlycloudy_day'), '⛅');
    expect(e('cloudy'), '☁️');
    expect(e('lightrainshowers_day'), '🌦️');
    expect(e('heavyrain'), '🌧️');
    expect(e('rainandthunder'), '⛈️');
    expect(e('lightsnow'), '🌨️');
    expect(e('fog'), '🌫️');
    expect(
        const Weather(celsius: 0, symbol: 'lightrainshowers_day').description,
        'light rain showers');
    expect(const Weather(celsius: 0, symbol: 'partlycloudy_night').description,
        'partly cloudy');
  });

  test('Celsius, or Fahrenheit where people read it that way', () {
    const w = Weather(celsius: 33.6, symbol: 'clearsky_day');
    expect(w.temperature(fahrenheit: false), '34°');
    expect(w.temperature(fahrenheit: true), '92°');
  });

  test('asks about a place to about a kilometre, never finer', () {
    final spot = WeatherSpot(25.204849, 55.270783);
    expect(spot.key, '25.20,55.27');
    expect(WeatherSpot(25.2049, 55.2701), spot, reason: 'the same place');
  });

  // The ceiling (PROGRESS.md § Cost exposure): MET Norway is free on the
  // terms that it is told who is asking and is not asked again before its
  // answer expires.
  test('says who is asking, and asks once per answer', () async {
    final now = DateTime.now().toUtc();
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
          _forecast(now.subtract(const Duration(minutes: 30)),
              [(31, 'clearsky_day')]),
          200,
          headers: {'last-modified': 'Thu, 01 Oct 2026 10:00:00 GMT'});
    });
    final service = WeatherService(client: client);
    final spot = WeatherSpot(14.5995, 120.9842);

    final first = await service.current(spot);
    expect(first!.celsius, 31);
    expect(requests.single.url.host, 'api.met.no');
    expect(
        requests.single.url.queryParameters, {'lat': '14.60', 'lon': '120.98'});
    expect(requests.single.headers['User-Agent'], contains('mydayflower.com'));

    // Home's clock ticking, twice at once: one request, still.
    await Future.wait([service.current(spot), service.current(spot)]);
    expect(requests, hasLength(1));
    expect(service.peek(spot)!.celsius, 31);

    // A new launch reads it from disk instead of asking again.
    final relaunched = WeatherService(client: client);
    expect((await relaunched.current(spot))!.celsius, 31);
    expect(requests, hasLength(1));
  });

  test('never asks again sooner than half an hour, whatever the header', () {
    final now = DateTime.utc(2026, 10, 2, 12);
    expect(WeatherService.expiryForTest('Fri, 02 Oct 2026 12:05:00 GMT', now),
        now.add(WeatherService.minRefresh));
    expect(WeatherService.expiryForTest('Fri, 02 Oct 2026 13:10:00 GMT', now),
        DateTime.utc(2026, 10, 2, 13, 10));
    expect(WeatherService.expiryForTest(null, now),
        now.add(WeatherService.minRefresh));
  });

  test('offline: no weather rather than a guess', () async {
    final service = WeatherService(
        client: MockClient((_) async => throw http.ClientException('offline')));
    expect(await service.current(WeatherSpot(25.2, 55.27)), isNull);
  });
}

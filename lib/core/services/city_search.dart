import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One place a person can say they are.
@immutable
class CityResult {
  const CityResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    this.region,
    this.country,
  });

  final String name;
  final double latitude;
  final double longitude;

  /// The IANA zone the city sits in, straight from the search.
  ///
  /// ⚠️ This is why a city and a timezone are picked in one gesture: nobody
  /// should have to know that Tuguegarao City is `Asia/Manila`, and every
  /// couple who set the zone by hand and skipped the city would get the
  /// estimated distance rather than the real one.
  final String timezone;

  /// State, province or region. "Cagayan Valley", "Dubai", "California".
  final String? region;
  final String? country;

  /// What the profile stores and every screen shows.
  ///
  /// The region is included because city names are not unique — there is a
  /// Dubai in Uttar Pradesh — and "Tuguegarao City, Cagayan Valley,
  /// Philippines" is the difference between a label and an answer.
  String get label => [
        name,
        if (region != null && region!.isNotEmpty && region != name) region,
        if (country != null && country!.isNotEmpty) country,
      ].join(', ');

  /// Just the town, for the tight one-line spots like the home header.
  String get shortLabel => name;

  factory CityResult.fromJson(Map<String, dynamic> json) => CityResult(
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timezone: json['timezone'] as String? ?? 'UTC',
        region: json['admin1'] as String?,
        country: json['country'] as String?,
      );
}

/// Looks up towns and cities by name.
///
/// ⚠️ **This sends the typed query to a third party** — Open-Meteo's
/// geocoding endpoint, which is free, needs no key and is backed by the
/// GeoNames database. Nothing about the user goes with it: no account, no
/// coordinates, no identifier, just the letters they typed into a search
/// box, and only while they are typing in it.
///
/// The alternative was a geolocation plugin reading the device's GPS, which
/// would have meant a native dependency, a runtime permission prompt and a
/// far more sensitive piece of data than "I live in Tuguegarao". A city is
/// the resolution this app actually needs — it feeds a distance in miles and
/// a clock, and neither is improved by knowing which street.
class CitySearch {
  CitySearch._();

  static const _host = 'geocoding-api.open-meteo.com';
  static const _path = '/v1/search';

  /// Below this the results are noise — "Du" matches thousands of places and
  /// none of them are what is being typed yet.
  static const minQueryLength = 2;

  /// Cities matching [query], best match first. Empty on anything that
  /// fails: a search box that shows nothing is recoverable by typing again,
  /// which is not true of one that throws into a red screen.
  static Future<List<CityResult>> search(String query) async {
    final q = query.trim();
    if (q.length < minQueryLength) return const [];

    try {
      final uri = Uri.https(_host, _path, {
        'name': q,
        'count': '12',
        'language': 'en',
        'format': 'json',
      });
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>?;
      if (results == null) return const [];

      return results
          .whereType<Map<String, dynamic>>()
          .map(CityResult.fromJson)
          .toList();
    } catch (e) {
      // Offline, rate-limited, or the shape changed. All three look the same
      // to the person typing, and all three mean "no results".
      debugPrint('city search failed: $e');
      return const [];
    }
  }
}

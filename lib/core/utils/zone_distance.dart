/// How far apart two people are, derived from the only location either of
/// them ever gave us: their IANA timezone.
///
/// This is deliberately not GPS. Asking a couples app for location
/// permission to print one line of text would be a bad trade, and the
/// timezone is already on the profile because the dual clocks need it.
///
/// The cost is precision: a zone is a city, not a person, so "London" means
/// the middle of London and two people in the same zone are zero miles
/// apart. For the sentence this feeds — "2,000 miles apart" — that is the
/// right resolution anyway. Nobody wants it to the metre.
library;

import 'dart:math' as math;

/// Approximate coordinates for each zone's namesake city.
///
/// Only zones people actually pick need to be here; anything missing
/// returns null from [milesBetweenZones], and the caller shows nothing
/// rather than a wrong number.
const _zoneCoordinates = <String, (double lat, double lng)>{
  // The picker's own shortlist first — these are the ones that matter.
  'Asia/Manila': (14.5995, 120.9842),
  'Europe/London': (51.5072, -0.1276),
  'America/New_York': (40.7128, -74.0060),
  'America/Los_Angeles': (34.0522, -118.2437),
  'Asia/Tokyo': (35.6762, 139.6503),
  'Asia/Singapore': (1.3521, 103.8198),
  'Australia/Sydney': (-33.8688, 151.2093),
  'Asia/Dubai': (25.2048, 55.2708),

  // Everything below is reach: a zone the OS reports, or one picked from
  // the full list, should still produce a distance.
  'UTC': (51.4779, 0.0015),
  'Europe/Dublin': (53.3498, -6.2603),
  'Europe/Paris': (48.8566, 2.3522),
  'Europe/Berlin': (52.5200, 13.4050),
  'Europe/Madrid': (40.4168, -3.7038),
  'Europe/Rome': (41.9028, 12.4964),
  'Europe/Amsterdam': (52.3676, 4.9041),
  'Europe/Lisbon': (38.7223, -9.1393),
  'Europe/Zurich': (47.3769, 8.5417),
  'Europe/Stockholm': (59.3293, 18.0686),
  'Europe/Oslo': (59.9139, 10.7522),
  'Europe/Warsaw': (52.2297, 21.0122),
  'Europe/Moscow': (55.7558, 37.6173),
  'Europe/Istanbul': (41.0082, 28.9784),
  'Europe/Athens': (37.9838, 23.7275),
  'America/Chicago': (41.8781, -87.6298),
  'America/Denver': (39.7392, -104.9903),
  'America/Phoenix': (33.4484, -112.0740),
  'America/Toronto': (43.6532, -79.3832),
  'America/Vancouver': (49.2827, -123.1207),
  'America/Mexico_City': (19.4326, -99.1332),
  'America/Sao_Paulo': (-23.5558, -46.6396),
  'America/Bogota': (4.7110, -74.0721),
  'America/Lima': (-12.0464, -77.0428),
  'America/Buenos_Aires': (-34.6037, -58.3816),
  'Asia/Hong_Kong': (22.3193, 114.1694),
  'Asia/Shanghai': (31.2304, 121.4737),
  'Asia/Seoul': (37.5665, 126.9780),
  'Asia/Taipei': (25.0330, 121.5654),
  'Asia/Bangkok': (13.7563, 100.5018),
  'Asia/Jakarta': (-6.2088, 106.8456),
  'Asia/Kuala_Lumpur': (3.1390, 101.6869),
  'Asia/Ho_Chi_Minh': (10.8231, 106.6297),
  'Asia/Kolkata': (22.5726, 88.3639),
  'Asia/Calcutta': (22.5726, 88.3639),
  'Asia/Karachi': (24.8607, 67.0011),
  'Asia/Dhaka': (23.8103, 90.4125),
  'Asia/Kathmandu': (27.7172, 85.3240),
  'Asia/Colombo': (6.9271, 79.8612),
  'Asia/Riyadh': (24.7136, 46.6753),
  'Asia/Qatar': (25.2854, 51.5310),
  'Asia/Kuwait': (29.3759, 47.9774),
  'Asia/Jerusalem': (31.7683, 35.2137),
  'Asia/Tehran': (35.6892, 51.3890),
  'Africa/Cairo': (30.0444, 31.2357),
  'Africa/Lagos': (6.5244, 3.3792),
  'Africa/Nairobi': (-1.2921, 36.8219),
  'Africa/Johannesburg': (-26.2041, 28.0473),
  'Australia/Melbourne': (-37.8136, 144.9631),
  'Australia/Brisbane': (-27.4698, 153.0251),
  'Australia/Perth': (-31.9505, 115.8605),
  'Pacific/Auckland': (-36.8485, 174.7633),
  'Pacific/Honolulu': (21.3069, -157.8583),
};

const double _earthRadiusMiles = 3958.7613;

/// Great-circle distance between two zones, in miles.
///
/// Null when either zone is unknown — the caller should then say nothing.
/// A made-up distance in a line about how far apart two people are would be
/// a strange thing to invent.
double? milesBetweenZones(String? a, String? b) {
  if (a == null || b == null) return null;
  final from = _zoneCoordinates[a];
  final to = _zoneCoordinates[b];
  if (from == null || to == null) return null;

  final lat1 = _radians(from.$1);
  final lat2 = _radians(to.$1);
  final dLat = lat2 - lat1;
  final dLng = _radians(to.$2 - from.$2);

  // Haversine. The naive flat-earth version is out by hundreds of miles at
  // the distances this app is for, which is most of them.
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * _earthRadiusMiles * math.asin(math.min(1, math.sqrt(h)));
}

double _radians(double degrees) => degrees * math.pi / 180;

/// The line the home screen prints: "2,000 miles apart ✈️".
///
/// Returns null when there is no distance to state. Same zone reads
/// "together" rather than "0 miles apart", which is technically true and
/// emotionally wrong — this is the one line on the screen that is about the
/// gap between two people.
String? distanceLabel(String? myZone, String? partnerZone) {
  final miles = milesBetweenZones(myZone, partnerZone);
  if (miles == null) return null;
  if (miles < 25) return 'Together 💛';
  return '${_grouped(miles.round())} miles apart ✈️';
}

/// Thousands separators without pulling in a formatter for one number.
String _grouped(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

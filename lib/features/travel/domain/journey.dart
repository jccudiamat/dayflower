import 'package:intl/intl.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/utils/zone_distance.dart';

/// The gap between the two of you, as the map draws it.
///
/// ⚠️ Distance comes from [haversineMiles] — the same maths behind "4,293
/// miles apart" on the home screen. Two numbers for one gap that disagreed
/// would be worse than either.
class Journey {
  const Journey({required this.miles, required this.flight});

  final double miles;

  /// 🔴 **An estimate, and never a route.** Cruise speed over great-circle
  /// distance plus a fixed allowance for taxi, climb, descent and approach.
  /// It knows nothing about winds, stopovers, or whether anyone actually
  /// flies it — which is the honest shape of the question "how far away are
  /// you", asked by two people who already know the answer is "too far".
  final Duration flight;

  /// Typical commercial cruise, in miles per hour.
  static const cruiseMph = 500.0;

  /// Everything that is not cruising: pushback, taxi, climb, descent,
  /// approach. Roughly constant regardless of how long the flight is, which
  /// is why a short hop is mostly this.
  static const onTheGround = Duration(minutes: 45);

  static final _miles = NumberFormat.decimalPattern();

  /// "4,293 miles". No "apart" — the map says that by drawing the line.
  String get distanceLabel => '${_miles.format(miles.round())} miles';

  /// "9h 20m in the air".
  String get flightLabel {
    final hours = flight.inHours;
    final minutes = flight.inMinutes % 60;
    if (hours == 0) return '$minutes min in the air';
    if (minutes == 0) return '${hours}h in the air';
    return '${hours}h ${minutes}m in the air';
  }
}

/// The line between two people, or null if either has not said where they are.
///
/// ⚠️ Needs a real city on **both** sides — unlike `profileDistanceLabel`,
/// which falls back to the timezone's namesake city. A line drawn on a map
/// is a claim about a place, and putting somebody's pin on Manila because
/// that is their timezone would be drawing a person somewhere they are not.
Journey? journeyBetween(UserProfile? me, UserProfile? partner) {
  if (me == null || partner == null) return null;
  if (!me.hasPlace || !partner.hasPlace) return null;

  final miles = haversineMiles(
    me.cityLat!,
    me.cityLon!,
    partner.cityLat!,
    partner.cityLon!,
  );

  return Journey(
    miles: miles,
    flight: Duration(
      minutes: (miles / Journey.cruiseMph * 60).round() +
          Journey.onTheGround.inMinutes,
    ),
  );
}

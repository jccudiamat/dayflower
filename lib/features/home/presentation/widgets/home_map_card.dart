import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../app_router.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/services/weather.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/map/flight_path.dart';
import '../../../../core/map/map_tiles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/time/zones.dart';
import '../../../../core/utils/zone_distance.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../location/data/live_location.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../domain/home_moments.dart';

/// The two of you on one map, with the gap drawn between.
///
/// ⚠️ A preview, never the map itself. It shows where each of you is and how
/// far that is, and hands off to Together for anything more.
///
/// ⚠️ This card puts a map on the first screen of the app, so every launch
/// fetches tiles. Which provider serves them, and why that matters more here
/// than on the travel map, is [MapTiles].
class HomeMapCard extends ConsumerWidget {
  const HomeMapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Where each of them actually is when they share it (LocationSharing),
    // their picked city otherwise: the pins, the distance, the flight path
    // and the weather all follow.
    final me = ref.watch(placedMeProvider).valueOrNull;
    final partner = ref.watch(placedPartnerProvider).valueOrNull;
    final pair = ref.watch(currentPairProvider).valueOrNull;
    final now = ref.watch(homeClockProvider).valueOrNull ?? DateTime.now();

    final here = _Place.of(me);
    final there = _Place.of(partner);
    // 🔴 Nothing at all until both ends are real. A map with one pin, or with
    // a pin dropped on a guess, makes a false claim about where somebody is,
    // and being trusted about exactly that is this card's whole job.
    if (pair?.isLinked != true || here == null || there == null) {
      return const SizedBox.shrink();
    }

    // The weather where each of them is, beside their clock. The last
    // answer stays up while a fresh one is fetched, so a refresh never
    // blinks it away.
    final weather = ref.read(weatherServiceProvider);
    Weather? weatherAt(_Place p) {
      final spot = WeatherSpot(p.at.latitude, p.at.longitude);
      return ref.watch(weatherProvider(spot)).valueOrNull ?? weather.peek(spot);
    }

    return Container(
      key: const ValueKey('home-map'),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: 'Open our map',
        child: InkWell(
          onTap: () => context.push(Routes.travel),
          // ⚠️ The map runs the whole card and everything else floats on it.
          // The row underneath used to sit on its own white strip, which cut
          // the map off a third of the way up and left the card looking like
          // a picture with a caption bar rather than one window.
          child: _Band(
              here: here, there: there, me: me, partner: partner, now: now,
              hereWeather: weatherAt(here),
              thereWeather: weatherAt(there),
              footer: profileDistanceLabel(me, partner) ?? ''),
        ),
      ),
    );
  }
}

class _Place {
  const _Place(this.at, this.city, this.zone);

  final LatLng at;
  final String city;
  final String zone;

  /// Their real city when they have picked one, the zone's stand-in otherwise.
  static _Place? of(UserProfile? p) {
    if (p == null) return null;
    if (p.hasPlace) {
      return _Place(LatLng(p.cityLat!, p.cityLon!),
          p.city?.split(',').first.trim() ?? zoneCity(p.timezone), p.timezone);
    }
    final coords = zoneCoordinates(p.timezone);
    if (coords == null) return null;
    return _Place(
        LatLng(coords.$1, coords.$2), zoneCity(p.timezone), p.timezone);
  }
}

/// Real tiles, the flight path between them, and a head bubble at each end.
class _Band extends StatelessWidget {
  const _Band(
      {required this.here,
      required this.there,
      required this.me,
      required this.partner,
      required this.now,
      required this.footer,
      this.hereWeather,
      this.thereWeather});

  final _Place here, there;
  final UserProfile? me, partner;
  final DateTime now;

  /// Null where it is not known yet, or could not be had: no weather is
  /// shown then, rather than a guess.
  final Weather? hereWeather, thereWeather;

  /// Where people read temperatures in Fahrenheit. The phone's own region,
  /// not the app's language, which is English everywhere.
  static const _fahrenheit = {'US', 'LR', 'BS', 'KY', 'PW', 'FM', 'MH'};
  static bool get _inFahrenheit => _fahrenheit.contains(
      WidgetsBinding.instance.platformDispatcher.locale.countryCode);

  /// The distance line, drawn over the map rather than under it.
  final String footer;

  /// ⚠️ Every overlay on this card is transparent, so a pale patch of ocean
  /// can leave dark text with almost nothing behind it. A halo costs no
  /// visible box and keeps the words readable over any tile the map serves.
  static List<Shadow> get _halo => [
        Shadow(color: AppColors.surface, blurRadius: 3),
        Shadow(color: AppColors.surface, blurRadius: 6),
      ];

  String _time(String zone) => DateFormat('h:mm a')
      .format(tz.TZDateTime.from(now, safeLocation(zone)))
      .replaceAll(' ', ' ');

  @override
  Widget build(BuildContext context) {
    final route = FlightPath.between(here.at, there.at);
    // The midpoint of the flown path, which on a curve is not the midpoint of
    // the straight line between the ends.
    final mid = FlightPath.midpoint(route);

    final (before, after) = FlightPath.splitAtMidpoint(route);
    final (west, east) = here.at.longitude <= there.at.longitude
        ? (here, there)
        : (there, here);

    return SizedBox(
      height: 178,
      child: Stack(children: [
        // ⚠️ Inert. The whole card is one button, and a map that ate the drag
        // would leave somebody scrubbing tiles instead of scrolling Home.
        Positioned.fill(
          child: IgnorePointer(
            child: FlutterMap(
              options: MapOptions(
                // Frames both people and the whole arc between them, peak
                // included, whatever the gap: neighbours and opposite
                // hemispheres both fill the strip.
                initialCameraFit: CameraFit.coordinates(
                    coordinates: route,
                    padding: const EdgeInsets.fromLTRB(56, 52, 56, 30)),
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.none),
                backgroundColor: AppColors.surfaceSubtle,
              ),
              children: [
                MapTiles.layer(context, labelled: false),
                // Two halves with a hole between them, so no dash crosses the
                // aircraft.
                PolylineLayer(polylines: [
                  for (final leg in [before, after])
                    Polyline(
                      points: leg,
                      color: AppColors.secondary,
                      strokeWidth: 2,
                      pattern: StrokePattern.dashed(segments: const [7, 6]),
                    ),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: mid,
                    width: 30,
                    height: 30,
                    child: Transform.rotate(
                      angle: FlightPath.headingAtMidpoint(route),
                      child: const Icon(Icons.flight,
                          size: 22, color: AppColors.secondary),
                    ),
                  ),
                  _bubble(here.at, me),
                  _bubble(there.at, partner),
                ]),
              ],
            ),
          ),
        ),
        // 🔴 West on the left, east on the right, so each city and clock sit
        // over the face that is actually there. It was always "me" on the
        // left: right on a phone in Dubai, and swapped on the one in the
        // Philippines, which showed its own city above the other face.
        _label(west, Alignment.topLeft,
            identical(west, here) ? hereWeather : thereWeather),
        _label(east, Alignment.topRight,
            identical(east, here) ? hereWeather : thereWeather),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.sm, 0, AppSpace.sm, AppSpace.xs),
            child: Row(children: [
              Expanded(
                  child: Text(footer,
                      style: AppText.body().copyWith(shadows: _halo))),
              Text('See on map',
                  style: AppText.body(AppColors.secondary)
                      .copyWith(shadows: _halo)),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.secondary),
              // The credits as an ⓘ, not a line (MapTiles.attributionButton),
              // in the corner where small maps keep theirs. It floated alone
              // between the two cities, which the user found spoiled the
              // card.
              MapTiles.attributionButton(
                  also: const [WeatherService.credit],
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.xxs, AppSpace.xxs, 0, AppSpace.xxs)),
            ]),
          ),
        ),
      ]),
    );
  }

  /// A city and its clock, and its weather beside the clock, floating
  /// straight on the tiles.
  Widget _label(_Place p, Alignment corner, Weather? weather) => Align(
        alignment: corner,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xs),
          child: Column(
              // Without this the Column takes the Stack's full height and the
              // label drifts to the vertical centre.
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: corner == Alignment.topLeft
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Text(p.city,
                    style: AppText.subtitle().copyWith(shadows: _halo)),
                Semantics(
                  label: weather == null
                      ? null
                      : '${_time(p.zone)}, ${weather.description}, '
                          '${weather.temperature(fahrenheit: _inFahrenheit)}',
                  excludeSemantics: weather != null,
                  child: Text(
                      weather == null
                          ? _time(p.zone)
                          : '${_time(p.zone)} · ${weather.emoji} '
                              '${weather.temperature(fahrenheit: _inFahrenheit)}',
                      key: ValueKey('home-map-time-${p.city}'),
                      style: AppText.body().copyWith(shadows: _halo)),
                ),
              ]),
        ),
      );

  /// The pinned head bubble: their avatar, ringed against the tiles.
  static Marker _bubble(LatLng at, UserProfile? who) => Marker(
        point: at,
        width: 38,
        height: 38,
        child: Container(
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.surface, width: 3),
              boxShadow: AppElevation.card),
          // ⚠️ Clipped inside the ring rather than sized to it: a square
          // avatar behind a round border shows its corners.
          child: ClipOval(child: UserAvatar(who, size: 32)),
        ),
      );
}

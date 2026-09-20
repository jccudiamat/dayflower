import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../app_router.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/map/flight_path.dart';
import '../../../../core/map/map_tiles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/time/zones.dart';
import '../../../../core/utils/zone_distance.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../onboarding/data/user_repository.dart';
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
    final me = ref.watch(userProfileProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
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
      required this.footer});

  final _Place here, there;
  final UserProfile? me, partner;
  final DateTime now;

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

    return SizedBox(
      height: 178,
      child: Stack(children: [
        // ⚠️ Inert. The whole card is one button, and a map that ate the drag
        // would leave somebody scrubbing tiles instead of scrolling Home.
        Positioned.fill(
          child: IgnorePointer(
            child: FlutterMap(
              options: MapOptions(
                // Frames both people whatever the gap, so neighbours and
                // opposite hemispheres both fill the strip.
                initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds(here.at, there.at),
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
        _label(here, Alignment.topLeft),
        _label(there, Alignment.topRight),
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
            ]),
          ),
        ),
        Align(
            alignment: Alignment.topCenter,
            child: MapTiles.attribution(
                padding: const EdgeInsets.only(top: AppSpace.xxs))),
      ]),
    );
  }

  /// A city and its clock, floating straight on the tiles.
  Widget _label(_Place p, Alignment corner) => Align(
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
                Text(_time(p.zone),
                    style: AppText.body().copyWith(shadows: _halo)),
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

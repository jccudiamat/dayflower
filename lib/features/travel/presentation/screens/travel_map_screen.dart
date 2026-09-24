import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../app_router.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../core/map/flight_path.dart';
import '../../../../core/map/map_tiles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ⚠️ latlong2 exports its own Path (a route between points), which shadows
// the dart:ui Path the callout tail is drawn with.
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/ios_back_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../data/map_pin_repository.dart';
import '../../domain/journey.dart';
import '../widgets/add_pin_sheet.dart';
import '../../../../core/widgets/storage_image.dart';

/// Everywhere the two of you have been, and where you are right now.
///
/// 🔴 **The tiles come from OpenStreetMap over the network and the map is
/// blank without them.** Nothing here is bundled — that is the whole reason
/// this feature fits inside the APK's 50 MiB ceiling at all. A phone with no
/// connection gets the pins on an empty ground, which is why the empty state
/// says so rather than looking broken.
///
/// ⚠️ OSM's tile policy expects a real user agent and modest volume. Two
/// people looking at their own map is well inside it; anything that starts
/// prefetching tiles is not, and would need a paid tile host.
class TravelMapScreen extends ConsumerWidget {
  const TravelMapScreen({super.key});

  /// Where the map opens when there is nothing on it yet — far enough out
  /// that any two places in the world are both on screen.
  static const _wholeWorld = LatLng(20, 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pins = ref.watch(mapPinsProvider).valueOrNull ?? const <MapPin>[];
    final me = ref.watch(userProfileProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;

    final people = [
      if (me != null && me.hasPlace) me,
      if (partner != null && partner.hasPlace) partner,
    ];
    final journey = journeyBetween(me, partner);

    final route = journey != null && people.length == 2
        ? FlightPath.between(
            LatLng(people[0].cityLat!, people[0].cityLon!),
            LatLng(people[1].cityLat!, people[1].cityLon!),
          )
        : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The map runs under the status bar, so the bar's icons follow the
      // tiles: dark on the light map, light on the dark one.
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: const AppBottomNav(),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          onPressed: () => showAddPinSheet(context),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add a place'),
        ),
        // 🔴 The whole screen is map, the way Google Maps is. It used to be
        // a rounded card under an app bar, and zoomed out it showed the grey
        // beyond the top and bottom of the world. Now the map runs edge to
        // edge, the controls float on it, and it cannot be dragged or
        // pinched past the world's edges: see [worldFillZoom].
        body: LayoutBuilder(builder: (context, box) {
          final minZoom = worldFillZoom(box.maxHeight);
          final (centre, zoom) = openingCamera(
            [
              for (final pin in pins) LatLng(pin.lat, pin.lon),
              for (final person in people)
                LatLng(person.cityLat!, person.cityLon!),
              ...?route,
            ],
            Size(box.maxWidth, box.maxHeight),
            // Clear of the floating controls and faces above, and of the
            // distance label and Add a place below.
            EdgeInsets.fromLTRB(
                56, MediaQuery.paddingOf(context).top + 130, 56, 160),
            minZoom: minZoom,
          );
          // ⚠️ Expanded, or the stack takes the size of its one unpositioned
          // child, the floating controls, and the map with it: a strip
          // about as tall as the back button.
          return SizedBox.expand(
              child: Stack(children: [
            Positioned.fill(
              child: FlutterMap(
                // Opened again once your places arrive, so it opens on the
                // two of you rather than wherever it stood while loading.
                key: ValueKey((people.length, pins.isEmpty)),
                options: MapOptions(
                  initialCenter: centre,
                  initialZoom: zoom,
                  minZoom: minZoom,
                  maxZoom: 17,
                  // Top and bottom only: sideways the world repeats, as it
                  // does in every map app.
                  cameraConstraint: const CameraConstraint.containLatitude(),
                  // Turning the world sideways is never what somebody
                  // pinching a travel map meant.
                  interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  backgroundColor: AppColors.surfaceSubtle,
                ),
                children: [
                  MapTiles.layer(context),
                  // 🔴 Under the markers, deliberately: a dotted line drawn
                  // over a face reads as a scratch on the photo. Two halves
                  // with a hole for the aircraft, as on Home.
                  if (route != null)
                    PolylineLayer(
                      polylines: [
                        for (final leg in [
                          FlightPath.splitAtMidpoint(route).$1,
                          FlightPath.splitAtMidpoint(route).$2,
                        ])
                          Polyline(
                            points: leg,
                            color: AppColors.brand,
                            strokeWidth: 2,
                            pattern: const StrokePattern.dotted(),
                          ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (route != null) ...[
                        // At the arc's peak, facing along it.
                        Marker(
                          point: FlightPath.midpoint(route),
                          width: 30,
                          height: 30,
                          child: Transform.rotate(
                            angle: FlightPath.headingAtMidpoint(route),
                            child: const Icon(Icons.flight,
                                size: 22, color: AppColors.brand),
                          ),
                        ),
                        // Hanging under the middle of the straight line, so
                        // it never covers the curve it describes.
                        Marker(
                          point: _midpoint(people),
                          // Room below for large text: the label hangs from
                          // the top of this box and grows down into it.
                          width: 180,
                          height: 72,
                          alignment: Alignment.bottomCenter,
                          child: _JourneyLabel(journey: journey!),
                        ),
                      ],
                      for (final person in people)
                        Marker(
                          point: LatLng(person.cityLat!, person.cityLon!),
                          width: 56,
                          height: 66,
                          alignment: Alignment.topCenter,
                          child: _PersonMarker(person: person),
                        ),
                      for (final pin in pins)
                        Marker(
                          point: LatLng(pin.lat, pin.lon),
                          // Generous, because the callout is a pill of text
                          // whose width depends on the label - Marker needs
                          // a fixed box and a cramped one clips the words.
                          width: 220,
                          height: 64,
                          alignment: Alignment.topCenter,
                          child: _PinCallout(pin: pin),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // The controls float on the map.
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.compact, AppSpace.xs, AppSpace.compact, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      _Floating(
                        circle: true,
                        child: IosBackButton(
                            onTap: () => context.canPop()
                                ? context.pop()
                                : context.go(Routes.together)),
                      ),
                      const SizedBox(width: AppSpace.xs),
                      _Floating(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.sm, vertical: 11),
                          child: Text('Travel map', style: AppText.subtitle()),
                        ),
                      ),
                    ]),
                    if (people.length < 2)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xs),
                        child: _MissingPlaceNote(me: me, partner: partner),
                      ),
                  ],
                ),
              ),
            ),
            // Both tile providers require visible credit.
            Positioned(
              left: AppSpace.xxs,
              bottom: AppSpace.xxs,
              child: MapTiles.attribution(),
            ),
          ]));
        }),
      ),
    );
  }

  /// The zoom at which the world is exactly as tall as the map, and so the
  /// furthest out it can go without grey showing above and below.
  ///
  /// ⚠️ A tile is 256 logical pixels and the world is one tile tall at zoom
  /// 0, doubling with each step; the constraint rejects anything wider.
  /// The hair of margin keeps a phone that rounds its height the other way
  /// from sitting a pixel short of the edge.
  @visibleForTesting
  static double worldFillZoom(double height) =>
      height <= 256 ? 0 : math.log(height / 256) / math.ln2 + .01;

  /// [centre], moved north or south just far enough that a map [height]
  /// tall at [zoom] shows nothing beyond the top or bottom of the world.
  ///
  /// 🔴 The latitude constraint holds from the first frame, and an opening
  /// camera outside it is an error, not a nudge. Zoomed all the way out the
  /// world is exactly as tall as the map, and the only centre that fits is
  /// the equator; opening on the two of you at 20 degrees north did not.
  @visibleForTesting
  static LatLng fitCentre(LatLng centre, double zoom, double height) {
    const edge = 85.05112878;
    final world = 256 * math.pow(2, zoom).toDouble();
    // A pixel inside each limit, so the camera's own arithmetic cannot land
    // a hair outside.
    final low = height / 2 + 1, high = world - height / 2 - 1;
    if (high <= low) return LatLng(0, centre.longitude);
    final lat = centre.latitude.clamp(-edge, edge) * math.pi / 180;
    final y = (1 - math.log(math.tan(math.pi / 4 + lat / 2)) / math.pi) /
        2 *
        world;
    final n = math.pi * (1 - 2 * y.clamp(low, high) / world);
    final fitted =
        math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi;
    return LatLng(fitted, centre.longitude);
  }

  /// Under the middle of the straight line between the two of you, where
  /// the label hangs: close to the curve without covering it.
  static LatLng _midpoint(List<UserProfile> people) => LatLng(
        (people[0].cityLat! + people[1].cityLat!) / 2,
        (people[0].cityLon! + people[1].cityLon!) / 2,
      );

  /// Where the map opens: everything in [points] framed inside [padding],
  /// or the whole world when there is nothing to frame.
  ///
  /// 🔴 It opened at a fixed zoom, and on a phone that zoom put Dubai and
  /// the Philippines both off the edges of the screen. Now it fits what is
  /// there: the two of you, the arc between you, and any places you pinned.
  ///
  /// ⚠️ Never further out than [minZoom], and the centre moved as
  /// [fitCentre] needs, so it opens inside the world's top and bottom.
  /// Longitude is a plain span, so two places either side of the date line
  /// frame the long way round, as the arc draws them.
  @visibleForTesting
  static (LatLng, double) openingCamera(
    List<LatLng> points,
    Size size,
    EdgeInsets padding, {
    required double minZoom,
    double oneZoom = 4,
  }) {
    // Web Mercator at zoom 0: the world is one 256-pixel tile.
    double xOf(LatLng p) => (p.longitude + 180) / 360 * 256;
    double yOf(LatLng p) {
      final lat = p.latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
      return (1 - math.log(math.tan(math.pi / 4 + lat / 2)) / math.pi) / 2 * 256;
    }

    if (points.isEmpty) {
      return (fitCentre(_wholeWorld, minZoom, size.height), minZoom);
    }
    final xs = points.map(xOf), ys = points.map(yOf);
    final left = xs.reduce(math.min), right = xs.reduce(math.max);
    final top = ys.reduce(math.min), bottom = ys.reduce(math.max);
    final roomX = math.max(1.0, size.width - padding.horizontal);
    final roomY = math.max(1.0, size.height - padding.vertical);
    final spanX = right - left, spanY = bottom - top;
    var zoom = spanX == 0 && spanY == 0
        ? oneZoom
        : math.min(
            spanX == 0 ? 17.0 : math.log(roomX / spanX) / math.ln2,
            spanY == 0 ? 17.0 : math.log(roomY / spanY) / math.ln2,
          );
    zoom = zoom.clamp(minZoom, 17.0).toDouble();

    // The middle of what is framed, shifted so it sits in the middle of the
    // padded room rather than the middle of the screen.
    final scale = math.pow(2, zoom).toDouble();
    final cx = (left + right) / 2;
    final cy = (top + bottom) / 2 +
        (padding.bottom - padding.top) / 2 / scale;
    final n = math.pi * (1 - 2 * cy / 256);
    final centre = LatLng(
      math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi,
      cx / 256 * 360 - 180,
    );
    return (fitCentre(centre, zoom, size.height), zoom);
  }
}

/// Says which half of the couple has no place set, by name.
///
/// 🔴 The map is the one screen where a missing city is visible as an
/// absence rather than a blank field, so it is the right place to ask —
/// and it names the person, because "someone has not set a city" is a
/// puzzle and "Sheena hasn't set hers" is an instruction.
class _MissingPlaceNote extends StatelessWidget {
  const _MissingPlaceNote({required this.me, required this.partner});

  final UserProfile? me;
  final UserProfile? partner;

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (me != null && !me!.hasPlace) 'You have',
      if (partner != null && !partner!.hasPlace)
        '${partner!.petName ?? partner!.displayName} has',
    ];
    if (missing.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
          AppSpace.sm, 0, AppSpace.sm, AppSpace.xs),
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        '${missing.join(' and ')} not set a city yet. '
        'Settings → Where you are puts you both on the map.',
        style: AppText.caption(),
      ),
    );
  }
}

/// One of the two of you, where you actually are.
///
/// 🔴 The face and nothing else. It carried the name in a pill before, and
/// on a world map that is two paragraphs floating over Asia — at the zoom
/// this opens at, the pins are most of what is on screen. There are exactly
/// two people here and each of them knows both faces, so the label was
/// saying something neither of them needed told.
class _PersonMarker extends StatelessWidget {
  const _PersonMarker({required this.person});

  final UserProfile person;

  /// Google's pin shape: a round head over a point, the whole thing
  /// standing *on* the place rather than beside it.
  static const _head = 44.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _head,
          height: _head,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.brand, width: 2.5),
            boxShadow: AppElevation.card,
          ),
          // ⚠️ Clipped inside the ring rather than sized to it: a square
          // avatar behind a circular border shows its corners.
          child: ClipOval(child: UserAvatar(person, size: _head - 5)),
        ),
        // Overlaps the ring by a hair so the two read as one shape rather
        // than a circle with a triangle parked under it.
        Transform.translate(
          offset: const Offset(0, -2),
          child: const _Point(color: AppColors.brand),
        ),
      ],
    );
  }
}

/// The spike under a pin. Solid, unlike the hollow tail on a callout —
/// this one is the pin, not a speech bubble.
class _Point extends StatelessWidget {
  const _Point({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(14, 12),
      painter: _TailPainter(fill: color, edge: color),
    );
  }
}

/// How far apart, and how long it would take — sitting on the line.
class _JourneyLabel extends StatelessWidget {
  const _JourneyLabel({required this.journey});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    // Hung from the top of its marker, just under the line's midpoint.
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.brand),
          boxShadow: AppElevation.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(journey.distanceLabel, style: AppText.caption(AppColors.ink)),
            Text(
              // ⚠️ "about", because it is. See Journey.flight.
              'about ${journey.flightLabel}',
              style: AppText.label(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A place, drawn the way the design asks: the photo, then what it was.
class _PinCallout extends ConsumerWidget {
  const _PinCallout({required this.pin});

  final MapPin pin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => showPinSheet(context, pin),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                // A place you mean to go is drawn as an outline, not a
                // memory — the map has to say which is which at a glance.
                color: pin.visited ? AppColors.border : AppColors.secondary,
              ),
              boxShadow: AppElevation.card,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pin.messageId != null) _PinPhoto(messageId: pin.messageId!),
                if (pin.messageId != null) const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    pin.label,
                    style: AppText.caption(AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _Tail(color: pin.visited ? AppColors.border : AppColors.secondary),
        ],
      ),
    );
  }
}

/// The thumbnail on a pin, or nothing at all.
///
/// ⚠️ Renders nothing rather than a spinner or a broken-image box. A map
/// with eight pins on it would otherwise be eight spinners, and the label is
/// the part that carries the meaning anyway.
class _PinPhoto extends ConsumerWidget {
  const _PinPhoto({required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(pinPhotoPathProvider(messageId)).valueOrNull;
    if (path == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: StorageImage.dayPhoto(
        path,
        width: 26,
        height: 26,
        fit: BoxFit.cover,
        decodeWidth: 26,
        error: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

/// The little point under a callout, so it reads as belonging to the spot
/// beneath it rather than floating near it.
class _Tail extends StatelessWidget {
  const _Tail({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(12, 7),
      painter: _TailPainter(fill: AppColors.surface, edge: color),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.fill, required this.edge});

  final Color fill, edge;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) =>
      old.fill != fill || old.edge != edge;
}

/// A control floating on the map: a surface with a soft shadow, round for
/// a lone button, a pill for a label.
class _Floating extends StatelessWidget {
  const _Floating({required this.child, this.circle = false});

  final Widget child;
  final bool circle;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        elevation: 3,
        shadowColor: Colors.black26,
        shape: circle ? const CircleBorder() : const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

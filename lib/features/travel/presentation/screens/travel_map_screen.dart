import '../../../home/presentation/widgets/today_story.dart';
import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:dayflower/core/widgets/story_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
import '../../../tulip/data/flower_repository.dart';
import '../../data/map_pin_repository.dart';
import '../../domain/journey.dart';
import '../widgets/add_pin_sheet.dart';

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
class TravelMapScreen extends ConsumerStatefulWidget {
  const TravelMapScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  ConsumerState<TravelMapScreen> createState() => _TravelMapScreenState();
}

class _TravelMapScreenState extends ConsumerState<TravelMapScreen> {
  late int _tab = widget.initialTab;

  /// Where the map opens when there is nothing on it yet — far enough out
  /// that any two places in the world are both on screen.
  static const _wholeWorld = LatLng(20, 0);

  @override
  Widget build(BuildContext context) {
    final allPins = ref.watch(mapPinsProvider);
    final pins = (allPins.valueOrNull ?? const <MapPin>[])
        .where((p) => _tab == 0
            ? false
            : _tab == 1
                ? p.visited
                : !p.visited)
        .toList();
    final me = ref.watch(userProfileProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;

    final people = [
      if (_tab == 0 && me != null && me.hasPlace) me,
      if (_tab == 0 && partner != null && partner.hasPlace) partner,
    ];
    final journey = journeyBetween(me, partner);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IosBackButton(onTap: () => Navigator.of(context).maybePop()),
        title: Text('Our Map', style: AppText.title()),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        onPressed: () => showAddPinSheet(context, visited: _tab != 2),
        icon: const AppIcon(Icons.add_location_alt_outlined),
        label: const Text('Add a place'),
      ),
      body: Column(
        children: [
          Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpace.screenInset),
              child: Text(
                  'Where you are, where you’ve been and where you’re going.',
                  style: AppText.caption())),
          Padding(
              padding: const EdgeInsets.all(AppSpace.xs),
              child: Wrap(spacing: AppSpace.xs, children: [
                for (var i = 0; i < 3; i++)
                  ChoiceChip(
                      label: Text(['Now', 'Our Places', 'Next'][i]),
                      selected: _tab == i,
                      onSelected: (_) => setState(() => _tab = i)),
              ])),
          if (_tab == 0)
            const Padding(
                padding: EdgeInsets.all(AppSpace.sm),
                child: LocationPreview(openMap: false)),
          if (_tab != 0 && allPins.hasError)
            const Text('Your places couldn’t load. Please try again.'),
          if (_tab != 0 &&
              !allPins.isLoading &&
              !allPins.hasError &&
              pins.isEmpty)
            Padding(
                padding: const EdgeInsets.all(AppSpace.sm),
                child: Text(
                    _tab == 1
                        ? 'Add your first place together.'
                        : 'Where would you love to go together?',
                    style: AppText.body())),
          if (_tab != 0 && pins.isNotEmpty)
            SizedBox(
                height: 110 * MediaQuery.textScalerOf(context).scale(14) / 14,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final pin in pins)
                    SizedBox(
                        width: 280,
                        child: Padding(
                            padding: const EdgeInsets.all(AppSpace.xs),
                            child: UtilityRow(
                                icon: Icons.place_outlined,
                                title: pin.label,
                                subtitle: pin.place,
                                trailing: pin.visited
                                    ? const SizedBox.shrink()
                                    : TextButton(
                                        onPressed: () async {
                                          try {
                                            await ref
                                                .read(mapPinRepositoryProvider)
                                                .markVisited(pin.id);
                                          } catch (_) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          'That didn’t save. Try again.')));
                                            }
                                          }
                                        },
                                        child: const Text('We went!')))))
                ])),
          if (_tab == 0 && people.length < 2)
            _MissingPlaceNote(me: me, partner: partner),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: FlutterMap(
                key: ValueKey(_tab),
                options: MapOptions(
                  initialCenter: _openingCentre(pins, people),
                  initialZoom: pins.isEmpty && people.length < 2 ? 1.6 : 3.2,
                  // Nothing below 1.5 — zooming further out just tiles the
                  // world side by side, which reads as a rendering fault.
                  minZoom: 1.5,
                  maxZoom: 17,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    // ⚠️ Required by OSM's policy, and the thing that gets
                    // an app blocked when it is left as the default.
                    userAgentPackageName: 'com.dayflower.app',
                    tileProvider: NetworkTileProvider(),
                  ),
                  // 🔴 Under the markers, deliberately: a dotted line drawn
                  // over a face reads as a scratch on the photo.
                  if (journey != null && people.length == 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            LatLng(people[0].cityLat!, people[0].cityLon!),
                            LatLng(people[1].cityLat!, people[1].cityLon!),
                          ],
                          color: AppColors.brand,
                          strokeWidth: 2,
                          // ⚠️ Straight on screen, not the curve a plane
                          // actually flies. The great-circle path bends on a
                          // Mercator projection, and the honest-looking arc
                          // would need the line subdivided into dozens of
                          // points — for a picture of "there is a gap", the
                          // straight line is what people read fastest. The
                          // *distance* on it is great-circle and true.
                          pattern: const StrokePattern.dotted(),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (journey != null && people.length == 2)
                        Marker(
                          point: _midpoint(people),
                          width: 168,
                          height: 46,
                          child: _JourneyLabel(journey: journey),
                        ),
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
                          // whose width depends on the label — Marker needs
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
          ),
        ],
      ),
    );
  }

  /// Halfway along the drawn line, which is where the label belongs.
  ///
  /// ⚠️ The midpoint of the *straight* line, to match what is drawn — not
  /// the great-circle midpoint, which would sit off the line it labels.
  static LatLng _midpoint(List<UserProfile> people) => LatLng(
        (people[0].cityLat! + people[1].cityLat!) / 2,
        (people[0].cityLon! + people[1].cityLon!) / 2,
      );

  /// Opens on your pins if there are any, otherwise on the two of you.
  static LatLng _openingCentre(List<MapPin> pins, List<UserProfile> people) {
    final points = <LatLng>[
      for (final pin in pins) LatLng(pin.lat, pin.lon),
      for (final person in people) LatLng(person.cityLat!, person.cityLon!),
    ];
    if (points.isEmpty) return _wholeWorld;
    // ⚠️ A plain mean, not a great-circle midpoint. Two cities either side
    // of the date line would average to the wrong ocean — acceptable for an
    // opening camera position, and worth knowing before this is reused for
    // anything that has to be correct.
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b);
    final lon = points.map((p) => p.longitude).reduce((a, b) => a + b);
    return LatLng(lat / points.length, lon / points.length);
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
      margin:
          const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.sm, AppSpace.xs),
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        '${missing.join(' and ')} not set a city yet — '
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
    return Center(
      child: Container(
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
    final url = ref.watch(dayPhotoUrlProvider(path)).valueOrNull;
    if (url == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        width: 26,
        height: 26,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
  bool shouldRepaint(_TailPainter old) => old.fill != fill || old.edge != edge;
}

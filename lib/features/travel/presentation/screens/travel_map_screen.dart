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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IosBackButton(onTap: () => Navigator.of(context).maybePop()),
        title: Text('Travel map', style: AppText.title()),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        onPressed: () => showAddPinSheet(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add a place'),
      ),
      body: Column(
        children: [
          if (people.length < 2) _MissingPlaceNote(me: me, partner: partner),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: FlutterMap(
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
                  MarkerLayer(
                    markers: [
                      for (final person in people)
                        Marker(
                          point: LatLng(person.cityLat!, person.cityLon!),
                          width: 132,
                          height: 54,
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
      margin: const EdgeInsets.fromLTRB(
          AppSpace.sm, 0, AppSpace.sm, AppSpace.xs),
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
class _PersonMarker extends StatelessWidget {
  const _PersonMarker({required this.person});

  final UserProfile person;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.brand, width: 1.5),
            boxShadow: AppElevation.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(person, size: 24),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  person.petName ?? person.displayName,
                  style: AppText.caption(AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const _Tail(color: AppColors.brand),
      ],
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
  bool shouldRepaint(_TailPainter old) =>
      old.fill != fill || old.edge != edge;
}

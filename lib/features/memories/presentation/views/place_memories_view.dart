import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// ⚠️ latlong2 exports its own Path, which would shadow dart:ui's.
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/map/map_tiles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/storage_image.dart';
import '../../../travel/data/map_pin_repository.dart';
import '../../../tulip/data/flower_repository.dart';
import '../../../tulip/presentation/widgets/media_viewer.dart';
import '../../data/memory_views.dart';
import '../widgets/memory_category_tabs.dart';

/// Places: everywhere your story has been.
///
/// 🔴 History only. This is not Together's map: no live location, no
/// distance, nowhere you mean to go. Only places you have been and kept
/// something from, on a map of their own, and a row for each.
class PlaceMemoriesView extends StatefulWidget {
  const PlaceMemoriesView({
    super.key,
    required this.pins,
    required this.messages,
  });

  final List<MapPin> pins;

  /// For a place's photo, by the id its pin carries.
  final List<FlowerMessage> messages;

  @override
  State<PlaceMemoriesView> createState() => _PlaceMemoriesViewState();
}

class _PlaceMemoriesViewState extends State<PlaceMemoriesView> {
  PlaceSort _sort = PlaceSort.recent;

  @override
  Widget build(BuildContext context) {
    final places = placeMemories(widget.pins, sort: _sort);
    if (places.isEmpty) {
      return MemoryEmpty(title: MemoryCategory.places.emptyTitle);
    }
    final stories = places.fold<int>(0, (n, p) => n + p.pins.length);
    final byId = {for (final m in widget.messages) m.id: m};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlacesMemoryMap(places: places, stories: stories),
        const SizedBox(height: AppSpace.sm),
        Row(children: [
          Expanded(
            child: Text(
                '${places.length} place${places.length == 1 ? '' : 's'} together',
                style: AppText.subtitle(AppColors.ink)),
          ),
          PopupMenuButton<PlaceSort>(
            initialValue: _sort,
            onSelected: (sort) => setState(() => _sort = sort),
            color: AppColors.surface,
            itemBuilder: (_) => [
              for (final sort in PlaceSort.values)
                PopupMenuItem(
                  value: sort,
                  child:
                      Text(sort.label, style: AppText.body(AppColors.ink)),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Sort', style: AppText.caption(AppColors.body)),
                const SizedBox(width: 3),
                AppIcon(CupertinoIcons.chevron_down,
                    size: 12, color: AppColors.body),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.xs),
        for (final place in places)
          Padding(
            padding: const EdgeInsets.only(bottom: MemoriesStyle.gap),
            child: PlaceMemoryRow(
              place: place,
              photo: place.photoMessageId == null
                  ? null
                  : byId[place.photoMessageId],
            ),
          ),
      ],
    );
  }
}

/// The memory map: a heart for every place, joined in the order you went.
class PlacesMemoryMap extends StatelessWidget {
  const PlacesMemoryMap({
    super.key,
    required this.places,
    required this.stories,
  });

  final List<PlaceMemory> places;
  final int stories;

  @override
  Widget build(BuildContext context) {
    final points = [
      for (final p in places) LatLng(p.pins.first.lat, p.pins.first.lon),
    ];
    // The route in the order you went: oldest first.
    final route = [...places]
      ..sort((a, b) => a.pins.last.createdAt.compareTo(b.pins.last.createdAt));
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 180,
        child: Stack(children: [
          // ⚠️ Inert: it is a picture of where you have been, and a map
          // that ate the drag would stop the page from scrolling.
          Positioned.fill(
            child: IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: points.length == 1
                      ? null
                      : CameraFit.coordinates(
                          coordinates: points,
                          // Clear of the note in the top-left corner, so
                          // no heart lands under it.
                          padding: const EdgeInsets.fromLTRB(40, 88, 40, 30),
                          maxZoom: 6,
                        ),
                  initialCenter: points.first,
                  initialZoom: 4,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                  backgroundColor: AppColors.surfaceSubtle,
                ),
                children: [
                  MapTiles.layer(context, labelled: false),
                  if (route.length > 1)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: [
                          for (final p in route)
                            LatLng(p.pins.first.lat, p.pins.first.lon),
                        ],
                        color: AppColors.brand.withValues(alpha: .7),
                        strokeWidth: 2,
                        pattern: const StrokePattern.dotted(),
                      ),
                    ]),
                  MarkerLayer(markers: [
                    for (final point in points)
                      Marker(
                        point: point,
                        width: 26,
                        height: 26,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: AppElevation.card,
                          ),
                          child: const Icon(CupertinoIcons.heart_fill,
                              size: 12, color: Colors.white),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
          ),
          // A note pinned to the corner.
          Positioned(
            left: 12,
            top: 12,
            child: Transform.rotate(
              angle: -.05,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF4),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AppElevation.card,
                ),
                child: Text(
                  '${places.length} place${places.length == 1 ? '' : 's'}\n'
                  '$stories stor${stories == 1 ? 'y' : 'ies'} ♡',
                  style: AppText.note(const Color(0xFF5E4A6E))
                      .copyWith(fontSize: 12.5, height: 1.25),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: MapTiles.attribution(),
          ),
        ]),
      ),
    );
  }
}

/// One place: its picture, its name and country, when, and what you kept.
class PlaceMemoryRow extends ConsumerWidget {
  const PlaceMemoryRow({super.key, required this.place, this.photo});

  final PlaceMemory place;

  /// The newest photo taken there, when a pin carries one.
  final FlowerMessage? photo;

  String get _counts {
    final stories = place.pins.length;
    final photos = place.photos;
    return [
      '$stories stor${stories == 1 ? 'y' : 'ies'}',
      if (photos > 0) '$photos photo${photos == 1 ? '' : 's'}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picture = photo;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(MemoriesStyle.tileRadius),
      child: InkWell(
        onTap: picture == null
            ? null
            : () => showPhotoMessage(context, ref, picture),
        borderRadius: BorderRadius.circular(MemoriesStyle.tileRadius),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MemoriesStyle.tileRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 68,
                height: 54,
                child: picture?.imagePath == null
                    ? _NoPhoto()
                    : StorageImage.dayPhoto(
                        picture!.imagePath!,
                        width: 68,
                        height: 54,
                        fit: BoxFit.cover,
                        decodeWidth: 68,
                        semanticLabel: place.name,
                        error: (_) => _NoPhoto(),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MemoriesStyle.itemTitle()),
                  if (place.region.isNotEmpty)
                    Text(place.region,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MemoriesStyle.itemMeta()),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMM y').format(place.latest),
                      maxLines: 1, style: MemoriesStyle.tileMeta()),
                  Text(_counts,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MemoriesStyle.tileMeta()),
                ],
              ),
            ),
            if (picture != null)
              AppIcon(CupertinoIcons.chevron_right,
                  size: 15, color: AppColors.muted)
            else
              const SizedBox(width: 15),
          ]),
        ),
      ),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: MemoriesStyle.givenTint,
        alignment: Alignment.center,
        child: const AppIcon(CupertinoIcons.location,
            size: 20, color: AppColors.brand),
      );
}

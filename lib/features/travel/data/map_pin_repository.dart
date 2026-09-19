import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';

/// One place on the couple's map. See migration 0047.
class MapPin {
  const MapPin({
    required this.id,
    required this.pairId,
    required this.createdBy,
    required this.label,
    required this.place,
    required this.lat,
    required this.lon,
    required this.visited,
    required this.createdAt,
    this.messageId,
  });

  final String id;
  final String pairId;
  final String createdBy;

  /// What the pin says on the map — "Beach day", not the city name.
  final String label;

  /// Where the city picker put it, for the line under the label.
  final String place;

  final double lat;
  final double lon;

  /// Somewhere you have been, or somewhere you mean to go.
  final bool visited;

  final DateTime createdAt;

  /// The photo behind the pin, when it has one.
  ///
  /// ⚠️ Nullable twice over: a pin can be dropped without a photo, and the
  /// column is `set null` so deleting the photo leaves the place on the map
  /// rather than taking it down with it.
  final String? messageId;

  factory MapPin.fromMap(Map<String, dynamic> map) => MapPin(
        id: map['id'] as String,
        pairId: map['pair_id'] as String,
        createdBy: map['created_by'] as String,
        label: map['label'] as String? ?? '',
        place: map['place'] as String? ?? '',
        lat: (map['lat'] as num).toDouble(),
        lon: (map['lon'] as num).toDouble(),
        visited: map['visited'] as bool? ?? true,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        messageId: map['message_id'] as String?,
      );
}

class MapPinRepository {
  MapPinRepository(this._client);

  final SupabaseClient _client;

  /// Every pin on the pair's map, live, oldest first.
  ///
  /// Ascending on purpose: the map reads as a history, and a list that
  /// reorders itself as pins arrive is harder to follow than one that grows
  /// at the end.
  Stream<List<MapPin>> watchPair(String pairId) {
    return _client
        .from('map_pins')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .order('created_at')
        .map((rows) => rows.map(MapPin.fromMap).toList());
  }

  Future<void> add({
    required String pairId,
    required String createdBy,
    required String label,
    required String place,
    required double lat,
    required double lon,
    bool visited = true,
    String? messageId,
  }) async {
    await _client.from('map_pins').insert({
      'pair_id': pairId,
      'created_by': createdBy,
      'label': label.trim(),
      'place': place,
      'lat': lat,
      'lon': lon,
      'visited': visited,
      if (messageId != null) 'message_id': messageId,
    });
  }

  /// ⚠️ Either of them can remove any pin — the map is a thing they build
  /// together, not two private maps drawn on one sheet. See the policies in
  /// 0047.
  Future<void> markVisited(String id) =>
      _client.from('map_pins').update({'visited': true}).eq('id', id);

  Future<void> remove(String id) async {
    await _client.from('map_pins').delete().eq('id', id);
  }

  Future<void> rename({required String id, required String label}) async {
    await _client.from('map_pins').update({'label': label.trim()}).eq('id', id);
  }
}

final mapPinRepositoryProvider = Provider<MapPinRepository>((ref) {
  return MapPinRepository(ref.watch(supabaseClientProvider));
});

/// The pins on the open map. Empty until paired.
final mapPinsProvider = StreamProvider.autoDispose<List<MapPin>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(mapPinRepositoryProvider).watchPair(pair.id);
});

/// The storage path of the photo behind a pin, if it still has one.
///
/// ⚠️ Its own small query rather than a join on the stream. The map holds a
/// handful of pins and most have no photo; reaching through `flower_messages`
/// on every emission would fetch the whole thread to draw a thumbnail.
final pinPhotoPathProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, messageId) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final row = await client
        .from('flower_messages')
        .select('image_path')
        .eq('id', messageId)
        .maybeSingle();
    return row?['image_path'] as String?;
  } catch (_) {
    // A pin whose photo cannot be resolved still belongs on the map.
    return null;
  }
});

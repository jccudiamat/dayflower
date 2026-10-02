import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/widgets/storage_image.dart';
import '../../pairing/data/pair_repository.dart';
import '../../tulip/data/flower_repository.dart' show dayPhotoBucket;

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
    this.photoPath,
    this.visitedOn,
    this.note,
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

  /// A photo of its own, uploaded with the pin (migration 0055), in the
  /// day_photos bucket under the pair's folder. Wins over [messageId].
  final String? photoPath;

  /// When they were there, when somebody said. A date, not an instant.
  final DateTime? visitedOn;

  /// What it was, in a few words more than the label.
  final String? note;

  /// Whether the map draws it as a photo rather than a label.
  bool get hasPhoto => photoPath != null || messageId != null;

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
        photoPath: map['photo_path'] as String?,
        visitedOn: _date(map['visited_on']),
        note: (map['note'] as String?)?.trim().isEmpty ?? true
            ? null
            : (map['note'] as String).trim(),
      );

  static DateTime? _date(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    final at = DateTime.tryParse(raw);
    return at == null ? null : DateTime(at.year, at.month, at.day);
  }
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

  /// Drops a pin. [photo] is uploaded first, as the pin's own picture,
  /// under the pair's folder in day_photos (0013's policies cover it).
  ///
  /// ⚠️ The new columns (0055) are sent only when they have something in
  /// them, so a pin without a photo, date or note still saves against a
  /// database that does not have them yet.
  Future<void> add({
    required String pairId,
    required String createdBy,
    required String label,
    required String place,
    required double lat,
    required double lon,
    bool visited = true,
    String? messageId,
    Uint8List? photo,
    DateTime? visitedOn,
    String? note,
  }) async {
    String? photoPath;
    if (photo != null) {
      photoPath = '$pairId/pin-${_id()}.jpg';
      await _client.storage.from(dayPhotoBucket).uploadBinary(photoPath, photo,
          fileOptions: const FileOptions(contentType: 'image/jpeg'));
      // Already on this phone: the pin draws from it, not a download.
      await StorageImageCache.prime(StorageBucket.dayPhotos, photoPath, photo);
    }
    final words = note?.trim() ?? '';
    try {
      await _client.from('map_pins').insert({
        'pair_id': pairId,
        'created_by': createdBy,
        'label': label.trim(),
        'place': place,
        'lat': lat,
        'lon': lon,
        'visited': visited,
        if (messageId != null) 'message_id': messageId,
        if (photoPath != null) 'photo_path': photoPath,
        if (visitedOn != null)
          'visited_on':
              '${visitedOn.year.toString().padLeft(4, '0')}-${visitedOn.month.toString().padLeft(2, '0')}-${visitedOn.day.toString().padLeft(2, '0')}',
        if (words.isNotEmpty) 'note': words,
      });
    } catch (_) {
      // No pin to show it: the photo just uploaded would be bytes nobody
      // can reach, kept and paid for.
      if (photoPath != null) await _removePhoto(photoPath);
      rethrow;
    }
  }

  /// ⚠️ Either of them can remove any pin — the map is a thing they build
  /// together, not two private maps drawn on one sheet. See the policies in
  /// 0047.
  ///
  /// Its own photo goes with it, when the one removing it is the one who
  /// uploaded it (0013 lets only the owner delete). A pin's chat photo
  /// ([MapPin.messageId]) belongs to the chat and stays.
  Future<void> remove(MapPin pin) async {
    await _client.from('map_pins').delete().eq('id', pin.id);
    final path = pin.photoPath;
    if (path != null) await _removePhoto(path);
  }

  Future<void> _removePhoto(String path) async {
    try {
      await _client.storage.from(dayPhotoBucket).remove([path]);
    } catch (_) {
      // Not theirs to delete, or offline: the bytes stay, the pin is gone.
    }
  }

  static String _id() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<void> rename({required String id, required String label}) async {
    await _client
        .from('map_pins')
        .update({'label': label.trim()}).eq('id', id);
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

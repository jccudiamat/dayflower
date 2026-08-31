import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';

class Reunion {
  const Reunion({
    required this.id,
    required this.pairId,
    required this.title,
    this.destination,
    required this.happensAt,
    this.note,
  });

  final String id;
  final String pairId;
  final String title;
  final String? destination;
  final DateTime happensAt;
  final String? note;

  factory Reunion.fromMap(Map<String, dynamic> map) => Reunion(
        id: map['id'] as String,
        pairId: map['pair_id'] as String,
        title: map['title'] as String? ?? 'Reunion',
        destination: map['destination'] as String?,
        happensAt: DateTime.parse(map['happens_at'] as String).toLocal(),
        note: map['note'] as String?,
      );
}

class ReunionRepository {
  ReunionRepository(this._client);
  final SupabaseClient _client;

  /// The pair's single reunion row (or null), live-updating.
  Stream<Reunion?> watchReunion(String pairId) {
    return _client
        .from('reunions')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .map((rows) => rows.isEmpty ? null : Reunion.fromMap(rows.first));
  }

  /// Create or replace the pair's reunion (one row per pair).
  Future<void> save({
    required String pairId,
    required String title,
    String? destination,
    required DateTime happensAt,
    String? note,
  }) async {
    await _client.from('reunions').upsert(
      {
        'pair_id': pairId,
        'title': title.trim().isEmpty ? 'Reunion' : title.trim(),
        'destination':
            (destination == null || destination.trim().isEmpty)
                ? null
                : destination.trim(),
        'happens_at': happensAt.toUtc().toIso8601String(),
        'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'pair_id',
    );
  }
}

final reunionRepositoryProvider = Provider<ReunionRepository>((ref) {
  return ReunionRepository(ref.watch(supabaseClientProvider));
});

/// Live reunion for the couple. Null until one is set (or before pairing).
final reunionProvider = StreamProvider.autoDispose<Reunion?>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(null);
  return ref.watch(reunionRepositoryProvider).watchReunion(pair.id);
});

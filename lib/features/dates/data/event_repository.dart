import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';

class EventRepository {
  EventRepository(this.client);
  final SupabaseClient client;

  Stream<List<Map<String, dynamic>>> watch(String pairId) => client
      .from('couple_events')
      .stream(primaryKey: ['pair_id', 'id'])
      .eq('pair_id', pairId)
      .order('date');

  Future<void> save(String pairId, Map<String, dynamic> event) async {
    await client
        .from('couple_events')
        .upsert({...event, 'pair_id': pairId}, onConflict: 'pair_id,id');
  }

  Future<void> delete(String pairId, int id) async {
    await client
        .from('couple_events')
        .delete()
        .eq('pair_id', pairId)
        .eq('id', id);
  }
}

final eventRepositoryProvider = Provider<EventRepository>(
    (ref) => EventRepository(ref.watch(supabaseClientProvider)));

final customEventsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(eventRepositoryProvider).watch(pair.id);
});

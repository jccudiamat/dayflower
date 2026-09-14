import 'package:dayflower/features/dates/data/event_repository.dart';
import 'package:dayflower/features/gifts/data/gift_favorites_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient offlineClient() => SupabaseClient('https://example.test', 'test',
    authOptions: const AuthClientOptions(autoRefreshToken: false));

class MemoryEvents extends EventRepository {
  MemoryEvents() : super(offlineClient());
  final rows = <String, Map<int, Map<String, dynamic>>>{};
  bool failWrites = false;
  @override
  Stream<List<Map<String, dynamic>>> watch(String pairId) =>
      Stream.value(rows[pairId]?.values.toList() ?? []);
  @override
  Future<void> save(String pairId, Map<String, dynamic> event) async {
    if (failWrites) throw StateError('Offline');
    (rows[pairId] ??= {})[event['id'] as int] = {...event};
  }

  @override
  Future<void> delete(String pairId, int id) async {
    if (failWrites) throw StateError('Offline');
    rows[pairId]?.remove(id);
  }
}

class MemoryFavorites extends GiftFavoritesRepository {
  MemoryFavorites() : super(offlineClient());
  final rows = <String, Set<String>>{};
  bool failWrites = false;
  @override
  Future<Set<String>> load(String userId) async => {...?rows[userId]};
  @override
  Future<void> setSaved(String userId, String productId, bool saved) async {
    if (failWrites) throw StateError('Offline');
    final ids = rows[userId] ??= {};
    saved ? ids.add(productId) : ids.remove(productId);
  }
}

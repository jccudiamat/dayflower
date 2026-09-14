import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';

class GiftFavoritesRepository {
  GiftFavoritesRepository(this.client);
  final SupabaseClient client;

  Future<Set<String>> load(String userId) async {
    final rows = await client
        .from('gift_favorites')
        .select('product_id')
        .eq('user_id', userId);
    return rows.map((row) => row['product_id'] as String).toSet();
  }

  Future<void> setSaved(String userId, String productId, bool saved) async {
    if (saved) {
      await client.from('gift_favorites').upsert(
          {'user_id': userId, 'product_id': productId},
          onConflict: 'user_id,product_id');
    } else {
      await client
          .from('gift_favorites')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
    }
  }
}

final giftFavoritesRepositoryProvider = Provider<GiftFavoritesRepository>(
    (ref) => GiftFavoritesRepository(ref.watch(supabaseClientProvider)));

class GiftFavorites extends AutoDisposeAsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return <String>{};
    return ref.watch(giftFavoritesRepositoryProvider).load(userId);
  }

  Future<void> toggle(String productId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || !state.hasValue) {
      throw StateError('Favorites unavailable');
    }
    final saved = !state.requireValue.contains(productId);
    final keepAlive = ref.keepAlive();
    try {
      await ref
          .read(giftFavoritesRepositoryProvider)
          .setSaved(userId, productId, saved);
      if (ref.read(currentUserIdProvider) != userId) return;
      final updated = {...state.requireValue};
      saved ? updated.add(productId) : updated.remove(productId);
      state = AsyncData(updated);
    } finally {
      keepAlive.close();
    }
  }
}

final giftFavoritesProvider =
    AsyncNotifierProvider.autoDispose<GiftFavorites, Set<String>>(
        GiftFavorites.new);

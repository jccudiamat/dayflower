import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import 'gift_catalog.dart';

/// Reads the live gift catalogue and records what gets opened.
class GiftRepository {
  GiftRepository(this._client);
  final SupabaseClient _client;

  /// Everything still on sale, in display order.
  Future<List<GiftProduct>> catalogue() async {
    final rows = await _client
        .from('gift_products')
        .select()
        .eq('active', true)
        .order('sort', ascending: true)
        .order('name', ascending: true);
    return (rows as List).map((r) => GiftProduct.fromMap(r)).toList();
  }

  /// Notes that a gift was opened.
  ///
  /// ⚠️ Never awaited by the caller and never allowed to fail loudly: this is
  /// bookkeeping, and a gift that would not open because the *logging* broke
  /// is a worse outcome than a click nobody counted.
  Future<void> logClick(String productId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('gift_clicks').insert({
      'product_id': productId,
      'user_id': userId,
    });
  }
}

final giftRepositoryProvider = Provider<GiftRepository>((ref) {
  return GiftRepository(ref.watch(supabaseClientProvider));
});

/// The catalogue the screen shows.
///
/// 🔴 **Falls back to the bundled list rather than to an empty screen.** The
/// gifts page with nothing on it looks like a broken feature; the same page
/// with a slightly stale price looks like a page. On a dead network, a first
/// run, or a table nobody has seeded yet, the shipped snapshot is the better
/// of the two.
final giftCatalogProvider = FutureProvider<List<GiftProduct>>((ref) async {
  try {
    final live = await ref.watch(giftRepositoryProvider).catalogue();
    return live.isEmpty ? giftProducts : live;
  } catch (_) {
    return giftProducts;
  }
});

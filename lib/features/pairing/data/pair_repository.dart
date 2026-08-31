import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/pair.dart';
import '../../../core/providers/supabase_provider.dart';

class PairRepository {
  PairRepository(this._client);
  final SupabaseClient _client;

  // Excludes ambiguous characters (0/O, 1/I) since it's typed by hand.
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final _random = Random.secure();

  String _generateCode() => List.generate(
        6,
        (_) => _codeChars[_random.nextInt(_codeChars.length)],
      ).join();

  Future<Pair?> getMyPair(String userId) async {
    final rows = await _client
        .from('pairs')
        .select()
        .or('user_a.eq.$userId,user_b.eq.$userId')
        .order('created_at');
    if (rows.isEmpty) return null;
    // Prefer a fully-linked pair over a still-open invite of our own.
    final linked = rows.firstWhere(
      (r) => r['user_b'] != null,
      orElse: () => rows.first,
    );
    return Pair.fromMap(linked);
  }

  /// Returns the caller's existing invite, or creates a new one.
  Future<Pair> ensureMyInvite(String userId) async {
    final existing = await getMyPair(userId);
    if (existing != null) return existing;

    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final row = await _client
            .from('pairs')
            .insert({'user_a': userId, 'invite_code': _generateCode()})
            .select()
            .single();
        return Pair.fromMap(row);
      } on PostgrestException catch (e) {
        if (e.code == '23505' && attempt < 4) continue; // code clash — retry
        rethrow;
      }
    }
    throw Exception('Could not generate an invite code. Please try again.');
  }

  /// Links the caller as user_b on the pair matching [code].
  Future<Pair> acceptInvite({required String code, required String userId}) async {
    final invite = await _client
        .from('pairs')
        .select()
        .eq('invite_code', code.trim().toUpperCase())
        .isFilter('user_b', null)
        .maybeSingle();

    if (invite == null) {
      throw Exception("That code doesn't match an open invite.");
    }
    if (invite['user_a'] == userId) {
      throw Exception("You can't enter your own code.");
    }

    final row = await _client
        .from('pairs')
        .update({'user_b': userId})
        .eq('id', invite['id'])
        .isFilter('user_b', null)
        .select()
        .single();
    return Pair.fromMap(row);
  }

  /// Deletes the pair. Cascades to flower_messages, heartbeats and
  /// reunions — this erases the couple's shared history, so callers must
  /// confirm destructively before invoking.
  Future<void> disconnect(String pairId) async {
    await _client.from('pairs').delete().eq('id', pairId);
  }

  /// Emits whenever the caller's own invite row changes (e.g. partner joins).
  Stream<Pair?> watchMyInvite(String userId) {
    return _client
        .from('pairs')
        .stream(primaryKey: ['id'])
        .eq('user_a', userId)
        .map((rows) => rows.isEmpty ? null : Pair.fromMap(rows.first));
  }
}

final pairRepositoryProvider = Provider<PairRepository>((ref) {
  return PairRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's pair, or null if not invited/paired yet.
/// Re-run with `ref.invalidate(currentPairProvider)` after pairing actions.
final currentPairProvider = FutureProvider<Pair?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(pairRepositoryProvider).getMyPair(userId);
});

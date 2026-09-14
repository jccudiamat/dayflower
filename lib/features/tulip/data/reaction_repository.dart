import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';

/// One mark, by one person, on one message. See migration 0045.
class MessageReaction {
  const MessageReaction({
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  final String messageId;
  final String userId;
  final String emoji;

  factory MessageReaction.fromMap(Map<String, dynamic> map) => MessageReaction(
        messageId: map['message_id'] as String,
        userId: map['user_id'] as String,
        emoji: map['emoji'] as String,
      );
}

/// What tapping [tapped] should do, given the reaction you already have on
/// this message ([mine], null if none).
///
/// The same rule as the mood chip: the same thing twice is how you say
/// "never mind". Anything you can say about yourself you must be able to
/// take back, and a reaction that could only ever be added would leave
/// somebody stuck laughing at a message that stopped being funny.
bool tapRemoves({required String? mine, required String tapped}) =>
    mine == tapped;

class ReactionRepository {
  ReactionRepository(this._client);

  final SupabaseClient _client;

  /// Every reaction on the pair's thread, live.
  ///
  /// One subscription for the whole conversation rather than one per
  /// message — which is why the row carries `pair_id` at all (0045).
  Stream<List<MessageReaction>> watchPair(String pairId) {
    return _client
        .from('message_reactions')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .map((rows) => rows.map(MessageReaction.fromMap).toList());
  }

  /// Sets or moves your mark on a message.
  ///
  /// ⚠️ `onConflict` names the unique pair, not the primary key. Without it
  /// this inserts a second row for the same person and the bubble shows them
  /// reacting twice — the key it would otherwise use is a generated uuid,
  /// which never collides.
  Future<void> set({
    required String pairId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _client.from('message_reactions').upsert(
      {
        'pair_id': pairId,
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
        'reacted_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'message_id,user_id',
    );
  }

  Future<void> clear({
    required String messageId,
    required String userId,
  }) async {
    await _client
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId);
  }
}

final reactionRepositoryProvider = Provider<ReactionRepository>((ref) {
  return ReactionRepository(ref.watch(supabaseClientProvider));
});

/// Reactions on the open conversation, grouped by message id.
///
/// Grouped here rather than in the bubble so the thread walks the list once
/// instead of once per message — a filter inside the bubble would be
/// quadratic in a long thread that has been reacted to a lot.
final reactionsProvider =
    StreamProvider.autoDispose<Map<String, List<MessageReaction>>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null) return Stream.value(const {});
  return ref.watch(reactionRepositoryProvider).watchPair(pair.id).map((all) {
    final byMessage = <String, List<MessageReaction>>{};
    for (final reaction in all) {
      byMessage.putIfAbsent(reaction.messageId, () => []).add(reaction);
    }
    return byMessage;
  });
});

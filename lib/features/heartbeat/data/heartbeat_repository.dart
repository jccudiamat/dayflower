import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';

class Heartbeat {
  const Heartbeat({
    required this.id,
    required this.senderId,
    required this.sentAt,
  });

  final String id;
  final String senderId;
  final DateTime sentAt;

  factory Heartbeat.fromMap(Map<String, dynamic> map) => Heartbeat(
        id: map['id'] as String,
        senderId: map['sender_id'] as String,
        sentAt: DateTime.parse(map['sent_at'] as String).toLocal(),
      );
}

class HeartbeatRepository {
  HeartbeatRepository(this._client);
  final SupabaseClient _client;

  /// Recent heartbeats for the pair, live. Limited window — the UI only
  /// needs today's taps.
  ///
  /// Descending is load-bearing next to `.limit(500)`: it is what makes this
  /// the 500 *newest* taps rather than the 500 oldest. Stated explicitly
  /// because it is also the silent default — see the note on
  /// `FlowerRepository.watchPairFlowers`, where relying on that default
  /// inverted the entire chat.
  Stream<List<Heartbeat>> watchRecent(String pairId) {
    return _client
        .from('heartbeats')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .order('sent_at', ascending: false)
        .limit(500)
        .map((rows) => rows.map(Heartbeat.fromMap).toList());
  }

  /// Fire-and-forget tap. No await needed by callers.
  Future<void> send({required String pairId, required String senderId}) {
    return _client
        .from('heartbeats')
        .insert({'pair_id': pairId, 'sender_id': senderId});
  }
}

final heartbeatRepositoryProvider = Provider<HeartbeatRepository>((ref) {
  return HeartbeatRepository(ref.watch(supabaseClientProvider));
});

/// Live list of recent heartbeats for the couple. Empty until paired.
final heartbeatsProvider =
    StreamProvider.autoDispose<List<Heartbeat>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(heartbeatRepositoryProvider).watchRecent(pair.id);
});

bool _isToday(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

/// (mine, partner's) tap counts for today, local time.
final todayHeartbeatCountsProvider =
    Provider.autoDispose<({int mine, int partner})>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final beats = ref.watch(heartbeatsProvider).valueOrNull ?? const [];
  var mine = 0;
  var partner = 0;
  for (final b in beats) {
    if (!_isToday(b.sentAt)) continue;
    if (b.senderId == userId) {
      mine++;
    } else {
      partner++;
    }
  }
  return (mine: mine, partner: partner);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';

/// The four numbers on the Us page, plus the two that feed them.
class CoupleStats {
  const CoupleStats({
    this.hearts = 0,
    this.flowers = 0,
    this.photos = 0,
    this.messages = 0,
    this.streak = 0,
  });

  /// Heartbeats sent between you, ever — both directions.
  final int hearts;

  /// Flowers sent, ever. Not photos and not text.
  final int flowers;

  /// Day photos and booth strips.
  final int photos;

  /// Every row in the thread, of any kind.
  final int messages;

  /// Consecutive days, counting back from today, with *anything* exchanged.
  final int streak;

  factory CoupleStats.fromMap(Map<String, dynamic> map) => CoupleStats(
        hearts: _int(map['hearts']),
        flowers: _int(map['flowers']),
        photos: _int(map['photos']),
        messages: _int(map['messages']),
        streak: _int(map['streak']),
      );

  /// `count(*)` comes back as a bigint, which PostgREST may render as a
  /// JSON number or, past 2^53, as a string. Neither will ever happen to a
  /// couple's heartbeat count, but the cast that assumes it cannot is the
  /// kind that throws once and takes the whole card with it.
  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

/// Everything the Us page counts, in one round trip.
///
/// ⚠️ **Deliberately not computed from the app's existing streams.** The
/// heartbeat stream is capped at the newest 500 taps, so a client-side
/// total would quietly stop at 500 and the couple's number would look like
/// it had plateaued — which is exactly the sort of wrong that nobody
/// reports because it looks plausible. `couple_stats` (migration 0021)
/// counts in Postgres, through the caller's own RLS.
final coupleStatsProvider = FutureProvider.autoDispose<CoupleStats>((ref) async {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return const CoupleStats();

  final client = ref.watch(supabaseClientProvider);
  final rows = await client.rpc<List<dynamic>>(
    'couple_stats',
    params: {
      'p_pair': pair.id,
      // The streak is counted in whole days, and which day it is differs
      // between Manila and Dubai. Sending the reader's own offset is what
      // stops a couple watching their streak break at 4am.
      'p_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
    },
  );
  if (rows.isEmpty) return const CoupleStats();
  return CoupleStats.fromMap((rows.first as Map).cast<String, dynamic>());
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';
import 'activity_models.dart';

/// Reads the feed and moves this person's "caught up to here" watermark.
///
/// There is no write path for activities and there is not meant to be —
/// every row arrives from a database trigger, and 0019 grants clients
/// `select` only. If something needs to appear in the feed, it gets a
/// trigger, not a method here.
class ActivityRepository {
  ActivityRepository(this._client);
  final SupabaseClient _client;

  /// How much of the timeline "View all" is willing to load.
  ///
  /// Not paginated: a couple generates a handful of these a day, so a
  /// thousand rows is years away, and a scroll-to-load on a live stream is
  /// real complexity to buy nothing anyone will reach.
  static const feedLimit = 200;

  /// The pair's activities, **newest first**, live-updating.
  ///
  /// `ascending: false` is spelled out for the same reason as in
  /// `FlowerRepository.watchPairFlowers`: a bare `.order('created_at')`
  /// reads as oldest-first and is not, which is exactly how the chat thread
  /// once ended up rendering upside down.
  Stream<List<Activity>> watchPair(String pairId) {
    return _client
        .from('activities')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .order('created_at', ascending: false)
        .limit(feedLimit)
        .map((rows) => rows.map(Activity.fromMap).toList(growable: false));
  }

  /// When this person last looked at the feed.
  Future<DateTime?> lastSeen({
    required String pairId,
    required String userId,
  }) async {
    final row = await _client
        .from('activity_reads')
        .select('last_seen_at')
        .eq('pair_id', pairId)
        .eq('user_id', userId)
        .maybeSingle();
    final value = row?['last_seen_at'] as String?;
    return value == null ? null : DateTime.parse(value).toLocal();
  }

  /// Marks everything up to now as read.
  ///
  /// A watermark rather than a per-row flag: there are two readers and the
  /// feed is only ever read newest-first, so one timestamp answers the badge
  /// and stays one row for the life of the pair.
  Future<void> markSeen({
    required String pairId,
    required String userId,
  }) async {
    await _client.from('activity_reads').upsert(
      {
        'pair_id': pairId,
        'user_id': userId,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'pair_id,user_id',
    );
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(supabaseClientProvider));
});

/// The whole feed, newest first. Empty until paired.
final activityFeedProvider =
    StreamProvider.autoDispose<List<Activity>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(activityRepositoryProvider).watchPair(pair.id);
});

/// Three, as asked for. Enough to be worth a glance, few enough that the
/// section never pushes the rest of Home off the screen.
const homeFeedCount = 3;

/// What Home shows: the three most recent.
///
/// Keeps the [AsyncValue] rather than flattening to a list. A failed load
/// and an empty feed are different things and `valueOrNull ?? []` renders
/// them identically — as "nothing has happened yet", which is a claim the
/// app has no business making when the query never came back.
final recentActivitiesProvider =
    Provider.autoDispose<AsyncValue<List<Activity>>>((ref) {
  return ref.watch(activityFeedProvider).whenData(
        (all) => all.take(homeFeedCount).toList(growable: false),
      );
});

/// This person's read watermark. Refreshed by invalidating, not streamed —
/// `activity_reads` is not in the realtime publication and does not need to
/// be: the only writer of your own row is your own phone.
final activityLastSeenProvider =
    FutureProvider.autoDispose<DateTime?>((ref) async {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  final userId = ref.watch(currentUserIdProvider);
  if (pair == null || !pair.isLinked || userId == null) return null;
  return ref
      .watch(activityRepositoryProvider)
      .lastSeen(pairId: pair.id, userId: userId);
});

/// How many activities the partner has caused that this person hasn't seen.
///
/// Your own actions never count. You know you set the reminder — a badge
/// telling you about it is the app reporting your own keystrokes back to
/// you.
final unseenActivityCountProvider = Provider.autoDispose<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final activities = ref.watch(activityFeedProvider).valueOrNull ?? const [];
  final seenAsync = ref.watch(activityLastSeenProvider);

  // Still loading the watermark: show nothing rather than flashing every
  // activity as new and then clearing a moment later.
  if (seenAsync.isLoading) return 0;
  final seen = seenAsync.valueOrNull;

  return activities
      .where((a) => !a.isMine(userId) && a.actorId != null)
      .where((a) => seen == null || a.createdAt.isAfter(seen))
      .length;
});

/// Marks the feed read and refreshes the badge.
Future<void> markActivityFeedSeen(WidgetRef ref) async {
  final pair = ref.read(currentPairProvider).valueOrNull;
  final userId = ref.read(currentUserIdProvider);
  if (pair == null || !pair.isLinked || userId == null) return;
  try {
    await ref
        .read(activityRepositoryProvider)
        .markSeen(pairId: pair.id, userId: userId);
  } catch (_) {
    // A failed watermark write means the badge stays up. That is the right
    // failure: the alternative is clearing it locally and telling someone
    // they have seen something the database still says they haven't.
    return;
  }
  ref.invalidate(activityLastSeenProvider);
}

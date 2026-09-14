import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';
import '../domain/presence.dart';
import 'device_presence.dart';

/// Who is around, and when they last were.
///
/// ⚠️ Nothing here is a *heartbeat*, and the word is avoided on purpose.
/// `features/heartbeat` is the other thing entirely — the heart you tap to
/// make their phone buzz. This is a silent once-a-minute ping nobody sees.
/// The two classes were both called `Heartbeat`, both imported by app.dart,
/// and only compiled because neither was named there.
///
/// See migration 0043 for why this is its own table and not a column on
/// `users`: a once-a-minute write to a row that is in the realtime
/// publication would push the whole profile to the other phone every minute
/// of the day, for a value nobody reads unless the chat is open.
class PresenceRepository {
  PresenceRepository(this._client);

  final SupabaseClient _client;

  /// Records that this person is using the app, right now.
  Future<void> markActive(String userId) async {
    await _client.from('presence').upsert(
      {
        'user_id': userId,
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  /// When they last had the app open, or null if they never have.
  Future<DateTime?> lastActive(String userId) async {
    final row = await _client
        .from('presence')
        .select('last_active_at')
        .eq('user_id', userId)
        .maybeSingle();
    final value = row?['last_active_at'] as String?;
    return value == null ? null : DateTime.parse(value).toLocal();
  }
}

final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  return PresenceRepository(ref.watch(supabaseClientProvider));
});

/// How often the header re-asks. Only while something is watching it.
const _pollEvery = Duration(seconds: 30);

/// When the partner was last using the app, re-read while you are looking.
///
/// ⚠️ **Polled, not streamed, and `autoDispose` is the point.** The timer is
/// created by the read and cancelled when the last watcher goes away, so an
/// app sitting on the home screen makes no presence requests at all. Closing
/// the conversation stops the cost dead.
final partnerLastActiveProvider =
    FutureProvider.autoDispose<DateTime?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final pair = ref.watch(currentPairProvider).valueOrNull;
  final partnerId = pair?.partnerIdFor(userId ?? '');
  if (userId == null || partnerId == null) return null;

  final timer = Timer(_pollEvery, ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  try {
    return await ref.watch(presenceRepositoryProvider).lastActive(partnerId);
  } catch (_) {
    // A dead connection is not evidence about where they are. Saying nothing
    // beats a header that claims they have been gone since Tuesday.
    return null;
  }
});

/// Pings while somebody is actually in the app.
///
/// Owned by the root widget rather than by the chat screen: "active" has to
/// mean using the app, not sitting on this one screen, or the header would
/// say a partner who is looking at your photos is not there.
///
/// ⚠️ Being resumed is necessary and **not sufficient** — every ping is
/// gated on [shouldClaimPresence], which is where the two ways this lied
/// are written down. The timer deliberately keeps running through a refused
/// ping rather than stopping: unlocking the phone raises no lifecycle event
/// to restart it, so the next tick has to be the thing that notices.
class PresencePinger {
  PresencePinger(this._ref);

  final Ref _ref;
  Timer? _timer;

  /// Safe to call repeatedly — resuming twenty times an hour must not leave
  /// twenty timers running.
  void start() {
    if (_timer != null) return;
    _ping();
    _timer = Timer.periodic(pingEvery, (_) => _ping());
  }

  /// One ping, now. The whole of [start] minus the timer, for tests.
  @visibleForTesting
  Future<void> pingNow() => _ping();

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _ping() async {
    final userId = _ref.read(currentUserIdProvider);
    final awake = await _ref.read(deviceAwakeProvider)();
    if (!shouldClaimPresence(
      signedIn: userId != null,
      onWeb: kIsWeb,
      deviceAwake: awake,
    )) {
      return;
    }
    try {
      await _ref.read(presenceRepositoryProvider).markActive(userId!);
    } catch (_) {
      // A missed ping costs one minute of accuracy on a header. It is never
      // worth an error in front of somebody, and the next one fixes it.
    }
  }
}

final presencePingerProvider = Provider<PresencePinger>((ref) {
  final pinger = PresencePinger(ref);
  ref.onDispose(pinger.stop);
  return pinger;
});

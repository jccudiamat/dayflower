import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../tulip/data/flower_repository.dart';
import '../domain/call.dart';

/// Starting, joining and ending calls — all of which are writes to
/// `flower_messages`. See the header of migration 0025 for why a call is a
/// message and not a table of its own.
class CallRepository {
  CallRepository(this._client);
  final SupabaseClient _client;

  /// The room name both phones derive, from data both phones already have.
  ///
  /// This is the whole trick, and it is the one thing consumer Google Meet
  /// cannot do: no handshake, no lookup, no "wait for the link". Two people
  /// in the same pair compute the same string and are in the same call.
  ///
  /// Prefixed and versioned so the scheme can change without a stale bubble
  /// dialling into a room a new build would never join — old rows carry
  /// their own `call_room`, which is why it is stored as well as derived.
  static String roomFor(String pairId) => 'dayflower-v1-$pairId';

  /// Places a call: writes the row that *is* the call.
  ///
  /// The row goes in before any media is negotiated, deliberately. It is the
  /// half that works on a network where the media never will — the partner
  /// gets a bubble in the thread either way, and on a failed call that
  /// bubble is the whole delivered feature rather than a consolation.
  Future<FlowerMessage> start({
    required String pairId,
    required String senderId,
    required CallMode mode,
  }) async {
    final row = await _client
        .from('flower_messages')
        .insert({
          'pair_id': pairId,
          'sender_id': senderId,
          'call_mode': mode.id,
          'call_room': roomFor(pairId),
          // A call belongs in the conversation and nowhere near the home
          // screen widget, which renders flowers and photos only.
          'to_chat': true,
          'to_widget': false,
        })
        .select()
        .single();
    return FlowerMessage.fromMap(row);
  }

  /// Hangs up.
  ///
  /// Goes through the `end_call` definer function rather than an update:
  /// 0001's update policy is recipient-only, so the caller — who is the
  /// sender — cannot write to their own row. See migration 0025.
  ///
  /// Idempotent on the server, so a double-tap or a retry after a dropped
  /// response keeps the first timestamp instead of stretching the call.
  Future<void> end(String messageId) async {
    await _client.rpc<void>('end_call', params: {'p_message_id': messageId});
  }
}

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository(ref.watch(supabaseClientProvider));
});

/// The call happening in this thread right now, or null.
///
/// Read off the message stream the chat is already subscribed to, so it
/// arrives on the other phone with no second subscription and no polling —
/// the reason a call is modelled as a message in the first place.
///
/// Only ever one: [FlowerMessage.isLiveCall] time-boxes a row whose hang-up
/// never landed, so an abandoned call stops advertising itself after two
/// hours instead of sitting in the header forever.
final liveCallProvider = Provider.autoDispose<FlowerMessage?>((ref) {
  final messages = ref.watch(flowerMessagesProvider).valueOrNull ?? const [];
  for (final m in messages) {
    if (m.isLiveCall) return m;
  }
  return null;
});

/// A live call my partner started that I have not joined. What would ring,
/// if anything in this app could ring.
///
/// ⚠️ Nothing rings today. Local notifications cannot wake a backgrounded
/// app (PROGRESS.md § Notifications), so this only fires while the app is
/// open — which is exactly why the thread bubble, not the ring, is the
/// feature that ships.
final incomingCallProvider = Provider.autoDispose<FlowerMessage?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final call = ref.watch(liveCallProvider);
  if (call == null || call.senderId == userId) return null;
  return call;
});

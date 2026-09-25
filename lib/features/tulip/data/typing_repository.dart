import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';

/// "typing…", both directions.
///
/// ⚠️ **Broadcast, not a table.** Somebody typing is true for four seconds
/// and then worthless; writing it down would be millions of rows a month
/// describing keystrokes nobody will ever read back. It rides the same
/// private per-pair channel the call signalling uses (migration 0050), so
/// only the two people in the pair can send or hear it.
///
/// 🔴 **One message per burst, not per keystroke.** The obvious build sends
/// on every letter, which at 5,000 pairs is millions of realtime messages a
/// month for an ellipsis. This sends "started" once, repeats it only if the
/// typing outlasts [_repeatAfter], and sends "stopped" when the field
/// empties or the message goes. A burst of normal length costs two messages.
class TypingLine {
  TypingLine({
    required SupabaseClient client,
    required String pairId,
    required String userId,
  })  : _client = client,
        _me = userId {
    _channel = _client.channel(
      'typing:$pairId',
      opts: const RealtimeChannelConfig(private: true),
    );
    _channel
      ..onBroadcast(event: 'typing', callback: _heard)
      ..subscribe();
  }

  final SupabaseClient _client;
  final String _me;
  late final RealtimeChannel _channel;

  final _partner = StreamController<bool>.broadcast();

  /// While still typing, say so again this often. Comfortably inside
  /// [_forgetAfter], so the indicator never blinks off mid-sentence.
  static const _repeatAfter = Duration(seconds: 4);

  /// No keystroke for this long and the burst is over.
  static const _stopAfter = Duration(seconds: 5);

  /// 🔴 The receiver's own expiry, and the reason this cannot go wrong in
  /// the one way that matters. A "stopped" that never arrives — the app was
  /// killed mid-word, the network dropped — would otherwise leave "typing…"
  /// on the other phone forever.
  static const _forgetAfter = Duration(seconds: 7);

  Timer? _repeat;
  Timer? _stop;
  Timer? _forget;
  bool _sending = false;
  bool _closed = false;

  /// Whether they are typing right now. Starts false, and false is also what
  /// it falls back to whenever anything goes quiet.
  Stream<bool> get partnerTyping => _partner.stream;

  /// Call on every keystroke. Cheap: after the first, this is only a timer
  /// being pushed back.
  void poke() {
    if (_closed) return;
    _stop?.cancel();
    _stop = Timer(_stopAfter, stop);
    if (_sending) return;
    _sending = true;
    _say(true);
    _repeat = Timer.periodic(_repeatAfter, (_) => _say(true));
  }

  /// Call when the field empties, the message goes, or the screen closes.
  void stop() {
    if (!_sending) return;
    _sending = false;
    _repeat?.cancel();
    _stop?.cancel();
    _say(false);
  }

  void _say(bool typing) {
    if (_closed) return;
    try {
      _channel.sendBroadcastMessage(
        event: 'typing',
        payload: {'from': _me, 'typing': typing},
      );
    } catch (e) {
      // An ellipsis is not worth an error anywhere. The receiver's own
      // expiry covers a lost "stopped".
      debugPrint('typing signal not sent: $e');
    }
  }

  void _heard(Map<String, dynamic> payload) {
    // Off the wire, so only as trustworthy as their build.
    final from = payload['from'];
    if (from is! String || from == _me) return;
    final typing = payload['typing'] == true;
    _forget?.cancel();
    if (typing) _forget = Timer(_forgetAfter, () => _emit(false));
    _emit(typing);
  }

  void _emit(bool value) {
    if (!_closed && !_partner.isClosed) _partner.add(value);
  }

  Future<void> dispose() async {
    // Said before the channel goes: leaving the chat should clear their
    // "typing…" at once rather than after the expiry.
    stop();
    _closed = true;
    _repeat?.cancel();
    _stop?.cancel();
    _forget?.cancel();
    try {
      await _client.removeChannel(_channel);
    } catch (e) {
      debugPrint('typing channel teardown failed: $e');
    }
    await _partner.close();
  }
}

/// The line for this pair, alive while any chat screen is watching.
final typingLineProvider = Provider.autoDispose<TypingLine?>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  final me = ref.watch(currentUserIdProvider);
  if (pair == null || !pair.isLinked || me == null) return null;
  // 🔴 Guarded. Building the line needs the Supabase client, and an
  // ellipsis is never worth taking the composer down for: without this, a
  // build where the client is not up throws on the first keystroke, from
  // inside `onChanged`.
  final TypingLine line;
  try {
    line = TypingLine(
      client: ref.watch(supabaseClientProvider),
      pairId: pair.id,
      userId: me,
    );
  } catch (e) {
    debugPrint('typing line unavailable: $e');
    return null;
  }
  ref.onDispose(line.dispose);
  // Held briefly after the last watcher goes, so stepping from the list into
  // the conversation does not tear the channel down and build it again.
  final link = ref.keepAlive();
  Timer? idle;
  ref.onCancel(() => idle = Timer(const Duration(seconds: 20), link.close));
  ref.onResume(() => idle?.cancel());
  ref.onDispose(() => idle?.cancel());
  return line;
});

/// Whether they are typing to you right now.
final partnerTypingProvider = StreamProvider.autoDispose<bool>((ref) {
  final line = ref.watch(typingLineProvider);
  if (line == null) return Stream.value(false);
  return line.partnerTyping;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';

/// Where this device can be reached when the app is not running.
///
/// The table is written by the app and read only by the edge function, which
/// runs as service role — so nothing here is ever read back. It is a
/// write-only mailbox address.
class PushRepository {
  PushRepository(this._client);
  final SupabaseClient _client;

  /// Records this device against the signed-in user.
  ///
  /// Upsert on the token, not on the user: one person can hold several
  /// devices, and the same handset reinstalled gets a new token while the
  /// old one lingers until FCM rejects it. Both are normal.
  Future<void> register(String token, {String platform = 'android'}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('device_tokens').upsert(
      {
        'token': token,
        'user_id': userId,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  /// Drops this device on sign-out.
  ///
  /// ⚠️ Not optional. A token left behind keeps delivering one person's
  /// messages to a phone somebody else may now be signed into — the worst
  /// privacy failure this feature could have, and the easiest to forget
  /// because nothing visibly breaks.
  Future<void> unregister(String token) async {
    await _client.from('device_tokens').delete().eq('token', token);
  }
}

final pushRepositoryProvider = Provider<PushRepository>((ref) {
  return PushRepository(ref.watch(supabaseClientProvider));
});

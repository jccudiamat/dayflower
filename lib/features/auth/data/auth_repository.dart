import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/widgets/storage_image.dart';
import '../../location/data/live_location.dart';
import '../../tulip/data/chat_shortcut.dart';
import '../../widget/widget_sync.dart';

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  /// Email + password sign in.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Create an account. Email confirmation is disabled in this project,
  /// so a session is returned immediately.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  /// Sends a 6-digit recovery code to [email].
  /// The Supabase "Reset Password" template must include {{ .Token }}.
  Future<void> sendPasswordResetCode(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  /// Verifies the recovery code and sets the new password.
  Future<void> completePasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.recovery,
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() async {
    // Your exact spot off their map first, while there is still a session
    // allowed to delete it: signing out stops sharing (live_location.dart).
    // Best effort and brief, so a dead network cannot hold up signing out.
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await LiveLocationRepository(_client)
            .stop(userId)
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // Offline, or 0055 not applied. The spot ages out on its own
        // (LiveLocation.freshFor).
      }
    }
    await _client.auth.signOut();
    // Every private photo and face this account has seen is on disk now
    // (see StorageImage). Signing out takes them with it, so whoever signs
    // in next on this phone starts with nothing of the last person's.
    await StorageImageCache.clear();
    // And off the home screen: the widgets held their partner, their days
    // and today's heartbeats, and kept showing them after the sign-out.
    await DayflowerWidgets.clearAccount();
    // Their chat, out of the app icon's menu (ChatShortcut).
    await ChatShortcut.clear();
  }

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

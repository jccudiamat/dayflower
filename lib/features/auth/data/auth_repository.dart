import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

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
    await _client.auth.signOut();
  }

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

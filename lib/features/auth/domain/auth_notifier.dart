import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

enum AuthMode { signIn, signUp }

enum AuthStep { form, recovery }

class AuthState {
  const AuthState({
    this.mode = AuthMode.signIn,
    this.step = AuthStep.form,
    this.email = '',
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
    this.resendSeconds = 0,
  });

  final AuthMode mode;
  final AuthStep step;
  final String email;
  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;
  final int resendSeconds;

  AuthState copyWith({
    AuthMode? mode,
    AuthStep? step,
    String? email,
    bool? isLoading,
    String? errorMessage,
    String? infoMessage,
    int? resendSeconds,
    bool clearMessages = false,
  }) {
    return AuthState(
      mode: mode ?? this.mode,
      step: step ?? this.step,
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearMessages ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearMessages ? null : (infoMessage ?? this.infoMessage),
      resendSeconds: resendSeconds ?? this.resendSeconds,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState());

  final AuthRepository _repo;

  void switchMode() {
    state = AuthState(
      mode: state.mode == AuthMode.signIn ? AuthMode.signUp : AuthMode.signIn,
    );
  }

  Future<void> submit(String rawEmail, String password) async {
    final email = rawEmail.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      state = state.copyWith(errorMessage: 'Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      state = state.copyWith(
        errorMessage: 'Password must be at least 8 characters.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearMessages: true, email: email);
    try {
      if (state.mode == AuthMode.signIn) {
        await _repo.signIn(email: email, password: password);
      } else {
        await _repo.signUp(email: email, password: password);
      }
      // Router redirect takes over via authStateProvider.
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendly(e));
    }
  }

  /// Step 1 of forgot-password: email a recovery code.
  Future<void> requestPasswordReset(String rawEmail) async {
    final email = rawEmail.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      state = state.copyWith(
        errorMessage: 'Enter your email above first, then tap forgot password.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearMessages: true, email: email);
    try {
      await _repo.sendPasswordResetCode(email);
      state = state.copyWith(
        isLoading: false,
        step: AuthStep.recovery,
        resendSeconds: 30,
        infoMessage: 'We emailed a 6-digit code to $email.',
      );
      _startResendTimer();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendly(e));
    }
  }

  /// Step 2 of forgot-password: verify code + set the new password.
  Future<void> completePasswordReset(String code, String newPassword) async {
    if (code.length != 6) {
      state = state.copyWith(errorMessage: 'Enter the 6-digit code.');
      return;
    }
    if (newPassword.length < 8) {
      state = state.copyWith(
        errorMessage: 'New password must be at least 8 characters.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _repo.completePasswordReset(
        email: state.email,
        code: code,
        newPassword: newPassword,
      );
      // Recovery verifies the session; router redirect takes over.
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'That code didn’t work. Please try again.',
      );
    }
  }

  Future<void> resendResetCode() async {
    if (state.resendSeconds > 0) return;
    await requestPasswordReset(state.email);
  }

  void backToForm() {
    state = AuthState(mode: state.mode, email: state.email);
  }

  // ── Private ────────────────────────────────
  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      final next = state.resendSeconds - 1;
      state = state.copyWith(resendSeconds: next < 0 ? 0 : next);
      return next > 0;
    });
  }

  String _friendly(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (msg.contains('already registered')) {
      return 'That email already has an account — sign in instead.';
    }
    if (msg.contains('network')) return 'No internet connection.';
    if (msg.contains('rate')) return 'Too many attempts. Try again later.';
    return 'Something went wrong. Please try again.';
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

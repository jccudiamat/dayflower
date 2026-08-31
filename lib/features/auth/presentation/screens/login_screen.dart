import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/otp_field.dart';
import '../../domain/auth_notifier.dart';

/// Option-A style auth card: email + password, forgot-password (code based),
/// create-account toggle, reserved social buttons.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  var _obscure = true;
  var _recoveryCode = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);
    final isSignIn = auth.mode == AuthMode.signIn;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: AppSpace.screen,
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppElevation.card,
                ),
                child: auth.step == AuthStep.recovery
                    ? _recoveryContent(auth, notifier)
                    : _formContent(auth, notifier, isSignIn),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sign in / create account ─────────────────────
  Widget _formContent(AuthState auth, AuthNotifier notifier, bool isSignIn) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isSignIn ? 'Sign in' : 'Create account', style: AppText.hero()),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              isSignIn ? 'New here?' : 'Have an account?',
              style: AppText.caption(),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: notifier.switchMode,
              child: Text(
                isSignIn ? 'Create an account' : 'Sign in',
                style: AppText.caption(AppColors.secondary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),

        _IconField(
          controller: _emailController,
          hint: 'Email address',
          icon: CupertinoIcons.mail,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpace.xs),
        _IconField(
          controller: _passwordController,
          hint: 'Password',
          icon: CupertinoIcons.lock,
          obscure: _obscure,
          onSubmitted: (_) =>
              notifier.submit(_emailController.text, _passwordController.text),
          trailing: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure
                  ? CupertinoIcons.eye_slash
                  : CupertinoIcons.eye,
              size: 20,
              color: AppColors.muted,
            ),
          ),
        ),

        if (isSignIn) ...[
          const SizedBox(height: AppSpace.xs),
          GestureDetector(
            onTap: () => notifier.requestPasswordReset(_emailController.text),
            child: Text(
              'Forgot password?',
              style: AppText.caption(AppColors.secondary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],

        if (auth.errorMessage != null) ...[
          const SizedBox(height: AppSpace.sm),
          _Banner(message: auth.errorMessage!, danger: true),
        ],

        const SizedBox(height: AppSpace.sm),
        GradientButton(
          label: isSignIn ? 'Login' : 'Create Account',
          loading: auth.isLoading,
          onPressed: () =>
              notifier.submit(_emailController.text, _passwordController.text),
        ),

        const SizedBox(height: AppSpace.sm),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: AppText.caption()),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSpace.sm),

        _SocialButton(
          label: 'Continue with Google',
          icon: _GoogleGlyph(),
          onTap: _comingSoon,
        ),
        const SizedBox(height: AppSpace.xs),
        _SocialButton(
          label: 'Continue with Facebook',
          icon: const Icon(
            Icons.facebook,
            size: 22,
            color: Color(0xFF1877F2),
          ),
          onTap: _comingSoon,
        ),
        const SizedBox(height: AppSpace.xs),
        _SocialButton(
          label: 'Continue with Apple',
          icon: const Icon(Icons.apple, size: 22, color: AppColors.ink),
          onTap: _comingSoon,
        ),

        const SizedBox(height: AppSpace.sm),
        Center(
          child: Text(
            'By continuing you agree to our Terms & Privacy Policy',
            textAlign: TextAlign.center,
            style: AppText.caption().copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }

  // ── Forgot password: code + new password ─────────
  Widget _recoveryContent(AuthState auth, AuthNotifier notifier) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: notifier.backToForm,
          child: const Icon(
            CupertinoIcons.chevron_back,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text('Reset password', style: AppText.hero()),
        const SizedBox(height: 6),
        Text(
          auth.infoMessage ?? 'Enter the code we emailed you.',
          style: AppText.caption(),
        ),
        const SizedBox(height: AppSpace.md),
        OtpField(onCompleted: (code) => _recoveryCode = code),
        const SizedBox(height: AppSpace.sm),
        _IconField(
          controller: _newPasswordController,
          hint: 'New password (8+ characters)',
          icon: CupertinoIcons.lock,
          obscure: true,
        ),
        if (auth.errorMessage != null) ...[
          const SizedBox(height: AppSpace.sm),
          _Banner(message: auth.errorMessage!, danger: true),
        ],
        const SizedBox(height: AppSpace.sm),
        GradientButton(
          label: 'Set new password',
          loading: auth.isLoading,
          onPressed: () => notifier.completePasswordReset(
            _recoveryCode,
            _newPasswordController.text,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Center(
          child: auth.resendSeconds > 0
              ? Text(
                  'Resend code in ${auth.resendSeconds}s',
                  style: AppText.caption(),
                )
              : TextButton(
                  onPressed: notifier.resendResetCode,
                  child: const Text('Resend code'),
                ),
        ),
      ],
    );
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon — email works great for now 🌷')),
    );
  }
}

/* ── Field with leading icon (option A style) ────── */
class _IconField extends StatelessWidget {
  const _IconField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autocorrect: false,
      onSubmitted: onSubmitted,
      style: AppText.body(AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.muted),
        suffixIcon: trailing,
      ),
    );
  }
}

/* ── Social button (reserved) ────────────────────── */
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: AppSpace.xs),
              Text(
                label,
                style:
                    AppText.body(AppColors.ink).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple neutral "G" glyph — replaced with the real logo asset when
/// Google sign-in is actually configured.
class _GoogleGlyph extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'G',
        style: AppText.caption(AppColors.ink).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

/* ── Message banner ──────────────────────────────── */
class _Banner extends StatelessWidget {
  const _Banner({required this.message, this.danger = false});
  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: danger ? AppColors.dangerSubtle : AppColors.blush,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        message,
        style: AppText.caption(danger ? AppColors.danger : AppColors.ink)
            .copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

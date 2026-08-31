import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/gradient_button.dart';

/// Light landing screen shown before authentication.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Padding(
            padding: AppSpace.screen,
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: AppColors.iconBg,
                    boxShadow: AppElevation.glow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.local_florist_rounded,
                          size: 48,
                          color: AppColors.petalDeep,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  'It starts with a',
                  textAlign: TextAlign.center,
                  style: AppText.hero(),
                ),
                ShaderMask(
                  shaderCallback: (b) => AppGradients.cta.createShader(b),
                  child: Text(
                    'flower 🌷',
                    textAlign: TextAlign.center,
                    style: AppText.hero(Colors.white),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'One flower a day, across any distance.',
                  textAlign: TextAlign.center,
                  style: AppText.note(),
                ),
                const Spacer(flex: 3),
                GradientButton(
                  label: 'Continue with Email',
                  onPressed: () => context.go(Routes.login),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'By continuing you agree to our Terms & Privacy Policy',
                  textAlign: TextAlign.center,
                  style: AppText.caption().copyWith(fontSize: 11),
                ),
                const SizedBox(height: AppSpace.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

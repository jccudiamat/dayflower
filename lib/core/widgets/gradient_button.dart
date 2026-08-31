import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// THE primary action button — full-width pill with the signature
/// pink→purple gradient. One per screen region.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppMotion.micro,
      opacity: _enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppGradients.cta,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: _enabled ? onPressed : null,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      label,
                      style: AppText.subtitle(Colors.white)
                          .copyWith(fontSize: 15),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary pill — transparent fill, tinted border.
class OutlinePillButton extends StatelessWidget {
  const OutlinePillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.dark = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Set true when rendered on the dark canvas.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? AppColors.onDark : AppColors.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onPressed,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: .55),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: AppText.subtitle(color).copyWith(fontSize: 15),
          ),
        ),
      ),
    );
  }
}

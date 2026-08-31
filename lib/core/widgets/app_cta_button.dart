import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

class AppCtaButton extends StatefulWidget {
  const AppCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  State<AppCtaButton> createState() => _AppCtaButtonState();
}

class _AppCtaButtonState extends State<AppCtaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return AnimatedScale(
      duration: AppMotion.micro,
      curve: AppMotion.easeOut,
      scale: _pressed && enabled ? 0.98 : 1,
      child: AnimatedContainer(
        duration: AppMotion.standard,
        curve: AppMotion.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: enabled
                ? const [
                    AppColors.gradientPink,
                    AppColors.gradientRose,
                    AppColors.gradientPurple,
                  ]
                : const [
                    Color(0xFFD7CDD4),
                    Color(0xFFCABFC7),
                  ],
          ),
          boxShadow: AppElevation.card,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: widget.onPressed,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: 14,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: Colors.white, size: 18),
                    const SizedBox(width: AppSpace.xs),
                  ],
                  Text(
                    widget.label,
                    style: AppText.body(Colors.white).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

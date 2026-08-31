import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';
import 'gradient_button.dart';

/// One-question-per-screen wizard scaffold on the midnight-plum canvas:
/// back arrow, [TwoToneHeading] (passed as [heading]), helper caption,
/// single control area, thin gradient progress bar, pinned gradient CTA.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.heading,
    this.caption,
    required this.child,
    required this.progress,
    required this.ctaLabel,
    this.onCta,
    this.ctaLoading = false,
    this.onBack,
    this.belowCta,
  });

  final Widget heading;
  final String? caption;
  final Widget child;

  /// 0..1 across the whole onboarding journey.
  final double progress;
  final String ctaLabel;
  final VoidCallback? onCta;
  final bool ctaLoading;
  final VoidCallback? onBack;

  /// Optional widget under the CTA (e.g. a plain-text escape action).
  final Widget? belowCta;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.darkCanvas,
        body: SafeArea(
          child: Padding(
            padding: AppSpace.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpace.xs),
                SizedBox(
                  height: 40,
                  child: onBack == null
                      ? null
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: onBack,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              CupertinoIcons.chevron_back,
                              color: AppColors.onDarkMuted,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: AppSpace.xs),
                heading,
                if (caption != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(caption!, style: AppText.caption(AppColors.onDarkMuted)),
                ],
                const SizedBox(height: AppSpace.md),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: child,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                _ProgressBar(value: progress),
                const SizedBox(height: AppSpace.sm),
                GradientButton(
                  label: ctaLabel,
                  onPressed: onCta,
                  loading: ctaLoading,
                ),
                if (belowCta != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Center(child: belowCta!),
                ],
                SizedBox(
                  height: AppSpace.sm +
                      MediaQuery.of(context).viewInsets.bottom * 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Container(color: AppColors.darkRaised),
            AnimatedFractionallySizedBox(
              duration: AppMotion.standard,
              curve: AppMotion.easeOut,
              widthFactor: value.clamp(0.02, 1),
              child: Container(
                decoration:
                    const BoxDecoration(gradient: AppGradients.cta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark-canvas text field matching the wizard style.
class DarkField extends StatelessWidget {
  const DarkField({
    super.key,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.autofocus = false,
    this.onSubmitted,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.style,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      autocorrect: false,
      style: style ?? AppText.body(AppColors.onDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.body(AppColors.onDarkMuted),
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: 15,
        ),
        border: _border(AppColors.darkBorder),
        enabledBorder: _border(AppColors.darkBorder),
        focusedBorder: _border(AppColors.secondary, width: 1.5),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: color, width: width),
      );
}

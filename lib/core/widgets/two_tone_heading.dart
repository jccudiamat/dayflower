import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// The signature headline pattern: neutral lead line, accent-tinted
/// keyword line. E.g. lead "Enter your verification", accent "Code".
class TwoToneHeading extends StatelessWidget {
  const TwoToneHeading({
    super.key,
    required this.lead,
    required this.accent,
    this.dark = false,
  });

  final String lead;
  final String accent;

  /// True on the midnight-plum canvas.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lead,
          style: AppText.hero(dark ? AppColors.onDark : AppColors.ink),
        ),
        ShaderMask(
          shaderCallback: (bounds) => AppGradients.cta.createShader(bounds),
          child: Text(accent, style: AppText.hero(Colors.white)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

/// TikTok's open-source UI typeface, bundled so text never waits on a network.
abstract final class AppTypography {
  static const family = 'TikTokSans';

  static TextStyle style({
    double? fontSize,
    double? height,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? color,
    double? letterSpacing,
    List<FontFeature>? fontFeatures,
  }) =>
      TextStyle(
        fontFamily: family,
        fontSize: fontSize,
        height: height,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: color,
        letterSpacing: letterSpacing,
        fontFeatures: fontFeatures,
      );
}

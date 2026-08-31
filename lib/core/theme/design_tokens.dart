import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// 4pt grid spacing tokens.
class AppSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: 20);
  static const EdgeInsets card = EdgeInsets.all(16);
}

/// Radius scale — pills for everything interactive, soft squares for
/// everything informational.
class AppRadius {
  static const double sm = 12; // inputs, option rows, photo tiles
  static const double md = 14; // secondary controls
  static const double lg = 18; // cards
  static const double xl = 24; // sheets, hero cards
  static const double pill = 999; // ALL buttons and chips
}

/// Elevation — flat by design. Separation comes from surface-color steps;
/// shadows exist only for floating action circles and overlays.
class AppElevation {
  static List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF2B1B3D).withValues(alpha: .04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> lift = [
    BoxShadow(
      color: const Color(0xFF2B1B3D).withValues(alpha: .12),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];

  /// Soft glow for the single primary CTA / floating hearts.
  static List<BoxShadow> glow = [
    BoxShadow(
      color: AppColors.gradientPurple.withValues(alpha: .32),
      blurRadius: 22,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Motion tokens used across interactions.
class AppMotion {
  static const Curve easeOut = Cubic(0.22, 1, 0.36, 1);

  static const Duration micro = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration emotional = Duration(milliseconds: 500);
}

/// Typography — Quicksand carries the whole UI (rounded, friendly,
/// premium through discipline). Lora italic remains the single emotional
/// accent, reserved for partner notes and quotes.
class AppText {
  // ── Display hierarchy ────────────────────────────────────────
  static TextStyle display([Color color = AppColors.ink]) =>
      GoogleFonts.quicksand(
        fontSize: 30,
        height: 1.12,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// Step titles / page headers. Pair with [TwoToneHeading] for the
  /// signature accent-keyword pattern.
  static TextStyle hero([Color color = AppColors.ink]) =>
      GoogleFonts.quicksand(
        fontSize: 25,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle title([Color color = AppColors.ink]) =>
      GoogleFonts.quicksand(
        fontSize: 19,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle subtitle([Color color = AppColors.ink]) =>
      GoogleFonts.quicksand(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // ── Reading sizes ────────────────────────────────────────────
  static TextStyle body([Color color = AppColors.body]) =>
      GoogleFonts.quicksand(
        fontSize: 14.5,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle caption([Color color = AppColors.muted]) =>
      GoogleFonts.quicksand(
        fontSize: 12.5,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// Overline label — uppercase section headers, pills, nav labels.
  static TextStyle label([Color color = AppColors.muted]) =>
      GoogleFonts.quicksand(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: color,
      );

  // ── Emotional accent (the only serif in the app) ────────────
  /// Partner notes, flower meanings, quotes. Sacred — nowhere else.
  static TextStyle note([Color color = AppColors.body]) => GoogleFonts.lora(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        color: color,
      );

  /// Big expressive numbers — countdowns, invite codes, stats.
  static TextStyle stat([Color color = AppColors.ink]) =>
      GoogleFonts.quicksand(
        fontSize: 32,
        height: 1.05,
        fontWeight: FontWeight.w700,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

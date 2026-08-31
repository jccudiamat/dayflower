import 'package:flutter/material.dart';

/// Dayflower palette v3 — midnight-plum dark journey + lavender-tinted light
/// utility screens, with ONE signature pink→purple gradient spent on every
/// primary action. See reference-analysis.md and design.md.
///
/// Rules:
///  - Neutrals carry 90% of every screen; the gradient means "primary/active"
///    and appears once per screen region.
///  - Never introduce raw hex values in feature code.
class AppColors {
  // ── Light mode neutrals (lavender-tinted) ───────────────────
  static const background = Color(0xFFF8F6FB); // app canvas
  static const surface = Color(0xFFFFFFFF); // cards, sheets
  static const surfaceSubtle = Color(0xFFEFEAF8); // OTP boxes, inset fills
  static const ink = Color(0xFF1C1024); // primary text
  static const body = Color(0xFF564A5E); // secondary text
  static const muted = Color(0xFF8E8698); // tertiary text, hints
  static const border = Color(0xFFEAE5F0); // hairlines

  // ── Dark mode ("midnight plum" journey screens) ─────────────
  static const darkCanvas = Color(0xFF100A1E); // wizard background
  static const darkSurface = Color(0xFF1D1430); // cards, inputs on dark
  static const darkRaised = Color(0xFF2A2040); // chips, raised surfaces
  static const darkBorder = Color(0xFF332A4A); // hairlines on dark
  static const onDark = Color(0xFFF5F2F8); // text on dark
  static const onDarkMuted = Color(0xFF9C92AC); // secondary text on dark

  // ── Brand (gradient endpoints + solid tints) ────────────────
  static const gradientPink = Color(0xFFF0709F); // gradient start
  static const gradientPurple = Color(0xFF906FE8); // gradient end
  static const brand = Color(0xFFEE6FA8); // solid pink accent
  static const brandDark = Color(0xFFD5568F); // pressed
  static const brandLight = Color(0xFFF59FC4); // decorative tint
  static const secondary = Color(0xFF8B72E0); // solid purple accent
  static const blush = Color(0xFFFCEDF4); // pink-tinted fill
  static const blushMid = Color(0xFFF6D3E4); // pink-tinted border

  // ── Legacy dark-hero aliases (now the plum set) ─────────────
  static const inkSurface = darkSurface;
  static const heroTop = Color(0xFF171027);
  static const heroMid = Color(0xFF221838);
  static const heroBottom = Color(0xFF120C1F);

  // ── Semantic ────────────────────────────────────────────────
  static const success = Color(0xFF3DBE7B);
  static const warning = Color(0xFFE8A13D);
  static const danger = Color(0xFFE2447C);
  static const dangerSubtle = Color(0xFFFDEBF2);

  // ── Accents (stats, tags — one per element) ─────────────────
  static const sage = Color(0xFF5EA383);
  static const amber = Color(0xFFD09A4E);
  static const lavender = Color(0xFF8B72E0);

  // ── Legacy gradient stop alias ──────────────────────────────
  static const gradientRose = brand;

  // ── Cycle phases (legacy Dates feature) ─────────────────────
  static const period = Color(0xFFD9678A);
  static const fertile = Color(0xFF62B392);
  static const ovulation = Color(0xFFD3A155);
  static const pms = Color(0xFF9179C9);

  // ── Brand asset colors (logo, icon) ─────────────────────────
  static const petalMain = Color(0xFFD97B72);
  static const petalDeep = Color(0xFFB5403A);
  static const petalLight = Color(0xFFE8A090);
  static const stemGreen = Color(0xFF3A7A28);
  static const leafGreen = Color(0xFF5AAF3C);
  static const iconBg = Color(0xFFF9EBE4);
  static const wordmark = Color(0xFF5C1828);
  static const wordNum = Color(0xFFB83040);
}

/// Reusable gradients.
class AppGradients {
  /// THE signature — every primary action. Horizontal pink→purple.
  static const cta = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.gradientPink, AppColors.gradientPurple],
  );

  /// Full-bleed splash / celebration backdrop. Diagonal.
  static const splash = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gradientPink, AppColors.gradientPurple],
  );

  /// Dark plum surface for hero cards on light screens.
  static const hero = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.heroTop, AppColors.heroMid, AppColors.heroBottom],
  );

  /// Legacy alias — brand celebration moments.
  static const brand = cta;
}

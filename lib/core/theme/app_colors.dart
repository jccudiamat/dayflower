import 'package:flutter/material.dart';

/// Which palette the app is painted in.
///
/// Named by flowers rather than by "light" and "dark" because that is what
/// the switch shows: a sunflower turns to follow the sun all day, and
/// jasmine opens after dark. Both are real entries in the catalogue, so the
/// control is drawn with the same artwork the conversation sends.
enum AppMode {
  light(flowerId: 'stem_sunflower', title: 'Sunflower', line: 'Follows the sun'),
  dark(flowerId: 'stem_jasmine', title: 'Jasmine', line: 'Opens after dark');

  const AppMode({
    required this.flowerId,
    required this.title,
    required this.line,
  });

  /// An id in `FlowerCatalog`. A string rather than a `Flower` because the
  /// theme is core and the catalogue is a feature — core must not reach
  /// upward into features.
  final String flowerId;
  final String title;
  final String line;

  AppMode get other => this == AppMode.light ? AppMode.dark : AppMode.light;
}

/// One complete set of surfaces and inks.
///
/// Only the neutrals live here. The brand — the gradient, the pink, the
/// purple — is the same in both modes on purpose: it is the one thing on
/// screen that means "this is Dayflower", and a brand that changes colour
/// when the lights go out is not a brand.
@immutable
class Palette {
  const Palette({
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.ink,
    required this.body,
    required this.muted,
    required this.border,
    required this.blush,
    required this.blushMid,
    required this.dangerSubtle,
  });

  final Color background, surface, surfaceSubtle, ink, body, muted, border;

  /// Your own chat bubble, and its hairline.
  final Color blush, blushMid;

  /// The fill behind a destructive row.
  final Color dangerSubtle;
}

const _lightPalette = Palette(
  background: Color(0xFFF8F6FB), // app canvas
  surface: Color(0xFFFFFFFF), // cards, sheets
  surfaceSubtle: Color(0xFFEFEAF8), // OTP boxes, inset fills
  ink: Color(0xFF1C1024), // primary text
  body: Color(0xFF564A5E), // secondary text
  muted: Color(0xFF8E8698), // tertiary text, hints
  border: Color(0xFFEAE5F0), // hairlines
  blush: Color(0xFFFCEDF4),
  blushMid: Color(0xFFF6D3E4),
  dangerSubtle: Color(0xFFFDEBF2),
);

/// The midnight plum the journey screens have always used, promoted to a
/// whole mode. Deliberately not black: this app is warm, and #000 under a
/// pink gradient reads as a different product.
const _darkPalette = Palette(
  background: Color(0xFF100A1E),
  surface: Color(0xFF1D1430),
  surfaceSubtle: Color(0xFF2A2040),
  ink: Color(0xFFF5F2F8),
  // Between ink and muted. A dark palette needs the middle step more than a
  // light one does — pure white body text on plum is louder than it looks.
  body: Color(0xFFC9C0D6),
  muted: Color(0xFF9C92AC),
  border: Color(0xFF332A4A),
  // ⚠️ Your bubble stays *pink*, not grey. Which side said what is carried
  // by fill, not by position alone, and a plum bubble on a plum canvas
  // takes that away.
  blush: Color(0xFF3A2039),
  blushMid: Color(0xFF56314F),
  dangerSubtle: Color(0xFF3A1B29),
);

/// Dayflower palette v3 — midnight-plum dark journey + lavender-tinted light
/// utility screens, with ONE signature pink→purple gradient spent on every
/// primary action. See reference-analysis.md and design.md.
///
/// Rules:
///  - Neutrals carry 90% of every screen; the gradient means "primary/active"
///    and appears once per screen region.
///  - Never introduce raw hex values in feature code.
///
/// 🔴 **The neutrals are getters, not constants, and that is load-bearing.**
/// There are ~950 `AppColors.x` references across ~60 files. Reaching dark
/// mode by threading `Theme.of(context)` through all of them was never a
/// real option, so the palette swaps underneath the name instead and not one
/// call site had to change. The price is paid in two places, both small: a
/// handful of `const` expressions had to drop their `const`, and switching
/// modes has to re-inflate the tree rather than just repaint it — see the
/// key on MaterialApp in app.dart.
class AppColors {
  /// The palette every getter below reads. Swapped by [use].
  static Palette _now = _lightPalette;
  static AppMode _mode = AppMode.light;

  static AppMode get mode => _mode;
  static bool get isDark => _mode == AppMode.dark;

  /// ⚠️ Global mutable state, set in exactly one place — the root widget,
  /// from `themeModeProvider`, before the tree is built. Calling it from
  /// anywhere else paints half a frame in the wrong palette.
  static void use(AppMode mode) {
    _mode = mode;
    _now = mode == AppMode.dark ? _darkPalette : _lightPalette;
  }

  // ── Neutrals (swap with the mode) ───────────────────────────
  static Color get background => _now.background;
  static Color get surface => _now.surface;
  static Color get surfaceSubtle => _now.surfaceSubtle;
  static Color get ink => _now.ink;
  static Color get body => _now.body;
  static Color get muted => _now.muted;
  static Color get border => _now.border;

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
  static Color get blush => _now.blush; // your bubble
  static Color get blushMid => _now.blushMid; // its hairline

  // ── Legacy dark-hero aliases (now the plum set) ─────────────
  static const inkSurface = darkSurface;
  static const heroTop = Color(0xFF171027);
  static const heroMid = Color(0xFF221838);
  static const heroBottom = Color(0xFF120C1F);

  // ── Semantic ────────────────────────────────────────────────
  static const success = Color(0xFF3DBE7B);
  static const warning = Color(0xFFE8A13D);
  static const danger = Color(0xFFE2447C);
  static Color get dangerSubtle => _now.dangerSubtle;

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

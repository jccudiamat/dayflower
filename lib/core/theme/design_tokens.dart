import 'package:flutter/material.dart';
import 'package:dayflower/core/theme/app_typography.dart';

import 'app_colors.dart';

/// 4pt grid spacing tokens.
class AppSpace {
  /// The gutter every full screen is inset by.
  static const double screenInset = 20;

  /// Between screenInset and sm, for rows that need breathing room
  /// without a full step.
  static const double compact = 12;
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

/// TikTok Sans throughout the UI, with italic emphasis for partner notes.
///
/// ⚠️ The colour defaults are resolved in the body, not in the signature.
/// They used to be `[Color color = AppColors.ink]`, and a default value has
/// to be a compile-time constant — which the neutrals stopped being when the
/// palette learned to swap. Resolving here is also what makes
/// `AppText.title()` follow the mode rather than freezing whichever ink
/// happened to be loaded first.
class AppText {
  // ── Display hierarchy ────────────────────────────────────────
  static TextStyle display([Color? color]) => AppTypography.style(
        fontSize: 30,
        height: 1.12,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.ink,
      );

  /// Step titles / page headers. Pair with [TwoToneHeading] for the
  /// signature accent-keyword pattern.
  static TextStyle hero([Color? color]) => AppTypography.style(
        fontSize: 25,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.ink,
      );

  static TextStyle title([Color? color]) => AppTypography.style(
        fontSize: 19,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.ink,
      );

  static TextStyle subtitle([Color? color]) => AppTypography.style(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.ink,
      );

  // ── Reading sizes ────────────────────────────────────────────
  static TextStyle body([Color? color]) => AppTypography.style(
        fontSize: 14.5,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.body,
      );

  static TextStyle caption([Color? color]) => AppTypography.style(
        fontSize: 12.5,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.muted,
      );

  /// Overline label — uppercase section headers, pills, nav labels.
  static TextStyle label([Color? color]) => AppTypography.style(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: color ?? AppColors.muted,
      );

  // ── Personal notes ─────────────────────────────────────────
  /// Partner notes, flower meanings, quotes. Sacred — nowhere else.
  static TextStyle note([Color? color]) => AppTypography.style(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        color: color ?? AppColors.body,
      );

  /// Big expressive numbers — countdowns, invite codes, stats.
  static TextStyle stat([Color? color]) => AppTypography.style(
        fontSize: 32,
        height: 1.05,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// The Together tab's pastel set: soft cards, generous corners, one tint
/// per section.
///
/// ⚠️ Getters, not constants, for the same reason the neutrals are — see
/// [AppColors]. Every colour here has a dark counterpart, and a `const`
/// would freeze whichever mode was loaded first.
///
/// Kept apart from [AppGradients] on purpose: the signature pink→purple
/// still means "primary action" everywhere else. These are backdrops, and
/// they only mean "this is Together".
class TogetherStyle {
  // ── Radii ────────────────────────────────────────────────────
  /// Every card on the tab.
  static const double cardRadius = 24;

  /// Tiles and chips inside a card.
  static const double tileRadius = 16;

  /// Round backdrop behind a row's icon.
  static const double bubble = 36;

  // ── Surfaces ─────────────────────────────────────────────────
  /// The hero's wash: near-white lavender on the left, where the text sits,
  /// warming to blush on the right, where the illustration fades in.
  static LinearGradient get heroGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.isDark
            ? const [Color(0xFF1F1633), Color(0xFF261A3B), Color(0xFF34213F)]
            : const [Color(0xFFFCFAFE), Color(0xFFF7EFFA), Color(0xFFFAE6EF)],
      );

  /// The sunset behind the hero's couple. Their illustration is cut out of
  /// its sky, so the card paints one: peach where the sun is, pink around
  /// it, gone before it reaches the text.
  static RadialGradient get heroGlow => RadialGradient(
        center: const Alignment(.75, .1),
        radius: .95,
        colors: AppColors.isDark
            ? [
                const Color(0xFF5A2E4F).withValues(alpha: .75),
                const Color(0xFF3A2244).withValues(alpha: .35),
                const Color(0x003A2244),
              ]
            : [
                const Color(0xFFFFD9C4).withValues(alpha: .85),
                const Color(0xFFF8D2E6).withValues(alpha: .45),
                const Color(0x00F8D2E6),
              ],
        stops: const [0, .45, 1],
      );

  /// A hairline of light around a card, so pastel on pastel still has an edge.
  static Color get cardEdge => AppColors.isDark
      ? const Color(0xFF34294A)
      : const Color(0xFFFFFFFF).withValues(alpha: .9);

  /// Lavender rather than grey: a grey shadow under a pink card reads dirty.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: AppColors.isDark
              ? const Color(0xFF000000).withValues(alpha: .28)
              : const Color(0xFF7A5CC0).withValues(alpha: .09),
          blurRadius: 26,
          offset: const Offset(0, 10),
        ),
      ];

  /// Behind each countdown's icon in the hero.
  static Color get rowBubble =>
      AppColors.isDark ? const Color(0xFF2E2242) : const Color(0xFFFDEFF5);

  // ── Actions ──────────────────────────────────────────────────
  /// "View our plans" and the other pill buttons on the tab. Violet on
  /// violet rather than the brand's pink→purple, as the mockup draws it.
  static const LinearGradient pillGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF9676F5), Color(0xFF7A5AF0)],
  );

  /// Label and arrow on a pill.
  static const Color onPill = Color(0xFFFFFFFF);

  static List<BoxShadow> get pillShadow => [
        BoxShadow(
          color: const Color(0xFF7A5AF0).withValues(alpha: .30),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  // ── Bento ────────────────────────────────────────────────────
  /// The tab's side gutter — tighter than [AppSpace.screenInset], because a
  /// two-column row at 360pt needs every point of width it can get.
  static const double gutter = 16;

  /// Between cards, both across and down.
  static const double gap = 12;

  /// Inside a full-width card, and inside a half-width one.
  static const double pad = 16;
  static const double padTight = 14;

  /// Below this much content width, two-column rows stack. A 360pt phone
  /// keeps its columns (328pt); a 320pt one does not.
  static const double twoColumnMin = 300;

  /// Each card's wash, faint enough that the neutrals still carry the page.
  static LinearGradient cardFill(TogetherTint tint) {
    final dark = AppColors.isDark;
    final colors = switch (tint) {
      TogetherTint.plain => dark
          ? const [Color(0xFF1D1430), Color(0xFF221839)]
          : const [Color(0xFFFFFFFF), Color(0xFFFBF9FE)],
      TogetherTint.lavender => dark
          ? const [Color(0xFF1D1430), Color(0xFF261B3F)]
          : const [Color(0xFFFFFFFF), Color(0xFFF3EFFD)],
      TogetherTint.blush => dark
          ? const [Color(0xFF1D1430), Color(0xFF301B36)]
          : const [Color(0xFFFFFFFF), Color(0xFFFDEDF4)],
      TogetherTint.sky => dark
          ? const [Color(0xFF17213B), Color(0xFF1C1C3C), Color(0xFF231939)]
          : const [Color(0xFFE2EFFC), Color(0xFFEAF2FC), Color(0xFFF1ECFB)],
    };
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  /// The dot beside each upcoming event, by what kind of day it is.
  static Color eventDot(String kind) => switch (kind) {
        'monthsary' => AppColors.brand,
        'reunion' => AppColors.brandLight,
        'anniversary' => const Color(0xFFA48BEA),
        'birthday' => AppColors.warning,
        _ => AppColors.lavender,
      };

  /// "See all ›".
  static const Color link = Color(0xFF7A5AF0);

  /// Each card's heading icon, one hue per card as the mockup draws them.
  static const Color iconEvents = Color(0xFF8B6CF0);
  static const Color iconGifts = Color(0xFFEE6FA8);
  static const Color iconMap = Color(0xFF8B6CF0);
  static const Color iconReminders = Color(0xFFB45FD6);
  static const Color iconSavings = Color(0xFF4DB47E);
  static const Color iconPlay = Color(0xFF5B8DEF);

  // ── Progress, chips, the map ─────────────────────────────────
  static Color get progressTrack =>
      AppColors.isDark ? const Color(0xFF2E2445) : const Color(0xFFE4DEF3);

  static Color get chipFill =>
      AppColors.isDark ? const Color(0xFF1F2744) : const Color(0xFFEAF1FC);

  static Color get chipInk =>
      AppColors.isDark ? const Color(0xFFB9C3E6) : const Color(0xFF6E7BA3);

  /// The dashed line between you, and the plane riding it.
  static Color get mapPath => AppColors.isDark
      ? const Color(0xFFB7A6F5)
      : const Color(0xFF6F58D8).withValues(alpha: .8);

  /// The dot where each of you is.
  static const Color mapDot = Color(0xFF7A5AF0);

  /// The lighter pill on the map card: "Open map".
  static const LinearGradient pillSoftGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFB9A1F8), Color(0xFF9E82F4)],
  );

  /// The white pill on a tinted card: "View ideas".
  static Color get pillPlain => AppColors.isDark
      ? const Color(0xFF2A2040)
      : const Color(0xFFFFFFFF).withValues(alpha: .9);

  /// The month printed on the calendar art, in the ink the art was drawn
  /// with, so the real month reads as part of the picture.
  static const Color calendarInk = Color(0xFF6A5BB0);

  /// Behind each Play Together tile.
  static LinearGradient tileFill(TogetherTile tile) {
    final dark = AppColors.isDark;
    final colors = switch (tile) {
      TogetherTile.lavender => dark
          ? const [Color(0xFF262047), Color(0xFF211A3B)]
          : const [Color(0xFFEAE7FB), Color(0xFFF5F3FD)],
      TogetherTile.pink => dark
          ? const [Color(0xFF3A1F3D), Color(0xFF2C1A35)]
          : const [Color(0xFFFCE4EF), Color(0xFFFDF1F6)],
      TogetherTile.peach => dark
          ? const [Color(0xFF3B2233), Color(0xFF2D1B30)]
          : const [Color(0xFFFDE6EA), Color(0xFFFEF3F2)],
    };
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    );
  }

  // ── Illustration placeholders ────────────────────────────────
  /// What an illustration looks like before its PNG exists.
  static LinearGradient get artFallback => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.isDark
            ? const [Color(0xFF2A2040), Color(0xFF3A2039)]
            : const [Color(0xFFEDE6FB), Color(0xFFFBE3EE)],
      );

  static Color get artFallbackIcon => AppColors.secondary.withValues(alpha: .6);

  // ── Text ─────────────────────────────────────────────────────
  /// "Together" — larger than [AppText.hero]; the tab opens on it.
  static TextStyle pageTitle() => AppTypography.style(
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: AppColors.ink,
      );

  static TextStyle pageSubtitle() => AppTypography.style(
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      );

  /// "What's next for us?"
  static TextStyle heroTitle() => AppTypography.style(
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      );

  /// A card's own heading: "Events", "Gifts", "Our Map".
  static TextStyle cardTitle() => AppTypography.style(
        fontSize: 16,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      );

  /// "29 days until our monthsary".
  static TextStyle rowTitle() => AppTypography.style(
        fontSize: 14,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  /// "19 October 2026" under it.
  static TextStyle rowMeta() => AppTypography.style(
        fontSize: 12.5,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      );

  static TextStyle pillLabel() => AppTypography.style(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: onPill,
      );

  /// The smaller pills inside the bento cards.
  static TextStyle pillLabelSmall([Color? color]) => AppTypography.style(
        fontSize: 13.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: color ?? onPill,
      );

  /// "See all ›".
  static TextStyle linkLabel() => AppTypography.style(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: link,
      );

  /// A line in a card's list: "Our monthsary", "Take vitamins".
  static TextStyle listTitle() => AppTypography.style(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      );

  /// The date or time at its end.
  static TextStyle listMeta() => AppTypography.style(
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      );

  /// "4,293 miles apart", "₱18,500" — the one number a card is about.
  static TextStyle figure([double size = 16]) => AppTypography.style(
        fontSize: size,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// A card's line of warmth: "Different places, same direction."
  static TextStyle tagline() => AppTypography.style(
        fontSize: 12.5,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: AppColors.body,
      );

  /// The tagline chip under the savings bar, italic like a note.
  static TextStyle chipLabel() => AppTypography.style(
        fontSize: 11.5,
        height: 1.35,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        color: chipInk,
      );

  /// A city under its avatar on the map card.
  static TextStyle placeName() => AppTypography.style(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      );

  /// The month on the calendar art. Sized by the art, not by this.
  static TextStyle calendarMonth() => AppTypography.style(
        fontSize: 20,
        height: 1,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: calendarInk,
      );

  /// A reminder's emoji in its bubble. Never scaled with the reader's text:
  /// it is an icon, and the bubble around it is a fixed size.
  static TextStyle emoji() => const TextStyle(fontSize: 17, height: 1);

  /// A Play Together tile's name.
  static TextStyle tileTitle() => AppTypography.style(
        fontSize: 13.5,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      );
}

/// Which wash a Together card sits on.
enum TogetherTint { plain, lavender, blush, sky }

/// Which wash a Play Together tile sits on.
enum TogetherTile { lavender, pink, peach }

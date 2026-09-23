import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';

/// One illustration on the Together tab, or a soft stand-in until it exists.
///
/// 🔴 **Missing is the normal case for now.** The paths in `TogetherAssets`
/// are placeholders waiting for real PNGs, so [Image.asset] fails on every
/// one of them today. The error builder turns that failure into a pastel
/// gradient with an icon — the same footprint the real art will take — so
/// the layout is final before any artwork is, and dropping a file in with
/// the right name is the only change ever needed.
///
/// Decorative: excluded from semantics. Whatever the picture says, the text
/// beside it says too.
class TogetherArt extends StatelessWidget {
  const TogetherArt(
    this.asset, {
    super.key,
    required this.fallbackIcon,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.radius = 0,
    this.iconSize,
    this.placeholder = true,
  });

  /// A path from `TogetherAssets`.
  final String asset;

  /// Drawn in the middle of the placeholder.
  final IconData fallbackIcon;

  final double? width, height;
  final BoxFit fit;
  final Alignment alignment;

  /// Corner radius for both the art and its placeholder.
  final double radius;

  /// Defaults to a share of the space available.
  final double? iconSize;

  /// False for art that sits *behind* a card rather than in it — the map's
  /// backdrop. The card's own wash is the placeholder there, and a gradient
  /// box with an icon in the middle would sit under the pins.
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => !placeholder
          ? SizedBox(width: width, height: height)
          : _Placeholder(
              width: width,
              height: height,
              icon: fallbackIcon,
              iconSize: iconSize,
              alignment: alignment,
            ),
    );
    if (radius <= 0) return image;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.alignment,
    this.width,
    this.height,
    this.iconSize,
  });

  final IconData icon;
  final Alignment alignment;
  final double? width, height, iconSize;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: TogetherStyle.artFallback),
          child: LayoutBuilder(builder: (context, box) {
            // ⚠️ Sized from the space it was given, not a constant: the
            // same widget stands in for a 38pt icon and a hero half the
            // card wide, and one icon size would be lost in one and
            // crowd the other.
            final side = box.biggest.shortestSide;
            final size = iconSize ??
                (side.isFinite ? (side * .42).clamp(14.0, 56.0) : 28.0);
            // Leaning the way the art is aligned, but only halfway: the
            // hero's art hugs the right edge because the couple stand
            // there, and a placeholder in the middle would sit on the text.
            return Align(
              alignment: Alignment(alignment.x * .5, alignment.y * .5),
              child:
                  Icon(icon, size: size, color: TogetherStyle.artFallbackIcon),
            );
          }),
        ),
      );
}

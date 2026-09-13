import 'package:flutter/material.dart';

import '../../features/tulip/domain/flower_catalog.dart';
import '../theme/design_tokens.dart';

/// Renders a flower, scene or stem's artwork, falling back to its emoji
/// glyph when the asset isn't in the bundle.
///
/// Two kinds of artwork, drawn two ways. A photograph fills its box
/// (`cover`) behind rounded corners rather than floating inside padding —
/// letterboxing on a photo looks like a mistake. 🔴 A **cut-out stem must
/// not** be treated that way: it is tall, narrow and transparent, and
/// `cover` in a square box scales it until the bloom is outside the frame.
/// It is `contain`ed on nothing instead, which is what the same drawing
/// does on the website.
///
/// The fallback is deliberate: it lets the catalog grow before every image
/// exists, and a missing or misnamed file degrades to something readable
/// instead of a grey error box.
class FlowerImage extends StatelessWidget {
  const FlowerImage({
    super.key,
    required this.flower,
    required this.size,
    this.radius,
  });

  final Flower flower;
  final double size;

  /// Defaults to a proportional corner so small thumbnails and large hero
  /// images both look right.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? (size * 0.22).clamp(AppRadius.sm, AppRadius.xl);

    return ClipRRect(
      // Nothing to round off on a cut-out: the corners are already empty,
      // and clipping them takes the tips off a wide bloom for no reason.
      borderRadius: BorderRadius.circular(flower.cutout ? 0 : r),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          flower.asset,
          fit: flower.cutout ? BoxFit.contain : BoxFit.cover,
          // Nothing here is decorative — the image IS the message.
          semanticLabel: flower.name,
          errorBuilder: (_, __, ___) => Container(
            color: flower.color.withValues(alpha: .12),
            alignment: Alignment.center,
            child: Text(
              flower.emoji,
              style: TextStyle(fontSize: size * 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

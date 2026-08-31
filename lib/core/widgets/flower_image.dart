import 'package:flutter/material.dart';

import '../../features/tulip/domain/flower_catalog.dart';
import '../theme/design_tokens.dart';

/// Renders a flower or scene's artwork, falling back to its emoji glyph
/// when the asset isn't in the bundle.
///
/// The artwork is photography rather than cut-out illustration, so it fills
/// its box (`cover`) behind rounded corners instead of floating inside
/// padding — a photo with visible letterboxing looks like a mistake.
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
      borderRadius: BorderRadius.circular(r),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          flower.asset,
          fit: BoxFit.cover,
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

import 'package:flutter/material.dart';

import '../models/avatar_flower.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';

/// Someone's flower on the brand gradient.
///
/// Replaces the first-initial circle that the chat header, the conversation
/// card and the inbox each drew separately. One widget so they cannot drift,
/// and so adding real uploaded avatars later is a change in one place.
class FlowerAvatar extends StatelessWidget {
  const FlowerAvatar({
    super.key,
    required this.flower,
    this.size = 44,
  });

  /// From a profile — falls back to the gender default, then to a tulip,
  /// so this never renders empty even before migration 0015 has run.
  FlowerAvatar.of(UserProfile? profile, {super.key, this.size = 44})
      : flower = profile?.flower ?? AvatarFlower.fallback;

  final AvatarFlower flower;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: AppGradients.cta,
        shape: BoxShape.circle,
      ),
      child: Text(
        flower.emoji,
        // Scaled off the circle rather than fixed, so the same widget works
        // at 22 in a chip and at 52 in the inbox row.
        style: TextStyle(fontSize: size * 0.5),
        semanticsLabel: flower.label,
      ),
    );
  }
}

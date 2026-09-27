import 'package:flutter/material.dart';

import '../models/avatar_character.dart';
import '../models/user_profile.dart';
import 'flower_avatar.dart';

/// Someone's drawn avatar, in a circle.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({super.key, required this.character, this.size = 44});

  final AvatarCharacter character;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Decoded at what it is drawn at (on the densest phones), not at its
    // 512px: an avatar in a 22pt chip would otherwise hold 20x the pixels.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context))
        .clamp(24, 512)
        .round();
    return ClipOval(
      child: Image.asset(
        character.asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: pixels,
        semanticLabel: character.label,
      ),
    );
  }
}

/// What stands in for someone with no photo: the character they chose at
/// sign-up, or the flower they chose instead (or were given, on an account
/// from before characters). Never empty.
Widget defaultAvatarFor(UserProfile? profile, {double size = 44}) {
  final character = profile?.character;
  if (character != null) {
    return CharacterAvatar(character: character, size: size);
  }
  return FlowerAvatar.of(profile, size: size);
}

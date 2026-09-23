import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'flower_avatar.dart';
import 'storage_image.dart';

/// This person, however they have chosen to appear: their photo if they
/// uploaded one, their flower otherwise.
///
/// **The flower is not a placeholder that goes away — it is the floor.** It
/// renders while the signed URL is being minted, when the network is gone,
/// when the object has been deleted out from under the row, and for every
/// account that has never uploaded anything. That is why [FlowerAvatar]
/// still exists as its own widget and why `users.avatar` is still a column
/// (see migration 0020's header). Nothing here should ever be able to draw
/// an empty circle.
class UserAvatar extends ConsumerWidget {
  const UserAvatar(this.profile, {super.key, this.size = 44});

  /// Null while a profile is still loading — draws the fallback flower,
  /// which is the same thing every other surface does while waiting.
  final UserProfile? profile;

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flower = FlowerAvatar.of(profile, size: size);
    final path = profile?.avatarPath;
    if (path == null || path.isEmpty) return flower;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        // 🔴 By path, like every private image now. The face used to be
        // cached under its signed URL, which changes every session - so
        // each launch fetched every avatar again and drew the flower until
        // it arrived. The flower is still what shows while a face never
        // seen on this phone loads, and if it cannot.
        child: StorageImage(
          bucket: StorageBucket.avatars,
          path: path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // The bytes are already 512² (see squareAvatarJpeg); a 22pt
          // header avatar decoding all of them would be ~20x more pixels
          // than it draws.
          decodeWidth: size.clamp(22, avatarDecodeCap.toDouble()),
          placeholder: flower,
          error: (_) => flower,
        ),
      ),
    );
  }
}

/// Never decode larger than the stored image actually is.
const int avatarDecodeCap = 512;

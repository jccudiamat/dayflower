import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/data/user_repository.dart';
import '../models/user_profile.dart';
import 'flower_avatar.dart';

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

    final url = ref.watch(avatarUrlProvider(path)).valueOrNull;
    if (url == null) return flower;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: size,
          height: size,
          // Both fall back to the flower rather than to a spinner or a
          // broken-image glyph: an avatar is furniture on every screen it
          // appears on, and furniture that flickers is worse than furniture
          // that is briefly the old thing.
          placeholder: (_, __) => flower,
          errorWidget: (_, __, ___) => flower,
          // The bytes are already 512² (see squareAvatarJpeg); this caps
          // what gets decoded into memory for the 22pt cases, where a full
          // decode would be ~20× more pixels than any of them draw.
          memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(44, avatarDecodeCap),
        ),
      ),
    );
  }
}

/// Never decode larger than the stored image actually is.
const int avatarDecodeCap = 512;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../theme/design_tokens.dart';
import 'app_icon.dart';
import 'flower_avatar.dart';
import 'storage_image.dart';
import 'user_avatar.dart';

/// Someone's face, which opens their profile picture when pressed.
///
/// The way WhatsApp does it: the small circle is a way into the big one.
/// Their flower, for somebody with no photo, opens too - larger, rather than
/// a tap that does nothing on something that looks exactly as tappable.
class ProfilePhotoButton extends StatelessWidget {
  const ProfilePhotoButton({
    super.key,
    required this.profile,
    required this.name,
    this.size = 44,
  });

  final UserProfile? profile;

  /// Said by a screen reader, and shown over the photo.
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: 'View $name’s photo',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showProfilePhoto(context, profile: profile, name: name),
          child: ExcludeSemantics(child: UserAvatar(profile, size: size)),
        ),
      );
}

/// Opens [profile]'s picture full screen, pinchable, over everything.
Future<void> showProfilePhoto(
  BuildContext context, {
  required UserProfile? profile,
  required String name,
}) =>
    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
      transitionDuration: AppMotion.standard,
      reverseTransitionDuration: AppMotion.micro,
      pageBuilder: (_, __, ___) =>
          _ProfilePhotoScreen(profile: profile, name: name),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: AppMotion.easeOut),
        child: child,
      ),
    ));

class _ProfilePhotoScreen extends StatelessWidget {
  const _ProfilePhotoScreen({required this.profile, required this.name});

  final UserProfile? profile;
  final String name;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final path = profile?.avatarPath;
    // No photo: their flower, big. The flower is who they chose to be here,
    // and a blank square would read as a picture that failed to load.
    final flower = Center(child: FlowerAvatar.of(profile, size: width * .6));
    return Scaffold(
      // Black in either mode, like the media viewer: a photo is judged
      // against black, not against the app's plum.
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xs, vertical: AppSpace.xxs),
            child: Row(children: [
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const AppIcon(CupertinoIcons.chevron_back,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpace.xxs),
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(Colors.white)),
              ),
            ]),
          ),
          Expanded(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                // Square, full width: the stored picture is a 512px square
                // (see squareAvatarJpeg), so this shows all of it.
                child: SizedBox.square(
                  dimension: width,
                  child: path == null || path.isEmpty
                      ? flower
                      : StorageImage(
                          bucket: StorageBucket.avatars,
                          path: path,
                          fit: BoxFit.contain,
                          semanticLabel: '$name’s photo',
                          placeholder: flower,
                          error: (_) => flower,
                        ),
                ),
              ),
            ),
          ),
          // Balances the top row, so the photo sits in the optical middle.
          const SizedBox(height: 56),
        ]),
      ),
    );
  }
}

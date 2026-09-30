import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/user_avatar.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../data/chat_shortcut.dart';

/// Asks for their chat on the home screen (ChatShortcut), and says what
/// came of it when the launcher's own dialog does not.
Future<void> addChatShortcut(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));

  final partner = ref.read(partnerProfileProvider).valueOrNull;
  if (partner == null) {
    say('Their chat isn’t ready yet. Try again in a moment.');
    return;
  }
  final result = await ChatShortcut.pin(partner,
      // Only reached for a photo: a drawn face or a flower needs no storage.
      download: (path) =>
          ref.read(userRepositoryProvider).downloadAvatar(path));
  final name = ChatShortcut.labelFor(partner);
  switch (result) {
    case ChatShortcutPin.asked:
      // The launcher's dialog is up, and says the rest.
      break;
    case ChatShortcutPin.already:
      say('$name is already on your home screen.');
    case ChatShortcutPin.unsupported:
      say('Your home screen can’t add it from here. Touch and hold the '
          'Dayflower icon, then drag $name onto your home screen.');
  }
}

/// Their chat's icon as it looks on a home screen, for the widget gallery:
/// their face in an app icon's shape, Dayflower's badge on its corner (the
/// launcher adds the real one), their name under it.
class ChatShortcutPreview extends ConsumerWidget {
  const ChatShortcutPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final name =
        partner == null ? 'Your person' : ChatShortcut.labelFor(partner);
    return DecoratedBox(
      // Something like a wallpaper, for the name to sit on.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B2A4F), Color(0xFF7A4468)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // A circle a little larger than the tile, so the tile is
                  // all face (or flower) to its corners.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: OverflowBox(
                      maxWidth: 68,
                      maxHeight: 68,
                      child: UserAvatar(partner, size: 68),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 22,
                      height: 22,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0x40000000), blurRadius: 3),
                        ],
                      ),
                      child: Image.asset('assets/images/mark.png',
                          excludeFromSemantics: true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(color: Color(0x80000000), blurRadius: 3)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';
import 'app_icon.dart';

/// Where a banner may appear, and nowhere else.
///
/// 🔴 **The list of places is here, in one const, on purpose.** An ad slot
/// added wherever it fits is how an app ends up with one on every screen. A
/// place has to be named in [PromoPlace] to exist, and the two rules behind
/// that list are written down in it.
///
/// ⚠️ **No ad network is wired up, and one cannot be yet.** The APK sits
/// about 76 KB under Play's ceiling and the smallest ad SDK is megabytes.
/// Removing `livekit_client` once peer calling is proven is what makes room.
/// Until then this renders house promos — the app pointing at its own
/// features — which is what the slot is for in the first place: the layout
/// has to be lived with before anybody sells it.
enum PromoPlace {
  /// The Create hub. A grid of cards already, so one more card fits without
  /// changing the shape of the page.
  create,

  /// The Together hub, for the same reason.
  together,

  /// Channels and Reads, when they exist. Content people browse, which is
  /// where a banner is least out of place and worth the most.
  reads,
}

/// 🔴 **Never on these, and this is the reasoning, not a preference.**
///
/// - **Home** holds their note, their mood and their heartbeat. It is the
///   emotional centre of the app.
/// - **Inside a conversation**, ever. It is two people talking.
/// - **The Chats list**, which has exactly one real row: a banner there
///   would *be* the list, and it sits directly on the conversation.
/// - **Memories**, where an ad between two memories of a relationship is
///   simply grim.
/// - **A call**, which is the one screen that is the other person.
const neverPromoted = [
  'home',
  'chat',
  'chats',
  'memories',
  'call',
];

/// Whether this person sees promos at all. False for anyone paying.
///
/// ⚠️ Already here with nothing behind it, deliberately: every slot reads it
/// from day one, so switching subscriptions on later is one provider and not
/// a hunt through the screens.
final promosHiddenProvider = Provider<bool>((ref) => false);

/// One promo, in its own section.
///
/// ⚠️ **A section with a label, not a card pretending to be content.** The
/// brief was "a designated section": something that reads as an
/// advertisement at a glance and cannot be mistaken for the couple's own
/// things. Hence the overline above it, and the border rather than the app's
/// own card fill.
class PromoSlot extends ConsumerWidget {
  const PromoSlot({super.key, required this.place});

  final PromoPlace place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(promosHiddenProvider)) return const SizedBox.shrink();
    final promo = housePromoFor(place);
    // Nothing to show is the normal state, and it takes no room at all: an
    // empty bordered box where an ad failed to load is worse than no ad.
    if (promo == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SPONSORED', style: AppText.label()),
          const SizedBox(height: AppSpace.xs),
          _PromoCard(promo: promo),
        ],
      ),
    );
  }
}

/// What a slot shows: a line, a line under it, an icon and where it goes.
typedef Promo = ({
  String title,
  String body,
  IconData icon,
  String action,
  VoidCallback? onTap,
});

/// The app pointing at its own features, until there is a network.
///
/// ⚠️ Returns null for a place with nothing to say rather than inventing
/// filler, so the empty case is exercised from the first day instead of
/// being discovered when an ad fails to load.
Promo? housePromoFor(PromoPlace place) => switch (place) {
      PromoPlace.create => (
          title: 'Send a real bouquet',
          body: 'Choose the flowers, write the card, have it delivered.',
          icon: CupertinoIcons.gift,
          action: 'Browse',
          onTap: null,
        ),
      PromoPlace.together => (
          title: 'Plan your next reunion',
          body: 'Somewhere to count down to makes the distance shorter.',
          icon: CupertinoIcons.airplane,
          action: 'See ideas',
          onTap: null,
        ),
      PromoPlace.reads => null,
    };

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo});

  final Promo promo;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: AppColors.border),
    );
    return Material(
      color: AppColors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: promo.onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.compact),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: AppIcon(promo.icon, size: 20, color: AppColors.secondary),
              ),
              const SizedBox(width: AppSpace.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(promo.title,
                        style: AppText.subtitle().copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(promo.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption()),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Text(promo.action,
                  style: AppText.caption(AppColors.brand)
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

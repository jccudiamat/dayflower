import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../features/tulip/data/flower_repository.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// Five destinations, and only the selected one says its name.
///
/// Five labels across a phone means five truncated words; showing just the
/// active one keeps the bar readable and makes the selection obvious without
/// a pill or an underline. The label animates in rather than appearing, so
/// the row does not jump as you move between tabs.
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final unread = ref.watch(unreadMessageCountProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xxs,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: CupertinoIcons.house_fill,
                label: 'Home',
                selected: location.startsWith(Routes.home),
                onTap: () => context.go(Routes.home),
              ),
              _NavItem(
                icon: CupertinoIcons.chat_bubble_2_fill,
                label: 'Chat',
                selected: location.startsWith(Routes.chat),
                badge: location == Routes.chat ? 0 : unread,
                onTap: () => context.go(Routes.chat),
              ),
              _NavItem(
                icon: CupertinoIcons.heart_fill,
                label: 'Dayflower',
                selected: location.startsWith(Routes.dayflower),
                onTap: () => context.go(Routes.dayflower),
              ),
              _NavItem(
                icon: CupertinoIcons.photo_on_rectangle,
                label: 'Memories',
                selected: location.startsWith(Routes.memories),
                onTap: () => context.go(Routes.memories),
              ),
              _NavItem(
                icon: CupertinoIcons.square_grid_2x2_fill,
                label: 'Together',
                selected: location.startsWith(Routes.together),
                onTap: () => context.go(Routes.together),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  /// Unread count. Zero hides the dot entirely.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.secondary : AppColors.muted;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          // The label is still read out on every tab even while hidden, so
          // an unselected tab is not an unlabelled button to a screen reader.
          child: Semantics(
            label: label,
            selected: selected,
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (label == 'Dayflower')
                        Opacity(
                            opacity: selected ? 1 : .6,
                            child: ColorFiltered(
                                colorFilter: ColorFilter.matrix(selected
                                    ? const <double>[
                                        1,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0
                                      ]
                                    : const <double>[
                                        .51,
                                        .43,
                                        .06,
                                        0,
                                        0,
                                        .13,
                                        .81,
                                        .06,
                                        0,
                                        0,
                                        .13,
                                        .43,
                                        .44,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0
                                      ]),
                                child: Image.asset('assets/images/mark.png',
                                    width: 28,
                                    height: 28,
                                    excludeFromSemantics: true)))
                      else
                        AppIcon(icon,
                            size: 24, color: color, selected: selected),
                      if (badge > 0)
                        Positioned(
                          top: -3,
                          right: -6,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 15),
                            height: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: AppColors.surfaceSubtle,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              badge > 9 ? '9+' : '$badge',
                              style: AppText.label(Colors.white).copyWith(
                                fontSize: 8.5,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Only the selected tab is named. AnimatedSize collapses
                  // the gap too, so the icons stay put instead of shifting
                  // up and down as the label comes and goes.
                  AnimatedSize(
                    duration: AppMotion.duration(context, AppMotion.micro),
                    curve: AppMotion.easeOut,
                    alignment: Alignment.topCenter,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              softWrap: false,
                              style: AppText.label(color).copyWith(
                                fontSize: 9.5,
                                letterSpacing: 0.3,
                              ),
                            ),
                          )
                        : const SizedBox(width: 0, height: 0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../features/tulip/data/flower_repository.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    // Flowers is a conversation now, so it needs the one affordance every
    // chat has. The stream behind this is already watched app-wide in
    // app.dart, so the badge costs nothing extra.
    final unread = ref.watch(unreadMessageCountProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
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
                label: 'HOME',
                selected: location == Routes.home,
                onTap: () => context.go(Routes.home),
              ),
              _NavItem(
                // Material, not Cupertino: there is no flower in the
                // Cupertino set (see the icon-set note in PROGRESS.md).
                icon: Icons.local_florist_rounded,
                label: 'Flowers',
                // startsWith: the thread is a sub-route of the inbox.
                selected: location.startsWith(Routes.flowers),
                // Suppressed only inside the thread, where markThreadSeen is
                // about to zero it anyway. On the inbox the badge must stay —
                // seeing the list is not the same as having read anything.
                badge: location == Routes.chat ? 0 : unread,
                onTap: () => context.go(Routes.flowers),
              ),
              _NavItem(
                icon: CupertinoIcons.calendar,
                label: 'DATES',
                selected: location == Routes.events,
                onTap: () => context.go(Routes.events),
              ),
              _NavItem(
                icon: CupertinoIcons.square_grid_2x2_fill,
                label: 'ACTIVITIES',
                // startsWith, not ==: the booth is a sub-route of the hub
                // and the tab has to stay lit while you're inside it.
                selected: location.startsWith(Routes.activities),
                onTap: () => context.go(Routes.activities),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xxs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 22, color: color),
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
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: AppText.label(color).copyWith(
                    fontSize: 9.5,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

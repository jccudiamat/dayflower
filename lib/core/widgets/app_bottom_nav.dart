import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'section_scroll_scope.dart';

import 'package:dayflower/app_router.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/core/theme/app_colors.dart';
import 'package:dayflower/core/theme/design_tokens.dart';

/// Five destinations under a line that slides between them.
///
/// 🔴 **This bar is meant to disappear.** It used to be a rounded lavender
/// card floating clear of the bottom edge, which made the navigation a
/// component on the page rather than the edge of the app. It is now a plain
/// full-width surface sitting on the bottom, separated from the content by a
/// single hairline, so the photographs and flowers above it keep the
/// attention.
///
/// The selected destination is marked by a short rule above it rather than by
/// a pill or a filled bubble, and that rule is the one thing that moves.
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key});

  /// Width of the active rule. Narrower than the icon so it reads as a mark
  /// above the tab rather than an underline under the whole slot.
  static const _indicator = 30.0;

  static const _destinations = <_Destination>[
    _Destination(AppSection.home, CupertinoIcons.house_fill, 'Home', Routes.home),
    _Destination(AppSection.chat, CupertinoIcons.chat_bubble_2, 'Chats', Routes.chats),
    _Destination(AppSection.dayflower, null, 'Create', Routes.dayflower),
    _Destination(AppSection.memories, CupertinoIcons.book, 'Memories', Routes.memories),
    _Destination(AppSection.together, Icons.join_full, 'Together', Routes.together),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final unread = ref.watch(unreadMessageCountProvider);
    final section = sectionForLocation(location);
    final index = _destinations.indexWhere((d) => d.section == section);
    final onDayflower = section == AppSection.dayflower;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        // ⚠️ A hairline and nothing else. The brief allows a divider or a soft
        // shadow; both together is what makes a bar look like a card.
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      // The surface runs under the gesture area; the controls stay above it.
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(builder: (context, box) {
            final slot = box.maxWidth / _destinations.length;
            return Stack(children: [
              // The rule, and the only thing that travels between tabs.
              AnimatedPositioned(
                duration: AppMotion.micro,
                curve: Curves.easeOutCubic,
                left: slot * index + (slot - _indicator) / 2,
                top: 0,
                width: _indicator,
                height: 3,
                child: AnimatedContainer(
                  duration: AppMotion.micro,
                  decoration: BoxDecoration(
                    // Coral over the tulip, purple everywhere else, so the
                    // centre still reads as the brand when it is the one you
                    // are on.
                    color: onDayflower ? AppColors.brand : AppColors.secondary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final destination in _destinations)
                    Expanded(
                      child: _Tab(
                        destination: destination,
                        selected: destination.section == section,
                        badge: destination.section == AppSection.chat &&
                                location != Routes.chat
                            ? unread
                            : 0,
                        onTap: () =>
                            _openSection(context, ref, destination.route),
                      ),
                    ),
                ],
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.section, this.icon, this.label, this.route);

  final AppSection section;

  /// Null for Dayflower, which draws the brand mark rather than a glyph.
  final IconData? icon;
  final String label;
  final String route;
}

void _openSection(BuildContext context, WidgetRef ref, String target) {
  final current = GoRouterState.of(context).matchedLocation;
  final reselect = sectionForLocation(current) == sectionForLocation(target);
  final controller = reselect
      ? ref.read(sectionScrollControllerProvider(target))
      : null;
  final reducedMotion = MediaQuery.disableAnimationsOf(context);
  if (current != target) context.go(target);
  if (controller == null) return;
  // Wait until a nested page has closed and the root scroll view is attached.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    for (final position in controller.positions.toList()) {
      if (reducedMotion) {
        position.jumpTo(position.minScrollExtent);
      } else {
        position.animateTo(position.minScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    }
  });
  WidgetsBinding.instance.ensureVisualUpdate();
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  /// Unread count. Zero hides the dot entirely.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final isDayflower = destination.section == AppSection.dayflower;
    final colour = !selected
        ? AppColors.muted
        : isDayflower
            ? AppColors.brand
            : AppColors.secondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          label: destination.label,
          selected: selected,
          button: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(clipBehavior: Clip.none, children: [
                if (isDayflower)
                  _BrandMark(selected: selected)
                else
                  AnimatedSwitcher(
                    duration: AppMotion.micro,
                    child: AppIcon(destination.icon!,
                        key: ValueKey(selected),
                        size: 24,
                        color: colour,
                        selected: selected),
                  ),
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
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border:
                            Border.all(color: AppColors.background, width: 1.5),
                      ),
                      child: Text(badge > 9 ? '9+' : '$badge',
                          style: AppText.label(Colors.white)
                              .copyWith(fontSize: 8.5, letterSpacing: 0)),
                    ),
                  ),
              ]),
              const SizedBox(height: 3),
              // ⚠️ Every tab is named, selected or not. The previous bar showed
              // only the active label, which meant four of the five buttons
              // relied on an icon alone to say where they went.
              AnimatedDefaultTextStyle(
                duration: AppMotion.micro,
                style: AppText.label(colour).copyWith(
                    fontSize: 11,
                    letterSpacing: 0.1,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                child: Text(destination.label,
                    maxLines: 1, overflow: TextOverflow.clip, softWrap: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tulip: an outline among outlines until you are on it, then the mark.
///
/// 🔴 **The inactive state is the whole point of this widget.** The brand mark
/// is the only colour artwork in a row of grey strokes, so at full strength it
/// looked selected on every screen in the app — Home could be the current tab
/// and the flower would still pull harder than it.
///
/// ⚠️ Draining its colour is what does the work. The resting state is the
/// same flower as a flat silhouette, tinted the same grey as its neighbours,
/// so it sits in the row rather than above it. An outline was tried first and
/// read as faint next to four solid glyphs — matching their weight matters
/// more than matching their stroke. Selecting it swaps in the real mark,
/// which is the one moment the brand is supposed to be louder than
/// everything else.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.micro,
      child: selected
          ? Image.asset('assets/images/brand_mark.png',
              key: const ValueKey(true),
              width: 28,
              height: 28,
              excludeFromSemantics: true)
          : Image.asset('assets/images/brand_glyph.png',
              key: const ValueKey(false),
              width: 24,
              height: 24,
              // The glyph ships as a white silhouette mask, so the tint is
              // what gives it a colour at all; it is not an overlay on
              // existing artwork.
              color: AppColors.muted,
              excludeFromSemantics: true),
    );
  }
}

/// Tab ownership is independent of historic deep-link paths.
enum AppSection { home, chat, dayflower, memories, together }

AppSection sectionForLocation(String location) {
  final path = Uri.parse(location).path;
  bool inside(String root) => path == root || path.startsWith('$root/');
  if (inside(Routes.chats) || inside(Routes.chat)) return AppSection.chat;
  // 🔴 Ownership follows what a page is *for*, not where its path sits.
  // Making a strip and writing this month are Create, even though the booth
  // and the journal still answer on the old /app/activities/... paths they
  // were born under. Looking back at what you kept is Memories, and that
  // now includes the garden: Create lost its garden section, and Blooms is
  // reached from Memories' Flowers only.
  //
  // ⚠️ The collection is a child path of the booth, so it has to be asked
  // about first or `inside(Routes.booth)` would swallow it.
  if (inside(Routes.boothCollection) || inside(Routes.blooms)) {
    return AppSection.memories;
  }
  if (inside(Routes.dayflower) ||
      inside(Routes.booth) ||
      inside(Routes.chapters)) {
    return AppSection.dayflower;
  }
  if (inside(Routes.memories)) return AppSection.memories;
  if (inside(Routes.together) ||
      inside(Routes.activities) ||
      inside(Routes.events) ||
      inside(Routes.gifts)) {
    return AppSection.together;
  }
  return AppSection.home;
}

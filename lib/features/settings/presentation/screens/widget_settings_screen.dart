// 🔴 `const` is a correctness hazard on a settings screen — see the header of
// settings_screen.dart for the whole story. The short version: a const widget
// is identical to itself, so Flutter never calls its build again and any
// colour it took from the global AppColors palette stays frozen at the mode
// it was first inflated in. Settings is a screen you are looking at while the
// theme changes under you, and so is this one.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_const_constructors_in_immutables

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../../core/widgets/ios_back_button.dart';
import '../../../widget/widget_sync.dart';
import 'settings_sections.dart';

/// Everything about the home screen widgets, on one screen.
///
/// ⚠️ These were three separate sections in the middle of Settings — which
/// one the plain widget shows, the picture behind Reunion, and how fast the
/// photos rotate. Three headings and three explanatory paragraphs for one
/// feature, sitting between the theme and the about box, made Settings long
/// enough that the things people actually came for were below the fold.
class WidgetSettingsScreen extends ConsumerWidget {
  const WidgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IosBackButton(
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go(Routes.settings)),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: FeatureScreenHeader(
                      title: 'Home screen widgets',
                      subtitle: 'What they show, and how they behave',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenInset, AppSpace.sm, AppSpace.screenInset,
                    AppSpace.lg),
                children: [
                  Text(
                    DayflowerWidgets.isSupported
                        ? 'Long-press your home screen → Widgets → Dayflower. "My Day", "Heartbeat" and "Reunion" can be placed on their own; the plain "Dayflower" widget shows whichever you pick here.'
                        : 'Home screen widgets are only available on the Android and iOS app.',
                    style: AppText.caption(),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  SettingsCard(
                    children: [
                      WidgetModeRow(
                        title: 'My Day',
                        subtitle: 'Their photo and note',
                        mode: WidgetMode.flower,
                      ),
                      SettingsLine(),
                      WidgetModeRow(
                        title: 'Heartbeat',
                        subtitle: 'Tap it to send a pulse',
                        mode: WidgetMode.heartbeat,
                      ),
                      SettingsLine(),
                      WidgetModeRow(
                        title: 'Reunion',
                        subtitle: 'Days until you are in the same place',
                        mode: WidgetMode.reunion,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),

                  Text('REUNION WIDGET', style: AppText.label()),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'The picture behind the countdown. Somewhere you are '
                    'going, or somewhere you have been.',
                    style: AppText.caption(),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  SettingsCard(children: [ReunionBackgroundRow()]),
                  const SizedBox(height: AppSpace.md),

                  Text('PHOTO ROTATION', style: AppText.label()),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'How often the widget moves to their next day. Only '
                    'applies when more than one is live.',
                    style: AppText.caption(),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  SettingsCard(
                    children: [
                      // ⚠️ "Don't" is first and is the default. A card that
                      // moves on its own is the kind of thing that reads as
                      // delightful for a week and restless after that, so it
                      // is opt-in.
                      WidgetRotationRow(
                        title: "Don't rotate",
                        subtitle: 'Only the newest day',
                        seconds: 0,
                      ),
                      SettingsLine(),
                      WidgetRotationRow(
                        title: 'Every 3 seconds',
                        subtitle: 'Through their live days',
                        seconds: 3,
                      ),
                      SettingsLine(),
                      WidgetRotationRow(
                        title: 'Every 5 seconds',
                        subtitle: 'A calmer pace',
                        seconds: 5,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

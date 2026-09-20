// 🔴 `const` is a correctness hazard on a settings screen — see the header of
// settings_screen.dart. A const widget is identical to itself, so Flutter
// never calls its build again and any colour it took from the global
// AppColors palette stays frozen at the mode it was first inflated in.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_const_constructors_in_immutables

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/services/pulse_alerts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../../core/widgets/ios_back_button.dart';
import '../../../heartbeat/data/pulse_alert_prefs.dart';
import 'settings_sections.dart';

/// What the app is allowed to interrupt you for.
///
/// ⚠️ Lives one tap from the notifications themselves rather than in
/// Settings. Somebody who wants to change how they are notified is almost
/// always looking at a notification when they decide that, and the old route
/// was Home → Settings → scroll past the theme.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

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
                          : context.go(Routes.notifications)),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: FeatureScreenHeader(
                      title: 'Notification settings',
                      subtitle: 'What reaches you, and how',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpace.screenInset,
                    AppSpace.sm, AppSpace.screenInset, AppSpace.lg),
                children: [
                  SettingsCard(
                    children: [
                      // One switch, and deliberately only one. The row that
                      // used to sit under here picked how long a heartbeat
                      // had to wait before another was allowed to buzz — a
                      // window on a gesture that is already the smallest
                      // thing you can send someone.
                      SettingsSwitchRow(
                        title: 'Heartbeat alerts',
                        subtitle: PulseAlerts.supported
                            ? 'Vibrate and play a heartbeat every time they send one'
                            : 'Only available on the Android and iOS app',
                        value: ref.watch(pulseAlertsEnabledProvider),
                        onChanged: PulseAlerts.supported
                            ? (v) => ref
                                .read(pulseAlertsEnabledProvider.notifier)
                                .setEnabled(v)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  // ⚠️ Says where the rest of the switches are rather than
                  // pretending this screen owns them. Everything else about
                  // notifications is the operating system's to grant, and a
                  // toggle here that silently did nothing would be worse than
                  // no toggle at all.
                  Text(
                    'Whether Dayflower may notify you at all is set by your '
                    'phone, under its own app settings.',
                    style: AppText.caption(),
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

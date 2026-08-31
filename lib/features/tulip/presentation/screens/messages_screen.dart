import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../widgets/share_your_day.dart';

/// The Messages tab — the inbox, not the thread.
///
/// Tapping the tab used to drop straight into the conversation. A couple only
/// ever has one, so the list is one row deep by design; it exists because
/// landing mid-conversation with no way back reads as a screen you fell into
/// rather than one you opened. The thread lives at [Routes.chat].
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Everything this screen shows now lives in ConversationCard and
    // ShareYourDayBar, which read their own providers.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
              child: FeatureScreenHeader(
                title: 'My Day',
                subtitle: 'Share it, then talk about it',
                trailing: IconButton(
                  onPressed: () => context.go(Routes.home),
                  tooltip: 'Done',
                  icon: const Icon(CupertinoIcons.xmark,
                      color: AppColors.muted, size: 20),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            // The camera takes every pixel the conversation row doesn't:
            // Expanded, not a fixed height, so it fills a tall phone and
            // still fits a short one without overflowing.
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpace.sm),
                child: ShareYourDayBar(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

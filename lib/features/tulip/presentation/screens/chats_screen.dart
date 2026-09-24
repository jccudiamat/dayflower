import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_icon.dart';
import '../widgets/conversation_row.dart';

/// The Chat tab: a list first, the conversation one tap in, the way
/// WhatsApp and Instagram open.
///
/// With one conversation the list looks like a step for nothing, and today
/// it nearly is. It is here for what comes next: Channels, where couples
/// pass on what works for them, and Reads, articles on making the distance
/// work. Both are held as greyed rows until they exist, so the tab already
/// has the shape it is growing into.
///
/// Notifications still open the conversation directly (Routes.chat). Back
/// from there comes here rather than Home; see backFallbackRoute.
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: AppSpace.xs, bottom: AppSpace.lg),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  ChatsStyle.gutter, 0, ChatsStyle.gutter - 8, AppSpace.xs),
              child: Row(children: [
                Expanded(
                  // Shrinks rather than truncates at large text sizes.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Chats',
                        maxLines: 1,
                        softWrap: false,
                        style: ChatsStyle.pageTitle()),
                  ),
                ),
                // WhatsApp's camera, top right: straight to My Day.
                IconButton(
                  tooltip: 'Camera',
                  onPressed: () => context.push(Routes.flowers),
                  icon: AppIcon(CupertinoIcons.camera,
                      size: 26, color: AppColors.ink),
                ),
              ]),
            ),
            const ConversationRow(),
            Padding(
              padding: const EdgeInsets.fromLTRB(ChatsStyle.gutter,
                  AppSpace.md, ChatsStyle.gutter, AppSpace.xxs),
              child: Semantics(
                header: true,
                child:
                    Text('COMING SOON', style: ChatsStyle.sectionLabel()),
              ),
            ),
            const ComingSoonRow(
              icon: CupertinoIcons.dot_radiowaves_left_right,
              title: 'Channels',
              subtitle: 'Tips from couples like you',
            ),
            const ComingSoonRow(
              icon: CupertinoIcons.book,
              title: 'Reads',
              subtitle: 'Articles on making distance work',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../widgets/together_card.dart';
import '../widgets/together_events_card.dart';
import '../widgets/together_gifts_card.dart';
import '../widgets/together_header.dart';
import '../widgets/together_hero_card.dart';
import '../widgets/together_map_card.dart';
import '../widgets/together_play_card.dart';
import '../widgets/together_reminders_card.dart';
import '../widgets/together_savings_card.dart';

/// The Together tab: what is coming, and the things you do as two.
///
/// Laid out as the mockup's bento — a full-width hero, then pairs of cards
/// in its proportions, broken by full-width cards where one idea needs the
/// room:
///
///     ┌──────────── What's next for us? ────────────┐
///     ├──── Events ────┬──── Gifts ────┤
///     ├──────────────── Our Map ────────────────┤
///     ├──── Reminders ─────┬── Our Savings ──┤
///     └──────────────── Play Together ────────────┘
///
/// Every card reads real data except Play Together, which has no backend
/// yet and says so — see together_mock_data.dart. Each card opens the
/// screen that owns what it shows; nothing that used to be reachable from
/// this tab is not reachable from it now:
///
///  * Events, Reminders, Gifts — their own cards.
///  * Trips — the map card.
///  * Finances — Our Savings.
///  * Shared goals — not here, deliberately. They live in each month's
///    chapter, under Memories.
class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: TogetherStyle.gap);
    // ⚠️ Its own scaffold rather than StoryScaffold: a larger title than the
    // shared chrome draws, and a tighter gutter so two columns fit at 360pt.
    // The bottom bar is the same AppBottomNav every tab uses, untouched.
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(TogetherStyle.gutter, AppSpace.sm,
              TogetherStyle.gutter, AppSpace.lg),
          children: const [
            TogetherHeader(),
            SizedBox(height: AppSpace.md - 4),
            TogetherHeroCard(),
            gap,
            TogetherBentoRow(
              leftShare: .56,
              left: TogetherEventsCard(),
              right: TogetherGiftsCard(),
            ),
            gap,
            TogetherMapCard(),
            gap,
            TogetherBentoRow(
              leftShare: .58,
              left: TogetherRemindersCard(),
              right: TogetherSavingsCard(),
            ),
            gap,
            TogetherPlayCard(),
          ],
        ),
      ),
    );
  }
}

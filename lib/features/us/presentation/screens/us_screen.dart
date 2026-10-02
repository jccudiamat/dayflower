import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/models/pair.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/ios_back_button.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../dates/presentation/screens/events_screen.dart';
import '../../../pairing/data/pair_repository.dart';
import '../widgets/calling_card.dart';
import '../widgets/couple_hero.dart';

/// The couple's own page — the "us" the whole app is about.
///
/// Reached from the pair pill on Home, which used to go straight to
/// Settings. That was always slightly wrong: the pill shows *both* of you,
/// and it opened a screen about one. Settings is still one tap away, from
/// the gear in the corner, which is the right depth for it.
///
/// Everything here is shared and true for both of you. Anything that
/// belongs to one person — your name, your flower, your alerts — is in
/// Settings, and the split is worth keeping: this page should read the same
/// on both phones.
///
/// 🔴 **The events are on this page** (EventsSection), under when you
/// started: what is next, the reunion countdown, everything coming up and
/// passed. They were a screen of their own behind an "Events" row, and every
/// link to them now lands here (Routes.events forwards to Routes.us). Three
/// cards went with that, each saying what something else already did:
/// "Coming up" (the monthsary and anniversary, which are in the events),
/// "Where you are" and the clocks (Home's map card shows both cities, both
/// clocks and the weather).
class UsScreen extends ConsumerStatefulWidget {
  const UsScreen({super.key, this.addEvent = false, this.showEvents = false});

  /// Opens the new-event sheet straight away: links that said "add an event"
  /// (`/app/events?add=1`, forwarded here).
  final bool addEvent;

  /// Arrived by a link to the events: opens scrolled down to them, not on
  /// the couple card above.
  final bool showEvents;

  @override
  ConsumerState<UsScreen> createState() => _UsScreenState();
}

class _UsScreenState extends ConsumerState<UsScreen> {
  final _events = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.showEvents || widget.addEvent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _events.currentContext;
        if (target != null) Scrollable.ensureVisible(target);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pair = ref.watch(currentPairProvider).valueOrNull;
    final me = ref.watch(userProfileProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
              child: Row(
                children: [
                  // Back where they came from: Home's pair pill, or the
                  // Together tab or wherever an events link was.
                  IosBackButton(
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go(Routes.home)),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(child: Text('Us', style: AppText.hero())),
                  // The one personal thing on a shared page, so it is an
                  // icon in the corner rather than a row in the list.
                  _GearButton(onTap: () => context.go(Routes.settings)),
                ],
              ),
            ),
            // ⚠️ Not a ListView: that builds what is on screen, and the
            // events are scrolled to by their key, which needs them built.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.sm, AppSpace.sm, AppSpace.sm, AppSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero and stats are one card now — see CoupleHero for
                    // why six rounded rectangles became one.
                    CoupleHero(me: me, partner: partner, pair: pair),
                    const SizedBox(height: AppSpace.sm),
                    // Where the monthsary and the anniversary come from, so
                    // it sits right above the events they appear in.
                    _TogetherSinceCard(pair: pair),
                    const SizedBox(height: AppSpace.md),
                    EventsSection(key: _events, addOnOpen: widget.addEvent),
                    // Silent below 70% of the month's allowance, and absent
                    // entirely on a self-hosted build — it brings its own
                    // leading gap so this list needs no condition.
                    const CallingCard(),
                    const SizedBox(height: AppSpace.md),
                    const _PremiumCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GearButton extends StatelessWidget {
  const _GearButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Your settings',
      child: Material(
        color: AppColors.surface,
        shape: CircleBorder(
          side: BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: AppIcon(CupertinoIcons.gear_alt_fill,
                size: 20, color: AppColors.body),
          ),
        ),
      ),
    );
  }
}

/* ── Who you are ─────────────────────────── */

/// Both faces, both names, and how long it has been.
/* ── The date everything else comes from ─── */

class _TogetherSinceCard extends ConsumerStatefulWidget {
  const _TogetherSinceCard({required this.pair});
  final Pair? pair;

  @override
  ConsumerState<_TogetherSinceCard> createState() => _TogetherSinceCardState();
}

class _TogetherSinceCardState extends ConsumerState<_TogetherSinceCard> {
  bool _saving = false;

  Future<void> _pick() async {
    final pair = widget.pair;
    if (pair == null || !pair.isLinked || _saving) return;

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: pair.togetherSince ?? now,
      // Nobody's start date is in the future, and letting one be chosen
      // gives every derived number a negative to render.
      firstDate: DateTime(now.year - 60),
      lastDate: now,
      helpText: 'When did you start?',
    );
    if (picked == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(pairRepositoryProvider)
          .setTogetherSince(pairId: pair.id, date: picked);
      ref.invalidate(currentPairProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("That didn't save. Try again?")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.pair?.togetherSince;

    return _Card(
      onTap: _pick,
      child: Row(
        children: [
          const Text('💞', style: TextStyle(fontSize: 24)),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOGETHER SINCE', style: AppText.label()),
                const SizedBox(height: 3),
                Text(
                  start == null
                      ? 'Tap to set the day'
                      : DateFormat('d MMMM y').format(start),
                  style: AppText.subtitle(
                    start == null ? AppColors.muted : AppColors.ink,
                  ),
                ),
                if (start == null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Your monthsary and anniversary come from this.',
                    style: AppText.caption(),
                  ),
                ],
              ],
            ),
          ),
          if (_saving)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            AppIcon(CupertinoIcons.chevron_forward,
                size: 16, color: AppColors.muted),
        ],
      ),
    );
  }
}

/* ── Premium ─────────────────────────────── */

/// ⚠️ **Static on purpose — there is no billing in this app.** No store
/// product, no receipt validation, no entitlement anywhere. None of the
/// features listed are gated today, so this card is a statement of intent
/// and the button says so when tapped rather than pretending to charge
/// anyone. Wiring it up means a real purchase flow; do not make this look
/// live until that exists.
///
/// The price is **per couple, not per person**: $4.99 covers both of you.
/// That is a product decision, and it is the one thing on this card that
/// would be easy to get wrong later, so it is on the card in words.
class _PremiumCard extends StatelessWidget {
  const _PremiumCard();

  static const _features = <(String, String)>[
    ('🌸', 'Rare & seasonal flower variants'),
    ('🌿', 'Full garden view'),
    ('📸', 'Unlimited photo strips'),
    ('🔍', 'Flower recognition'),
    ('🔥', 'Streak repair'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 30)),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dayflower Premium',
                        style: AppText.title(Colors.white)),
                    Text(
                      // Spelled out because it is the unusual half of the
                      // pricing and the thing most likely to be misread.
                      r'$4.99 / month for the two of you',
                      style: AppText.caption(AppColors.onDarkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          for (final (emoji, label) in _features)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(label, style: AppText.body(AppColors.onDark)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.xs),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                // Not a dead button. Nothing can be bought yet, and saying
                // so is better than a tap that appears to fail.
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Not available yet. Nothing is charged.'),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Unlock Premium 💗',
                    textAlign: TextAlign.center,
                    style: AppText.subtitle(Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ── Shared shell ────────────────────────── */

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

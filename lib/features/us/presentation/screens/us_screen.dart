import '../../../../core/widgets/story_components.dart';
import '../../../tulip/data/flower_repository.dart';
import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../app_router.dart';
import '../../../../core/models/pair.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/timezone_picker.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/utils/zone_distance.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
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
class UsScreen extends ConsumerWidget {
  const UsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  IconButton(
                      tooltip: 'Back',
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(Routes.home),
                      icon: const AppIcon(CupertinoIcons.back)),
                  Expanded(child: Text('Us', style: AppText.hero())),
                  // The one personal thing on a shared page, so it is an
                  // icon in the corner rather than a row in the list.
                  _GearButton(onTap: () => context.go(Routes.settings)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.sm, AppSpace.sm, AppSpace.sm, AppSpace.md),
                children: [
                  // Hero and stats are one card now — see CoupleHero for
                  // why six rounded rectangles became one.
                  CoupleHero(me: me, partner: partner, pair: pair),
                  const SizedBox(height: AppSpace.md),
                  Material(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      side: BorderSide(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const AppIcon(CupertinoIcons.clock,
                          color: AppColors.secondary),
                      title:
                          Text('Activity history', style: AppText.subtitle()),
                      subtitle: Text(
                          'Everything the two of you have been up to',
                          style: AppText.caption()),
                      trailing: AppIcon(CupertinoIcons.chevron_right,
                          size: 16, color: AppColors.muted),
                      onTap: () => context.push(Routes.activityFeed),
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  _RelationshipTimeline(start: pair?.togetherSince),
                  const StorySection('Our identity'),
                  _TogetherSinceCard(pair: pair),
                  const SizedBox(height: AppSpace.sm),
                  _WhereYouAreCard(me: me, partner: partner),
                  const SizedBox(height: AppSpace.md),
                  UtilityRow(
                      icon: CupertinoIcons.square_grid_2x2,
                      title: 'Widgets & Connections',
                      subtitle: 'My Day, Heartbeat and Reunion',
                      onTap: () => context.push(Routes.widgetSettings)),
                  const SizedBox(height: AppSpace.xs),
                  UtilityRow(
                      icon: CupertinoIcons.person_2,
                      title: 'Names & preferences',
                      subtitle: 'Endearments, notifications and privacy',
                      onTap: () => context.push(Routes.settings)),
                  const SizedBox(height: AppSpace.md),
                  const _PremiumCard(),
                ],
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

class _WhereYouAreCard extends ConsumerWidget {
  const _WhereYouAreCard({required this.me, required this.partner});

  final UserProfile? me;
  final UserProfile? partner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distance = profileDistanceLabel(me, partner);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('WHERE YOU ARE', style: AppText.label())),
              // Hidden entirely when a zone is unknown rather than guessed
              // at — same rule as the home greeting.
              if (distance != null)
                Text(distance,
                    style: AppText.caption(AppColors.brandDark)
                        .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          _PersonRow(profile: me, isMe: true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Divider(height: 1, color: AppColors.border),
          ),
          _PersonRow(profile: partner, isMe: false),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.profile, required this.isMe});

  final UserProfile? profile;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final zone = profile?.timezone;
    final localTime =
        zone == null ? null : tz.TZDateTime.now(safeLocation(zone));

    return Row(
      children: [
        UserAvatar(profile, size: 38),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.petName ?? profile?.displayName ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.subtitle(),
              ),
              Text(
                zone == null ? 'No city set' : zoneCity(zone),
                style: AppText.caption(),
              ),
            ],
          ),
        ),
        if (localTime != null)
          Text(
            DateFormat('h:mm a').format(localTime),
            style: AppText.subtitle(AppColors.body),
          ),
      ],
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
                      r'$4.99 / month — for the two of you',
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
                    content: Text('Not available yet — nothing is charged.'),
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

class _RelationshipTimeline extends ConsumerWidget {
  const _RelationshipTimeline({required this.start});
  final DateTime? start;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final since = start;
    if (since == null) return const SizedBox.shrink();
    final flowers = (ref.watch(flowerMessagesProvider).valueOrNull ?? [])
        .where((m) => m.flower != null)
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    final now = DateTime.now();
    final moments = <({DateTime date, String title})>[
      (date: since, title: 'Together since'),
      if (flowers.isNotEmpty)
        (date: flowers.first.sentAt, title: 'Our first Dayflower'),
      for (var year = since.year + 1; year <= now.year; year++)
        if (!DateTime(year, since.month, since.day).isAfter(now))
          (
            date: DateTime(year, since.month, since.day),
            title:
                '${year - since.year} ${year - since.year == 1 ? 'year' : 'years'} together'
          ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const StorySection('Our story'),
      for (final m in moments)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Row(children: [
              const AppIcon(CupertinoIcons.heart,
                  size: 20, color: AppColors.brand),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(m.title, style: AppText.subtitle()),
                    Text(DateFormat('d MMMM y').format(m.date),
                        style: AppText.caption()),
                  ]))
            ])),
    ]);
  }
}

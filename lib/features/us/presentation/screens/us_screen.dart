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
import '../../../../core/widgets/ios_back_button.dart';
import '../../../../core/widgets/timezone_picker.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/utils/zone_distance.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/couple_stats.dart';
import '../widgets/calling_card.dart';
import '../../domain/couple_dates.dart';

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
                  IosBackButton(onTap: () => context.go(Routes.home)),
                  const SizedBox(width: AppSpace.xs),
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
                  _CoupleHero(me: me, partner: partner, pair: pair),
                  const SizedBox(height: AppSpace.md),
                  const _StatsRow(),
                  const SizedBox(height: AppSpace.md),
                  _TogetherSinceCard(pair: pair),
                  if (pair?.togetherSince != null) ...[
                    const SizedBox(height: AppSpace.sm),
                    _MilestonesCard(start: pair!.togetherSince!),
                  ],
                  const SizedBox(height: AppSpace.sm),
                  _WhereYouAreCard(me: me, partner: partner),
                  // Silent below 70% of the month's allowance, and absent
                  // entirely on a self-hosted build — it brings its own
                  // leading gap so this list needs no condition.
                  const CallingCard(),
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
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(9),
            child: Icon(CupertinoIcons.gear_alt_fill,
                size: 20, color: AppColors.body),
          ),
        ),
      ),
    );
  }
}

/* ── Who you are ─────────────────────────── */

/// Both faces, both names, and how long it has been.
class _CoupleHero extends StatelessWidget {
  const _CoupleHero({
    required this.me,
    required this.partner,
    required this.pair,
  });

  final UserProfile? me;
  final UserProfile? partner;
  final Pair? pair;

  static const double _face = 76;

  @override
  Widget build(BuildContext context) {
    final start = pair?.togetherSince;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm, vertical: AppSpace.md),
      decoration: BoxDecoration(
        gradient: AppGradients.cta,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        children: [
          SizedBox(
            height: _face,
            // Overlapped rather than side by side: two touching circles read
            // as a couple, two spaced ones read as a list. Same reasoning as
            // the pill this page is reached from.
            width: partner == null ? _face : _face * 1.66,
            child: Stack(
              children: [
                _ringed(me),
                if (partner != null)
                  Positioned(left: _face * 0.66, child: _ringed(partner)),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            _names,
            textAlign: TextAlign.center,
            style: AppText.title(Colors.white).copyWith(fontSize: 21),
          ),
          if (start != null) ...[
            const SizedBox(height: 4),
            Text(
              '${togetherLabel(start, DateTime.now())} together',
              style: AppText.body(Colors.white.withValues(alpha: .92)),
            ),
          ],
        ],
      ),
    );
  }

  String get _names {
    final mine = me?.petName ?? me?.displayName;
    final theirs = partner?.petName ?? partner?.displayName;
    // Before pairing there is no "&" to show, and "Bunny & null" is worse
    // than one name on its own.
    return [if (mine != null) mine, if (theirs != null) theirs].join('  &  ');
  }

  Widget _ringed(UserProfile? profile) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: .9), width: 2),
        ),
        child: UserAvatar(profile, size: _face - 4),
      );
}

/* ── The numbers ─────────────────────────── */

/// Four dark tiles, in the shape of the reference.
///
/// Dark on a light page on purpose: these are the only numbers on the
/// screen, and inverting them is what makes four small tiles read as one
/// block of statistics rather than four more cards.
class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(coupleStatsProvider);
    final pair = ref.watch(currentPairProvider).valueOrNull;
    final start = pair?.togetherSince;

    final data = stats.valueOrNull;
    // A dash, not a zero. "0 hearts" is a claim; while the count is in
    // flight the app does not have one to make.
    String show(int? n) => n == null ? '—' : '$n';

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            emoji: '🌷',
            value: show(data?.flowers),
            label: 'FLOWERS',
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: _StatTile(
            emoji: '🔥',
            value: show(data?.streak),
            label: 'STREAK',
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: _StatTile(
            emoji: '💗',
            value: show(data?.hearts),
            label: 'HEARTS',
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: _StatTile(
            emoji: '📅',
            // The only tile that is not a count. Hidden behind a dash until
            // the start date exists, rather than showing a confident 0.
            value: start == null
                ? '—'
                : '${daysBetween(start, DateTime.now())}',
            label: 'DAYS',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.inkSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            FittedBox(
              // Four digits of heartbeats in a quarter-width tile would
              // otherwise overflow rather than shrink.
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: AppText.title(Colors.white).copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppText.label(AppColors.brandLight)),
          ],
        ),
      ),
    );
  }
}

/* ── The date everything else comes from ─── */

class _TogetherSinceCard extends ConsumerStatefulWidget {
  const _TogetherSinceCard({required this.pair});
  final Pair? pair;

  @override
  ConsumerState<_TogetherSinceCard> createState() =>
      _TogetherSinceCardState();
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
            const Icon(CupertinoIcons.chevron_forward,
                size: 16, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// What the start date implies, without anybody entering it twice.
class _MilestonesCard extends StatelessWidget {
  const _MilestonesCard({required this.start});
  final DateTime start;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthsary = nextMonthsary(start, now);
    final anniversary = nextAnniversary(start, now);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COMING UP', style: AppText.label()),
          const SizedBox(height: AppSpace.xs),
          _MilestoneRow(
            emoji: '🌷',
            title: '${monthsBetween(start, monthsary)} month monthsary',
            date: monthsary,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Divider(height: 1, color: AppColors.border),
          ),
          _MilestoneRow(
            emoji: '💞',
            title:
                '${anniversaryNumber(start, anniversary)} year anniversary',
            date: anniversary,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Both are worked out from your start date — they appear on '
            'Events on their own.',
            style: AppText.caption(),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.emoji,
    required this.title,
    required this.date,
  });

  final String emoji;
  final String title;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final days = daysBetween(DateTime.now(), date);
    final away = days == 0
        ? 'Today'
        : days == 1
            ? 'Tomorrow'
            : 'in $days days';

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.subtitle()),
              Text(DateFormat('EEEE d MMMM').format(date),
                  style: AppText.caption()),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.blush,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            away,
            style: AppText.label(AppColors.brandDark),
          ),
        ),
      ],
    );
  }
}

/* ── Where you both are ──────────────────── */

class _WhereYouAreCard extends ConsumerWidget {
  const _WhereYouAreCard({required this.me, required this.partner});

  final UserProfile? me;
  final UserProfile? partner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distance = distanceLabel(me?.timezone, partner?.timezone);

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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.xs),
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

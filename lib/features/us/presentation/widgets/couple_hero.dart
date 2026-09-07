import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/pair.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/couple_stats.dart';
import '../../domain/couple_dates.dart';

/// The shared profile: who you are as a pair, and the four numbers behind it.
///
/// ⚠️ **One object, not a banner with a scoreboard under it.** This used to
/// be a bright pink gradient card followed by four dark emoji tiles — six
/// rounded rectangles for one idea, which is what made the top of this page
/// read as a template rather than a masthead. The numbers belong to the
/// couple, so they live inside the couple's card, separated by hairlines
/// rather than by gaps.
///
/// 🔴 **The pink gradient is not the ground here.** `AppGradients.cta` means
/// "primary action" and the palette spends it once per screen region; a
/// full-bleed non-interactive card was wearing the loudest thing in the
/// system for decoration. It appears now only as the rule under the eyebrow
/// and the ring behind the faces — small, deliberate, and still the thing
/// your eye lands on. The ground is `AppGradients.hero`, the plum the design
/// system already reserves for exactly this: a dark hero on a light screen.
class CoupleHero extends ConsumerWidget {
  const CoupleHero({
    super.key,
    required this.me,
    required this.partner,
    required this.pair,
  });

  final UserProfile? me;
  final UserProfile? partner;
  final Pair? pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = pair?.togetherSince;
    final stats = ref.watch(coupleStatsProvider).valueOrNull;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        // A hairline of light on the top edge, the way a physical card
        // catches it. Without this the plum sits on the lavender canvas as
        // a hole rather than an object.
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
        boxShadow: AppElevation.lift,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Two blooms, off-centre and mostly outside the card. They are
          // the difference between a flat swatch and a lit surface: what
          // shows inside is the falloff, so they read as light rather than
          // as colour.
          const Positioned(
            top: -90,
            right: -70,
            child: _Bloom(color: AppColors.gradientPink, size: 240),
          ),
          const Positioned(
            bottom: -120,
            left: -50,
            child: _Bloom(color: AppColors.gradientPurple, size: 240),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.md,
              AppSpace.md,
              AppSpace.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Eyebrow(),
                const SizedBox(height: AppSpace.md),
                _Faces(me: me, partner: partner),
                const SizedBox(height: AppSpace.sm),
                Text(
                  _names,
                  style: AppText.display(Colors.white).copyWith(
                    fontSize: 27,
                    letterSpacing: -0.4,
                  ),
                ),
                if (start != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${togetherLabel(start, DateTime.now())} together',
                    style: AppText.body(AppColors.brandLight),
                  ),
                ],
                const SizedBox(height: AppSpace.md),
                _StatStrip(stats: stats, start: start),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _names {
    final mine = me?.petName ?? me?.displayName;
    final theirs = partner?.petName ?? partner?.displayName;
    // Before pairing there is no "&" to show, and "Bunny & null" is worse
    // than one name on its own.
    return [if (mine != null) mine, if (theirs != null) theirs].join(' & ');
  }
}

/// A soft radial wash. Sized generously and positioned mostly outside the
/// card, so what shows inside is the falloff rather than the hotspot.
class _Bloom extends StatelessWidget {
  const _Bloom({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: .30),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      );
}

/// The masthead line, with the signature gradient as a short rule beneath.
///
/// ⚠️ It says "OUR STORY" rather than the start date. The first draft put
/// "TOGETHER SINCE · 10 APRIL 2022" here — and the editable *Together since*
/// card sits three rows below on the same screen, so the page said the same
/// date twice within one scroll. An eyebrow that repeats the row under it is
/// decoration wearing the clothes of information.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OUR STORY',
          style: AppText.label(Colors.white.withValues(alpha: .62))
              .copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: AppSpace.xs),
        // 28px of the app's signature, used the way a studio uses a rule:
        // to say where the page begins.
        Container(
          width: 28,
          height: 2.5,
          decoration: BoxDecoration(
            gradient: AppGradients.cta,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ],
    );
  }
}

/// The two faces, overlapped.
///
/// ⚠️ Overlapped rather than side by side: two touching circles read as a
/// couple, two spaced ones read as a list. Each sits on a gradient ring —
/// a padded circle *behind* the avatar rather than a border on it, so a
/// photo sits inside the ring instead of being clipped by it.
class _Faces extends StatelessWidget {
  const _Faces({required this.me, required this.partner});

  final UserProfile? me;
  final UserProfile? partner;

  static const double _face = 66;
  static const double _overlap = 0.72;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _face,
      width: partner == null ? _face : _face * (1 + _overlap),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _ringed(me),
          if (partner != null)
            Positioned(left: _face * _overlap, child: _ringed(partner)),
        ],
      ),
    );
  }

  Widget _ringed(UserProfile? profile) => Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          gradient: AppGradients.cta,
          shape: BoxShape.circle,
        ),
        // A plum gap between the gradient ring and the face, so two
        // overlapping rings stay two rings instead of merging into one
        // pink blob where they meet.
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            color: AppColors.heroMid,
            shape: BoxShape.circle,
          ),
          child: UserAvatar(profile, size: _face - 9),
        ),
      );
}

/// The four numbers, as one strip.
///
/// ⚠️ **No emoji.** They were carrying the meaning that the labels should
/// carry, and a 🌷 above a 🔥 above a 💗 is the single clearest signal that
/// a layout was assembled rather than designed. Typography does it here:
/// tabular figures so the row does not jitter as counts change, and a
/// letter-spaced overline underneath.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats, required this.start});

  final CoupleStats? stats;
  final DateTime? start;

  @override
  Widget build(BuildContext context) {
    // A dash, not a zero. "0 hearts" is a claim; while the count is in
    // flight the app does not have one to make.
    String show(int? n) => n == null ? '—' : '$n';

    final items = <(String, String)>[
      (
        start == null ? '—' : '${daysBetween(start!, DateTime.now())}',
        'DAYS',
      ),
      (show(stats?.flowers), 'FLOWERS'),
      (show(stats?.hearts), 'HEARTS'),
      (show(stats?.streak), 'STREAK'),
    ];

    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: .09)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  // Hairline rules instead of gaps: four numbers in one
                  // frame, which is what makes them read as a set.
                  Container(
                    width: 1,
                    height: 26,
                    color: Colors.white.withValues(alpha: .09),
                  ),
                Expanded(child: _Stat(value: items[i].$1, label: items[i].$2)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      child: Column(
        children: [
          FittedBox(
            // Four digits of heartbeats in a quarter-width column would
            // otherwise overflow rather than shrink.
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppText.stat(Colors.white).copyWith(
                fontSize: 23,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: AppText.label(Colors.white.withValues(alpha: .62))
                .copyWith(fontSize: 9.5, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

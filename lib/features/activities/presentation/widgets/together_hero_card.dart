import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../home/domain/home_moments.dart';
import '../../data/together_assets.dart';
import '../../data/together_next_up.dart';
import 'together_art.dart';
import 'together_card.dart';

/// "What's next for us?" — the three dates worth counting to, and the way
/// into everything else you have planned.
///
/// Every row is real: the monthsary from the day you started, the reunion
/// from Events, the trip from Our Map. A row with nothing behind it says so
/// and points to where it would be set, rather than showing a mock date.
class TogetherHeroCard extends ConsumerWidget {
  const TogetherHeroCard({super.key});

  static final _date = DateFormat('d MMMM y');

  /// "7 Nov 2026" on a narrow card, where the full month cuts the year off
  /// the reunion line — and the year is the part that must not go missing.
  static final _shortDate = DateFormat('d MMM y');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(togetherNextUpProvider);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: TogetherStyle.heroGradient,
        borderRadius: BorderRadius.circular(TogetherStyle.cardRadius),
        border: Border.all(color: TogetherStyle.cardEdge),
        boxShadow: TogetherStyle.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TogetherStyle.cardRadius),
        // Transparent Material so the rows' ink lands on the card, not on
        // the scaffold behind its gradient where nobody would see it.
        child: Material(
          type: MaterialType.transparency,
          child: LayoutBuilder(builder: (context, box) {
            // ⚠️ The text column claims more of a narrow card. At 360pt the
            // card is 320 wide, and the mockup's 42% would wrap every row to
            // three lines; the fade is what lets the words sit over the art.
            final narrow = box.maxWidth < 340;
            // ⚠️ Large text takes the whole card and the picture steps
            // aside. At 200% the rows need every point they can get, and a
            // decoration is the one thing on the card nobody needs to read.
            final large = MediaQuery.textScalerOf(context).scale(10) > 13;
            final textWidth =
                large ? box.maxWidth : box.maxWidth * (narrow ? .72 : .68);
            // 🔴 Wider than the card, and hanging off its right edge. The
            // couple are the middle third of a wide sunset strip; drawn at
            // this size, with the right quarter cropped away, they land in
            // the card's right third and the sea runs off behind the text,
            // fading as it goes — which is the mockup. Drawn to fit the
            // card instead, they end up in the middle, under the words.
            final artWidth = box.maxWidth * _Hero.artShare;
            return Stack(children: [
              // The sky the illustration was cut out of.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: TogetherStyle.heroGlow),
                ),
              ),
              if (!large)
                Positioned(
                  right: -box.maxWidth * _Hero.overhang,
                  bottom: 0,
                  width: artWidth,
                  height: artWidth / _Hero.artAspect,
                  child: const _FadingArt(),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.md - 4,
                    AppSpace.md - 2, AppSpace.sm, AppSpace.md - 4),
                child: SizedBox(
                  width: textWidth,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What’s next for us?',
                            style: TogetherStyle.heroTitle()),
                        const SizedBox(height: AppSpace.compact),
                        _milestoneRow(context, next, narrow),
                        _reunionRow(context, next, narrow),
                        _tripRow(context, next),
                        const SizedBox(height: AppSpace.compact),
                        TogetherPill(
                          label: 'View our plans',
                          onTap: () => context.push(Routes.events),
                        ),
                      ]),
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _milestoneRow(BuildContext context, TogetherNextUp next, bool narrow) {
    final moment = next.milestone;
    final word = moment?.kind == HomeMomentKind.anniversary
        ? 'anniversary'
        : 'monthsary';
    return _HeroRow(
      asset: TogetherAssets.heroMonthsary,
      icon: CupertinoIcons.heart_fill,
      tint: AppColors.brand,
      loading: next.milestoneLoading,
      title: moment == null
          ? 'When did it all begin?'
          : switch (moment.daysFrom(next.now)) {
              0 => 'Our $word is today',
              1 => 'Our $word is tomorrow',
              final n => '$n days until our $word',
            },
      meta: moment == null
          ? 'Add the day you started'
          : (narrow ? _shortDate : _date).format(moment.date),
      onTap: () => context.push(moment == null ? Routes.us : Routes.events),
    );
  }

  Widget _reunionRow(BuildContext context, TogetherNextUp next, bool narrow) {
    final moment = next.reunion;
    final where = moment == null || moment.location.trim().isEmpty
        ? null
        : placeName(moment.location);
    return _HeroRow(
      asset: TogetherAssets.heroReunion,
      icon: CupertinoIcons.airplane,
      tint: AppColors.secondary,
      loading: next.reunionLoading,
      title: moment == null
          ? 'No reunion planned yet'
          : switch (moment.daysFrom(next.now)) {
              0 => 'Reunion is today',
              1 => 'Reunion is tomorrow',
              final n => '$n days until reunion',
            },
      meta: moment == null ? 'Set when you’ll meet' : null,
      metaSpans: moment == null
          ? null
          : [
              if (where != null) ...[where, '›'],
              (narrow ? _shortDate : _date).format(moment.date),
            ],
      onTap: () => context.push(Routes.events),
    );
  }

  Widget _tripRow(BuildContext context, TogetherNextUp next) {
    final pin = next.trip;
    final label = pin?.label.trim() ?? '';
    return _HeroRow(
      asset: TogetherAssets.heroTrip,
      icon: Icons.beach_access_rounded,
      tint: AppColors.sage,
      loading: next.tripLoading,
      title:
          pin == null ? 'Where to next?' : 'Next trip: ${placeName(pin.place)}',
      // The pin's own name when it has one worth reading — "Beach day" —
      // and never a date, because a pin does not have one.
      meta: pin == null
          ? 'Pin a place you want to go'
          : (label.isNotEmpty && label != placeName(pin.place)
              ? label
              : 'On our map'),
      onTap: () => context.push(Routes.travel),
    );
  }
}

/// Where the hero's art sits, as shares of the card's width.
abstract final class _Hero {
  /// The art is this much wider than the card is.
  static const artShare = .9;

  /// And pushed this far past the right edge.
  static const overhang = .24;

  /// Width over height of the art, so its box is the art's own shape and
  /// it sits on the card's bottom edge. Only the box: a replacement file of
  /// another shape still draws, fitted to the width and anchored low.
  static const artAspect = 1400 / 610;
}

/// The illustration, fading into the card on its left edge.
class _FadingArt extends StatelessWidget {
  const _FadingArt();

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          // Invisible at the edge the text is on, whole by the time it
          // reaches the couple a third of the way in — so the sea fades
          // out behind the words and the two of them never do.
          colors: [Color(0x00000000), Color(0x66000000), Color(0xFF000000)],
          stops: [0, .2, .34],
        ).createShader(rect),
        child: const TogetherArt(
          TogetherAssets.hero,
          fallbackIcon: Icons.favorite_rounded,
          iconSize: 44,
          fit: BoxFit.fitWidth,
          alignment: Alignment.bottomCenter,
          width: double.infinity,
          height: double.infinity,
        ),
      );
}

class _HeroRow extends StatelessWidget {
  const _HeroRow({
    required this.asset,
    required this.icon,
    required this.tint,
    required this.title,
    required this.onTap,
    this.meta,
    this.metaSpans,
    this.loading = false,
  });

  final String asset;
  final IconData icon;
  final Color tint;
  final String title;
  final String? meta;

  /// Meta drawn in pieces, for "Manila › 7 November 2026", where the
  /// chevron is lighter than the words either side of it.
  final List<String>? metaSpans;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metaStyle = TogetherStyle.rowMeta();
    return Semantics(
      container: true,
      button: true,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(TogetherStyle.tileRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            // ⚠️ The art brings its own round backdrop — the plane on
            // sky blue, the island in its bubble of sea — so it is drawn
            // at the bubble's full size with nothing behind it. Only a
            // missing file gets the pastel bubble, with a tinted glyph in
            // it rather than TogetherArt's gradient box: a pastel box
            // inside a pastel bubble is a smudge.
            Image.asset(
              asset,
              width: TogetherStyle.bubble,
              height: TogetherStyle.bubble,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => Container(
                width: TogetherStyle.bubble,
                height: TogetherStyle.bubble,
                decoration: BoxDecoration(
                  color: TogetherStyle.rowBubble,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: tint),
              ),
            ),
            const SizedBox(width: AppSpace.compact - 2),
            Expanded(
              child: loading
                  ? const TogetherSkeleton()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // No line cap: at 200% "29 days until our
                        // monthsary" needs three, and cutting it to "29
                        // days until our m…" loses the only noun.
                        Text(title, style: TogetherStyle.rowTitle()),
                        const SizedBox(height: 2),
                        if (metaSpans != null)
                          Text.rich(
                            TextSpan(children: [
                              for (final (i, part) in metaSpans!.indexed) ...[
                                if (i > 0) const TextSpan(text: '  '),
                                TextSpan(
                                  text: part,
                                  style: part == '›'
                                      ? metaStyle.copyWith(
                                          color: AppColors.muted
                                              .withValues(alpha: .6))
                                      : null,
                                ),
                              ],
                            ]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          )
                        else if (meta != null)
                          Text(meta!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: metaStyle),
                      ],
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

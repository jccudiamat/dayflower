import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';

/// The shell every Together card shares: a soft wash, generous corners, a
/// hairline of light and a lavender shadow — and the whole card as one tap
/// target, because a card that only answers on its button is a card people
/// tap and nothing happens.
class TogetherCard extends StatelessWidget {
  const TogetherCard({
    super.key,
    required this.child,
    this.tint = TogetherTint.plain,
    this.onTap,
    this.padding = const EdgeInsets.all(TogetherStyle.pad),
  });

  final Widget child;
  final TogetherTint tint;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: TogetherStyle.cardFill(tint),
          borderRadius: BorderRadius.circular(TogetherStyle.cardRadius),
          border: Border.all(color: TogetherStyle.cardEdge),
          boxShadow: TogetherStyle.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TogetherStyle.cardRadius),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      );
}

/// A card's icon, title and one line under it, with room for "See all".
///
/// ⚠️ The title shrinks rather than wraps or cuts. In a half-width card at
/// 360pt, "Our Savings" beside its icon is a few points wider than the card;
/// scaled down 5% it reads as the same heading, where "Our Sav…" or a
/// second line would not.
class TogetherCardHeader extends StatelessWidget {
  const TogetherCardHeader({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "See all" shares the title's line only. Beside the whole
                // block it took the subtitle's width too, and "2 waiting on
                // you" broke over three lines in a half card.
                Row(children: [
                  // Expanded, not Flexible beside a Spacer: two flex
                  // children split the room evenly, and "Reminders" was
                  // being shrunk to fit half of it.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      // 🔴 softWrap off. A bento row measures each card
                      // before laying it out, and a FittedBox reports its
                      // text's height *at the card's width* — wrapped. The
                      // title never wraps (it shrinks), but the row was
                      // sized for the two lines it would have taken, and
                      // every card in it grew a blank strip at the bottom.
                      child: Text(title,
                          maxLines: 1,
                          softWrap: false,
                          style: TogetherStyle.cardTitle()),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpace.xxs),
                    trailing!,
                  ],
                ]),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TogetherStyle.rowMeta()),
                ],
              ],
            ),
          ),
        ],
      );
}

/// "See all ›" in a card's corner.
class TogetherSeeAll extends StatelessWidget {
  const TogetherSeeAll({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('See all', style: TogetherStyle.linkLabel()),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: TogetherStyle.link),
            ]),
          ),
        ),
      );
}

/// How a pill is filled.
enum TogetherPillStyle {
  /// Violet, white text: the hero's one action.
  strong,

  /// Lilac, white text: an action inside a tinted card.
  soft,

  /// Near-white, ink text: an action on a pink or busy card.
  plain,
}

/// Every button on the tab. A pill, like every button in the app.
class TogetherPill extends StatelessWidget {
  const TogetherPill({
    super.key,
    required this.label,
    required this.onTap,
    this.style = TogetherPillStyle.strong,
    this.small = false,
  });

  final String label;
  final VoidCallback onTap;
  final TogetherPillStyle style;

  /// The bento cards' size, rather than the hero's.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final ink =
        style == TogetherPillStyle.plain ? AppColors.ink : TogetherStyle.onPill;
    final text = small
        ? TogetherStyle.pillLabelSmall(ink)
        : TogetherStyle.pillLabel().copyWith(color: ink);
    return Semantics(
      container: true,
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: switch (style) {
            TogetherPillStyle.strong => TogetherStyle.pillGradient,
            TogetherPillStyle.soft => TogetherStyle.pillSoftGradient,
            TogetherPillStyle.plain => null,
          },
          color:
              style == TogetherPillStyle.plain ? TogetherStyle.pillPlain : null,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: style == TogetherPillStyle.strong
              ? TogetherStyle.pillShadow
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: small
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
                  : const EdgeInsets.symmetric(
                      horizontal: AppSpace.md - 4,
                      vertical: AppSpace.compact - 1),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                // Flexible, so at 200% text the label wraps inside the
                // pill instead of pushing the arrow off the card. A small
                // pill in a half card shrinks instead: "View / ideas" on
                // two lines reads as two buttons.
                Flexible(
                  child: small
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(label,
                              maxLines: 1, softWrap: false, style: text))
                      : Text(label, style: text),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded,
                    size: small ? 16 : 18, color: ink),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded bar, violet over lilac.
class TogetherProgressBar extends StatelessWidget {
  const TogetherProgressBar({super.key, required this.value});

  /// 0 to 1.
  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // Full width, or the Stack shrinks to the fill and the track —
        // the part that says how far is left — is never drawn.
        child: SizedBox(
          height: 8,
          width: double.infinity,
          child: Stack(children: [
            Positioned.fill(
              child: ColoredBox(color: TogetherStyle.progressTrack),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: TogetherStyle.pillGradient,
                  borderRadius: BorderRadius.all(Radius.circular(99)),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// Two cards side by side, the same height, in the mockup's proportions —
/// or one above the other when two would not be readable.
///
/// 🔴 **Stacks rather than squeezes.** Below [TogetherStyle.twoColumnMin]
/// of width, or at large text, each half would be under 130pt: every line
/// in it ellipsised, and the cards turned into two columns of fragments.
/// A 360pt phone keeps its columns; a 320pt one, or 200% text, gets each
/// card at full width.
///
/// ⚠️ Equal heights come from [IntrinsicHeight], which asks each card how
/// tall it wants to be before laying either out. That is why nothing inside
/// a bento card may use a LayoutBuilder — it cannot answer the question,
/// and the whole row throws.
class TogetherBentoRow extends StatelessWidget {
  const TogetherBentoRow({
    super.key,
    required this.left,
    required this.right,
    this.leftShare = .5,
  });

  final Widget left, right;

  /// Of the width, after the gap. The rest is [right]'s.
  final double leftShare;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final large = MediaQuery.textScalerOf(context).scale(10) > 13;
        if (large || box.maxWidth < TogetherStyle.twoColumnMin) {
          // Still wrapped: a card built to fill its row's height (Gifts
          // pins its button to the bottom) needs a height to fill, and a
          // bare Column offers it an unbounded one.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(child: left),
              const SizedBox(height: TogetherStyle.gap),
              IntrinsicHeight(child: right),
            ],
          );
        }
        final share = (leftShare * 1000).round();
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: share, child: left),
              const SizedBox(width: TogetherStyle.gap),
              Expanded(flex: 1000 - share, child: right),
            ],
          ),
        );
      });
}

/// Two soft bars where a line of words will be.
class TogetherSkeleton extends StatelessWidget {
  const TogetherSkeleton({super.key, this.lines = 2});

  final int lines;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AppColors.muted.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines; i++)
          bar(i.isEven ? 110 : 72, i == 0 ? 12 : 10),
      ],
    );
  }
}

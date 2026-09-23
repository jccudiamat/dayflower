import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../travel/domain/journey.dart';
import '../../data/together_assets.dart';
import 'together_art.dart';
import 'together_card.dart';

/// Our Map: how far apart you are, and the two of you with the gap drawn
/// between.
///
/// ⚠️ The miles are [journeyBetween] — the same arithmetic behind the
/// travel map and Home's "miles apart", so no screen can disagree with
/// another about the one number this card exists for. It needs a real city
/// on both profiles and says so when one is missing, rather than measuring
/// from a timezone's namesake and drawing somebody where they are not.
class TogetherMapCard extends ConsumerWidget {
  const TogetherMapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(userProfileProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final journey = journeyBetween(me, partner);
    void open() => context.push(Routes.travel);

    // West on the left, as a map would have it. Dubai sits left of Manila
    // whichever of the two is holding the phone.
    var (west, east) = (me, partner);
    if (me?.cityLon != null &&
        partner?.cityLon != null &&
        me!.cityLon! > partner!.cityLon!) {
      (west, east) = (partner, me);
    }

    return TogetherCard(
      tint: TogetherTint.sky,
      padding: EdgeInsets.zero,
      onTap: open,
      child: LayoutBuilder(builder: (context, box) {
        // Wider on a narrow card, so "4,293 miles apart" stays one line.
        final textWidth = box.maxWidth * (box.maxWidth < 350 ? .5 : .44);
        return Stack(children: [
          const Positioned.fill(
            child: TogetherArt(
              TogetherAssets.mapBackground,
              fallbackIcon: CupertinoIcons.map,
              fit: BoxFit.cover,
              placeholder: false,
            ),
          ),
          Positioned(
            left: textWidth - 8,
            right: 0,
            top: 0,
            bottom: 0,
            child: _Route(west: west, east: east),
          ),
          Padding(
            padding: const EdgeInsets.all(TogetherStyle.pad),
            child: SizedBox(
              width: textWidth - TogetherStyle.pad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TogetherCardHeader(
                    icon: CupertinoIcons.location_solid,
                    iconColor: TogetherStyle.iconMap,
                    title: 'Our Map',
                    subtitle: journey == null
                        ? 'Add your cities'
                        : '${journey.distanceLabel} apart',
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    journey == null
                        ? 'Set where you are in Settings to see the miles '
                            'between you.'
                        : 'Different places, same direction. ♡',
                    style: TogetherStyle.tagline(),
                  ),
                  const SizedBox(height: AppSpace.compact),
                  TogetherPill(
                    label: 'Open map',
                    style: TogetherPillStyle.soft,
                    small: true,
                    onTap: open,
                  ),
                ],
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

/// The two of you and the dashed line between.
class _Route extends StatelessWidget {
  const _Route({required this.west, required this.east});

  final UserProfile? west, east;

  static const _avatar = 40.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        // Each face sits above its dot; the line runs dot to dot.
        final a = Offset(w * .17, h * .30);
        final b = Offset(w * .83, h * .40);
        final dotA = a + const Offset(12, _avatar / 2 + 4);
        final dotB = b + const Offset(-12, _avatar / 2 + 4);
        return Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: CustomPaint(
              painter: TogetherRoutePainter(
                from: dotA,
                to: dotB,
                color: TogetherStyle.mapPath,
              ),
            ),
          ),
          _face(west, a),
          _face(east, b),
          _dot(dotA),
          _dot(dotB),
          _place(west, a, w),
          _place(east, b, w),
        ]);
      });

  Widget _face(UserProfile? who, Offset at) => Positioned(
        left: at.dx - _avatar / 2,
        top: at.dy - _avatar / 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 2.5),
            boxShadow: TogetherStyle.cardShadow,
          ),
          child: UserAvatar(who, size: _avatar),
        ),
      );

  Widget _dot(Offset at) => Positioned(
        left: at.dx - 6,
        top: at.dy - 6,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: TogetherStyle.mapDot,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 2.5),
          ),
        ),
      );

  /// "• Dubai" over "United Arab Emirates", under the face.
  Widget _place(UserProfile? who, Offset at, double width) {
    final city = who?.city;
    if (city == null || city.trim().isEmpty) return const SizedBox.shrink();
    final parts = city.split(',');
    final name = parts.first.trim();
    final country = parts.skip(1).join(',').trim();
    final labelWidth = width * .44;
    return Positioned(
      left: (at.dx - labelWidth / 2).clamp(0.0, width - labelWidth),
      top: at.dy + _avatar / 2 + 12,
      width: labelWidth,
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.brandLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TogetherStyle.placeName()),
          ),
        ]),
        if (country.isNotEmpty)
          Text(country,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TogetherStyle.listMeta()),
      ]),
    );
  }
}

/// A dashed arc from [from] to [to], bowed upward, with a plane at its
/// middle pointing the way it is going.
class TogetherRoutePainter extends CustomPainter {
  const TogetherRoutePainter({
    required this.from,
    required this.to,
    required this.color,
  });

  final Offset from, to;
  final Color color;

  /// The arc as a quadratic curve. Public so a test can check the plane
  /// really sits on the line rather than near it.
  Path get path {
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    final lift = (to.dx - from.dx).abs() * .32;
    final control = Offset(mid.dx, math.min(from.dy, to.dy) - lift);
    return Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final metric = path.computeMetrics().first;
    const dash = 6.0, gap = 5.0;
    // The dashes stop short of the plane on either side, so it sits in a
    // clear patch of sky rather than on top of a line.
    final middle = metric.length / 2;
    const clear = 16.0;
    for (var d = 0.0; d < metric.length; d += dash + gap) {
      final end = math.min(d + dash, metric.length);
      if (end > middle - clear && d < middle + clear) continue;
      canvas.drawPath(metric.extractPath(d, end), line);
    }

    final tangent = metric.getTangentForOffset(middle);
    if (tangent == null) return;
    canvas.save();
    canvas.translate(tangent.position.dx, tangent.position.dy);
    // Icons.flight points up; the tangent's angle is measured from the
    // x-axis with y down, so a quarter turn lines the nose up with it.
    canvas.rotate(-tangent.angle + math.pi / 2);
    const icon = Icons.flight_rounded;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 24,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(TogetherRoutePainter old) =>
      old.from != from || old.to != to || old.color != color;
}

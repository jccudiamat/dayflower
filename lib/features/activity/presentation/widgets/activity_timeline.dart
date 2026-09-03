import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../data/activity_models.dart';
import '../../data/activity_repository.dart';

/// The timeline itself — a dotted rail down the left, a card per activity.
///
/// The rail is what makes three unrelated events read as one sequence
/// instead of three stacked cards, and the filled first dot is what says
/// "this is the newest" without a label spending a line on it.
class ActivityTimeline extends ConsumerWidget {
  const ActivityTimeline({
    super.key,
    required this.activities,
    this.lastSeen,
  });

  final List<Activity> activities;

  /// Anything the partner did after this is drawn as new. Null means the
  /// watermark has never been written — a first run, where everything
  /// present is genuinely unseen.
  final DateTime? lastSeen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(currentUserIdProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final partnerName =
        partner?.petName ?? partner?.displayName ?? 'Your partner';

    return Column(
      children: [
        for (var i = 0; i < activities.length; i++)
          _TimelineRow(
            activity: activities[i],
            isFirst: i == 0,
            isLast: i == activities.length - 1,
            myUserId: myId,
            partnerName: partnerName,
            isNew: _isNew(activities[i], myId),
          ),
      ],
    );
  }

  bool _isNew(Activity a, String? myId) {
    if (a.isMine(myId) || a.actorId == null) return false;
    return lastSeen == null || a.createdAt.isAfter(lastSeen!);
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.activity,
    required this.isFirst,
    required this.isLast,
    required this.myUserId,
    required this.partnerName,
    required this.isNew,
  });

  final Activity activity;
  final bool isFirst;
  final bool isLast;
  final String? myUserId;
  final String partnerName;
  final bool isNew;

  /// Where the dot sits from the top of the row — level with the kind pill,
  /// so the rail lines up with the first thing you read rather than with the
  /// middle of a card whose height depends on how long the title is.
  static const _dotCentre = 30.0;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight so the rail can be told how tall the card next to it
    // is. Expensive in general, cheap here: three rows on Home, and a list
    // that tops out at ActivityRepository.feedLimit on the full screen.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: CustomPaint(
              painter: _RailPainter(
                isFirst: isFirst,
                isLast: isLast,
                filled: isFirst,
                colour: activity.kind.tint,
                dotCentre: _dotCentre,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: _ActivityCard(
                activity: activity,
                myUserId: myUserId,
                partnerName: partnerName,
                isNew: isNew,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dot, and the dashes above and below it.
///
/// Hand-painted for the same reason the empty day arch is: Flutter has no
/// dashed border, and faking one with a stack of small boxes means the gap
/// count changes with the card height and the dashes stop meeting the dot.
class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.isFirst,
    required this.isLast,
    required this.filled,
    required this.colour,
    required this.dotCentre,
  });

  final bool isFirst;
  final bool isLast;
  final bool filled;
  final Color colour;
  final double dotCentre;

  static const _dash = 4.0;
  static const _gap = 4.0;
  static const _radius = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;

    final line = Paint()
      ..color = AppColors.blushMid
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // Above the dot only when there is something above to connect to.
    if (!isFirst) _dashes(canvas, x, 0, dotCentre - _radius - 3, line);
    // Below always stops short of the row's bottom edge, so consecutive
    // rows read as one continuing line rather than a series of touching
    // segments.
    if (!isLast) _dashes(canvas, x, dotCentre + _radius + 3, size.height, line);

    final ring = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(x, dotCentre), _radius, ring);

    if (filled) {
      canvas.drawCircle(
        Offset(x, dotCentre),
        _radius - 3,
        Paint()..color = colour,
      );
    }
  }

  void _dashes(Canvas canvas, double x, double from, double to, Paint paint) {
    var y = from;
    while (y < to) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + _dash, to)),
        paint,
      );
      y += _dash + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _RailPainter old) =>
      old.isFirst != isFirst ||
      old.isLast != isLast ||
      old.filled != filled ||
      old.colour != colour;
}

/// One activity, as something to tap.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.myUserId,
    required this.partnerName,
    required this.isNew,
  });

  final Activity activity;
  final String? myUserId;
  final String partnerName;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final kind = activity.kind;
    final route = activity.route;
    final when = timeago.format(activity.createdAt, locale: 'en_short');

    return Semantics(
      button: route != null,
      label: '${kind.label}. ${activity.title}. '
          '${activity.sentence(myUserId: myUserId, partnerName: partnerName)}, '
          '$when ago',
      child: Material(
        // A wash of the kind's own colour rather than a fill of it: these
        // are palette colours at full strength and a card painted in one
        // would shout louder than anything else on Home.
        color: kind.tint.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          // Untappable only for a kind this build has never heard of, where
          // there is genuinely nowhere honest to send anyone.
          onTap: route == null ? null : () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _KindPill(kind: kind),
                          if (isNew) ...[
                            const SizedBox(width: AppSpace.xxs),
                            const _NewDot(),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        activity.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.subtitle(AppColors.ink),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${activity.sentence(myUserId: myUserId, partnerName: partnerName)}'
                        '  ·  $when',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(AppColors.body),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                Text(activity.emoji, style: const TextStyle(fontSize: 30)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KindPill extends StatelessWidget {
  const _KindPill({required this.kind});
  final ActivityKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: kind.tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        kind.label.toUpperCase(),
        style: AppText.label(Colors.white),
      ),
    );
  }
}

/// The "you haven't seen this" marker. A dot, not a word — it sits beside a
/// pill that is already carrying text.
class _NewDot extends StatelessWidget {
  const _NewDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: AppColors.brand,
        shape: BoxShape.circle,
      ),
    );
  }
}

/* ── The Home section ─────────────────────── */

/// The three most recent activities, with a way through to the rest.
///
/// Lives on Home rather than behind the Activities tab because the whole
/// point is finding out something happened without going looking for it.
class ActivitySection extends ConsumerWidget {
  const ActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentActivitiesProvider);
    final unseen = ref.watch(unseenActivityCountProvider);
    final lastSeen = ref.watch(activityLastSeenProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('ACTIVITY', style: AppText.label()),
            if (unseen > 0) ...[
              const SizedBox(width: AppSpace.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  unseen > 9 ? '9+' : '$unseen',
                  style: AppText.label(Colors.white).copyWith(fontSize: 9.5),
                ),
              ),
            ],
            const Spacer(),
            // Hidden while there is nothing to see all of — a link to an
            // empty screen is a worse answer than no link.
            if ((recent.valueOrNull ?? const []).isNotEmpty)
              _ViewAllButton(
                onTap: () => context.go(Routes.activityFeed),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        recent.when(
          loading: () => const _FeedPlaceholder(text: 'Catching up…'),
          // Says what failed. "Nothing yet" here would be the app inventing
          // an answer it does not have.
          error: (_, __) => const _FeedPlaceholder(
            text: "Couldn't load your activity.",
          ),
          data: (list) => list.isEmpty
              ? const _FeedEmpty()
              : ActivityTimeline(activities: list, lastSeen: lastSeen),
        ),
      ],
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text(
            'View all',
            style: AppText.caption(AppColors.secondary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 2),
          const Icon(CupertinoIcons.chevron_forward,
              size: 12, color: AppColors.secondary),
        ],
      ),
    );
  }
}

class _FeedPlaceholder extends StatelessWidget {
  const _FeedPlaceholder({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.caption(AppColors.muted),
      ),
    );
  }
}

/// Nothing has happened yet — which on a brand new feed is the truth, since
/// migration 0019 deliberately backfills nothing.
class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 26)),
          const SizedBox(height: AppSpace.xxs),
          Text(
            'Nothing yet',
            style: AppText.subtitle(AppColors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            'Set a reminder, add a goal or start a photo strip — '
            'it turns up here for both of you.',
            textAlign: TextAlign.center,
            style: AppText.caption(AppColors.muted),
          ),
        ],
      ),
    );
  }
}

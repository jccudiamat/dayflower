import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/services/pulse_alerts.dart';
import '../../../heartbeat/data/heartbeat_repository.dart';
import '../../../heartbeat/data/pulse_alert_prefs.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../../tulip/presentation/widgets/conversation_card.dart';
import '../../data/mood_prefs.dart';
import '../../../../core/utils/zone_distance.dart';
import '../../../../core/widgets/timezone_picker.dart';
import '../../../tulip/data/flower_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: ListView(
          padding: AppSpace.screen,
          children: [
            const SizedBox(height: AppSpace.md),
            const _HomeHeader(),
            const SizedBox(height: AppSpace.md),
            const _MoodCard(),
            const SizedBox(height: AppSpace.sm),
            const _HeartbeatCard(),
            const SizedBox(height: AppSpace.sm),
            // The conversation, not the reunion countdown — that already
            // lives on Dates, and having it twice meant two places to
            // keep in step for no extra information.
            const ConversationCard(),
            const SizedBox(height: AppSpace.md),
          ],
        ),
      ),
    );
  }
}

/* ── Mood card ───────────────────────────── */
/// A one-tap check-in, sized to be glanced at rather than read.
///
/// Chips are laid out with [Expanded] instead of fixed widths so six of them
/// still fit on a 320pt screen without overflowing.
class _MoodCard extends ConsumerWidget {
  const _MoodCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = ref.watch(moodProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('SET YOUR MOOD', style: AppText.label())),
              Text(
                mood?.label ?? 'Tap one',
                style: AppText.caption(
                  mood == null ? AppColors.muted : AppColors.brand,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              for (final m in Mood.values) ...[
                Expanded(
                  child: _MoodChip(
                    mood: m,
                    selected: mood == m,
                    onTap: () => ref.read(moodProvider.notifier).select(m),
                  ),
                ),
                if (m != Mood.values.last) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final Mood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: AnimatedContainer(
          duration: AppMotion.micro,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.blush : AppColors.background,
            shape: BoxShape.circle,
            // design.md: selection reads as a tinted outline, not a fill swap.
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            mood.emoji,
            style: const TextStyle(fontSize: 19),
            semanticsLabel: mood.label,
          ),
        ),
      ),
    );
  }
}

/* ── Heartbeat card ──────────────────────────────── */
class _HeartbeatCard extends ConsumerStatefulWidget {
  const _HeartbeatCard();

  @override
  ConsumerState<_HeartbeatCard> createState() => _HeartbeatCardState();
}

class _HeartbeatCardState extends ConsumerState<_HeartbeatCard>
    with TickerProviderStateMixin {
  /// The heart itself. Ripples are sized relative to it.
  static const double _heartSize = 84;

  /// Big enough to hold a fully expanded incoming ripple without clipping —
  /// [Stack] clips by default, so this and [_incomingGrowth] move together.
  static const double _stageSize = 190;

  static const double _incomingGrowth = 106;
  static const Duration _incomingDuration = Duration(milliseconds: 1200);

  late final AnimationController _scaleCtrl;

  /// Double-thump (lub-dub) played on the receiving side only.
  late final AnimationController _beatCtrl;
  late final Animation<double> _beat;

  int _rippleSeed = 0;
  final List<_Ripple> _ripples = [];

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
      lowerBound: 0,
      upperBound: 0.12,
    );
    _beatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _beat = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.22).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.22, end: 1.04).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.04, end: 1.14).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.14, end: 1.0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 24,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 38),
    ]).animate(_beatCtrl);
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _beatCtrl.dispose();
    super.dispose();
  }

  void _addRipple(_Ripple ripple) {
    setState(() => _ripples.add(ripple));
    Future.delayed(ripple.delay + ripple.duration, () {
      if (mounted) setState(() => _ripples.remove(ripple));
    });
  }

  /// Your own tap — a single modest ring. Deliberately smaller than the
  /// incoming one: receiving should feel bigger than sending.
  void _spawnSentRipple() {
    _addRipple(
      _Ripple(
        id: _rippleSeed++,
        color: AppColors.brand,
        growth: 40,
        duration: AppMotion.emotional,
        strokeWidth: 2,
      ),
    );
  }

  /// Their tap — three staggered rings sweeping out to the edge of the stage,
  /// the first carrying a soft bloom behind the heart.
  void _spawnIncomingRipples() {
    for (var i = 0; i < 3; i++) {
      _addRipple(
        _Ripple(
          id: _rippleSeed++,
          color: AppColors.lavender,
          growth: _incomingGrowth,
          duration: _incomingDuration,
          delay: Duration(milliseconds: i * 200),
          strokeWidth: 3 - i * 0.6,
          bloom: i == 0,
        ),
      );
    }
  }

  void _onTap() {
    HapticFeedback.mediumImpact();
    _scaleCtrl.forward().then((_) => _scaleCtrl.reverse());
    _spawnSentRipple();

    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) {
      debugPrint('heartbeat blocked: pair=${pair?.id} userId=$userId');
      return;
    }
    // Fire and forget — the stream updates the count.
    ref
        .read(heartbeatRepositoryProvider)
        .send(pairId: pair.id, senderId: userId)
        .catchError((Object e) => debugPrint('heartbeat send failed: $e'));
  }

  @override
  Widget build(BuildContext context) {
    final counts = ref.watch(todayHeartbeatCountsProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    // Fallback must read naturally in "X hasn't tapped yet today" while the
    // partner profile is still loading.
    final partnerName =
        partner?.petName ?? partner?.displayName ?? 'Your partner';

    // Incoming partner beat → big lavender ripple, a double-thump on the
    // heart, and (opt-in) a buzz + heartbeat sound.
    ref.listen(todayHeartbeatCountsProvider, (prev, next) {
      if (prev == null || next.partner <= prev.partner) return;
      _spawnIncomingRipples();
      _beatCtrl.forward(from: 0);

      final alerts = ref.read(pulseAlertSettingsProvider);
      if (alerts.enabled) {
        // Throttling lives in the service — it may decide this one only
        // updates the existing notification without buzzing.
        PulseAlerts.handleIncoming(
          from: partnerName,
          pulses: next.partner - prev.partner,
          cadence: alerts.cadence,
        );
      } else {
        HapticFeedback.lightImpact();
      }
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text('HEARTBEAT', style: AppText.label()),
          const SizedBox(height: AppSpace.xs),
          SizedBox(
            width: _stageSize,
            height: _stageSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final r in _ripples)
                  _RippleRing(
                    key: ValueKey(r.id),
                    ripple: r,
                    baseSize: _heartSize,
                  ),
                AnimatedBuilder(
                  animation: Listenable.merge([_scaleCtrl, _beatCtrl]),
                  builder: (context, child) => Transform.scale(
                    scale: (1 + _scaleCtrl.value) * _beat.value,
                    child: child,
                  ),
                  child: GestureDetector(
                    onTap: _onTap,
                    child: Container(
                      width: _heartSize,
                      height: _heartSize,
                      decoration: BoxDecoration(
                        gradient: AppGradients.brand,
                        shape: BoxShape.circle,
                        boxShadow: AppElevation.glow,
                      ),
                      child: const Icon(
                        CupertinoIcons.heart_fill,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            counts.mine == 0
                ? 'Tap to send a pulse'
                : 'Tapped ${counts.mine}× today',
            style: AppText.subtitle(),
          ),
          const SizedBox(height: 2),
          Text(
            counts.partner == 0
                ? "$partnerName hasn't tapped yet today"
                : '$partnerName sent ${counts.partner} ${counts.partner == 1 ? "pulse" : "pulses"} today 💗',
            style: AppText.caption(),
          ),
        ],
      ),
    );
  }
}

/// One expanding ring. Several of these, staggered, make the incoming pulse.
class _Ripple {
  _Ripple({
    required this.id,
    required this.color,
    required this.growth,
    required this.duration,
    required this.strokeWidth,
    this.delay = Duration.zero,
    this.bloom = false,
  });

  final int id;
  final Color color;

  /// How much wider than the heart the ring gets, in logical pixels.
  final double growth;
  final Duration duration;
  final double strokeWidth;
  final Duration delay;

  /// Fills the ring with a faint wash as well as stroking it.
  final bool bloom;
}

class _RippleRing extends StatefulWidget {
  const _RippleRing({
    super.key,
    required this.ripple,
    required this.baseSize,
  });

  final _Ripple ripple;
  final double baseSize;

  @override
  State<_RippleRing> createState() => _RippleRingState();
}

class _RippleRingState extends State<_RippleRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.ripple.duration);
    if (widget.ripple.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.ripple.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ripple;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final v = Curves.easeOut.transform(_ctrl.value);
          // Fade late rather than linearly, so the ring stays readable most of
          // the way out instead of vanishing at half radius.
          final fade = (1 - v * v).clamp(0.0, 1.0);
          final size = widget.baseSize + r.growth * v;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: r.bloom
                  ? r.color.withValues(alpha: 0.14 * fade)
                  : null,
              border: Border.all(
                color: r.color.withValues(alpha: fade),
                width: r.strokeWidth,
              ),
            ),
          );
        },
      ),
    );
  }
}
/* ── Header ──────────────────────────────── */

/// The greeting block: who you are to them, where they are, and how far
/// away that is — with today's photos standing beside it.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  static String _greetingFor(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning,';
    if (h < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;

    // The greeting uses the name they call you — that is the whole point of
    // a pet name, and "Good morning, Bunny" is the line this screen exists
    // to open with.
    final myName = profile?.petName ?? profile?.displayName ?? '…';

    final partnerName = partner?.petName ?? partner?.displayName;
    final partnerZone = partner?.timezone;
    final partnerTime = partnerZone == null
        ? null
        : tz.TZDateTime.now(safeLocation(partnerZone));

    final distance = distanceLabel(profile?.timezone, partnerZone);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greetingFor(DateTime.now()), style: AppText.display()),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      myName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(AppColors.brandDark),
                    ),
                  ),
                  const SizedBox(width: AppSpace.xxs),
                  const Text('🌷', style: TextStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: AppSpace.xs),

              // Where they are and what time it is there. One line, because
              // it is one thought.
              if (partnerName != null && partnerTime != null)
                Text(
                  '$partnerName · ${zoneCity(partnerZone!)} · '
                  '${DateFormat('h:mm a').format(partnerTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(AppColors.body),
                ),

              // Replaces the old "Day N together". A streak counts how long
              // you have kept a habit; this counts what the app is actually
              // about. Hidden entirely when a zone is unknown rather than
              // guessed at.
              if (distance != null) ...[
                const SizedBox(height: 2),
                Text(distance, style: AppText.body(AppColors.body)),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        const _DayArch(),
      ],
    );
  }
}

/// The arched panel beside the greeting: their day on top, yours beneath.
///
/// Proportions follow the reference — a tall arch, roughly 2:3, with the
/// top corners rounded far more than the bottom so it reads as a window
/// rather than a card.
class _DayArch extends ConsumerWidget {
  const _DayArch();

  static const double _width = 132;
  static const double _aspect = 0.68; // width ÷ height

  static const _shape = BorderRadius.only(
    topLeft: Radius.circular(64),
    topRight: Radius.circular(64),
    bottomLeft: Radius.circular(AppRadius.lg),
    bottomRight: Radius.circular(AppRadius.lg),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theirs = ref.watch(partnerDayPhotoProvider);
    final mine = ref.watch(myDayPhotoProvider);

    return SizedBox(
      width: _width,
      height: _width / _aspect,
      child: GestureDetector(
        onTap: () => context.go(Routes.chat),
        child: ClipRRect(
          borderRadius: _shape,
          child: _content(theirs, mine),
        ),
      ),
    );
  }

  Widget _content(FlowerMessage? theirs, FlowerMessage? mine) {
    // Both: stacked, theirs on top — the whole point of the panel is
    // seeing their day first.
    if (theirs != null && mine != null) {
      return Column(
        children: [
          Expanded(child: _DayPhoto(message: theirs)),
          const SizedBox(height: 3),
          Expanded(child: _DayPhoto(message: mine)),
        ],
      );
    }
    // One: it fills the arch. Half a panel with an empty space under it
    // would read as something failing to load.
    final only = theirs ?? mine;
    if (only != null) return _DayPhoto(message: only);
    return const _DayEmpty();
  }
}

/// One day photo, filling whatever box it is given.
class _DayPhoto extends ConsumerWidget {
  const _DayPhoto({required this.message});

  final FlowerMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future:
          ref.read(flowerRepositoryProvider).signedPhotoUrl(message.imagePath!),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(color: AppColors.surfaceSubtle);
        }
        return Image.network(
          snap.data!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          // A failed image inside a decorative panel should look like the
          // empty state, not like a broken page.
          errorBuilder: (_, __, ___) =>
              Container(color: AppColors.surfaceSubtle),
        );
      },
    );
  }
}

/// Nothing shared today, by either of them.
class _DayEmpty extends StatelessWidget {
  const _DayEmpty();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedArchPainter(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📷', style: TextStyle(fontSize: 22)),
              const SizedBox(height: AppSpace.xxs),
              Text(
                'Share your day',
                textAlign: TextAlign.center,
                style: AppText.caption(AppColors.brand)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed outline in the arch shape.
///
/// Hand-painted because Flutter's border side has no dash support and
/// `ClipRRect` cannot outline what it clips — a dotted rectangle behind an
/// arch-shaped hole would show the mismatch at the corners.
class _DashedArchPainter extends CustomPainter {
  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          rect.deflate(1),
          topLeft: const Radius.circular(64),
          topRight: const Radius.circular(64),
          bottomLeft: const Radius.circular(AppRadius.lg),
          bottomRight: const Radius.circular(AppRadius.lg),
        ),
      );

    final paint = Paint()
      ..color = AppColors.blushMid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + _dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedArchPainter oldDelegate) => false;
}

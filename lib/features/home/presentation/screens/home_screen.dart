import 'package:dayflower/core/widgets/app_icon.dart';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../app_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../heartbeat/data/heartbeat_repository.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/mood_prefs.dart';
import '../../domain/greeting_flower.dart';
import '../../../../core/utils/zone_distance.dart';
import '../../../../core/widgets/timezone_picker.dart';
import '../../../tulip/data/flower_repository.dart';
import '../../../tulip/presentation/widgets/share_your_day.dart';
import '../../../activity/data/activity_repository.dart';
import '../widgets/home_upcoming_events.dart';
import '../widgets/home_throwback.dart';
import '../widgets/home_map_card.dart';
import '../widgets/home_widget_gallery.dart';
import '../../domain/home_moments.dart';
import '../../../../core/widgets/user_avatar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(homeClockProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeClockProvider, (previous, next) {
      if (previous?.hasValue != true || !next.hasValue) return;
      ref.invalidate(partnerMoodProvider);
      ref.invalidate(todayHeartbeatCountsProvider);
      ref.invalidate(myDayPhotoProvider);
      ref.invalidate(partnerDayPhotoProvider);
    });
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        // CustomScrollView rather than ListView so the top bar can be a
        // sliver: `floating` lets it slide away as you read down the page
        // and `snap` brings the whole thing back on the first upward
        // flick, instead of dragging it in a pixel at a time.
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              titleSpacing: 0,
              toolbarHeight: 56,
              automaticallyImplyLeading: false,
              title: const Padding(
                padding: AppSpace.screen,
                child: _HomeBar(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  Center(
                      child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HomeHeader(),
                          SizedBox(height: AppSpace.md),
                          HomeMapCard(),
                          SizedBox(height: AppSpace.md),
                          _HeartbeatCard(),
                          SizedBox(height: AppSpace.md),
                          HomeUpcomingEvents(),
                          SizedBox(height: AppSpace.md),
                          HomeThrowback(),
                          HomeWidgetGallery(),
                        ]),
                  )),
                ]),
              ),
            ),
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

    // ⚠️ No Container of its own: this is the lower half of the heartbeat
    // card, so the surface, radius and border come from the parent.
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text('HOW ARE YOU FEELING?', style: AppText.label())),
            // ⚠️ Nothing here until something is chosen. The old placeholder
            // read "Tap one", which is an instruction sitting where an answer
            // goes and left the row looking answered before it was.
            if (mood != null)
              Text(mood.label,
                  style: AppText.caption(AppColors.brand)
                      .copyWith(fontWeight: FontWeight.w600)),
          ]),
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
        ]);
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
    return Semantics(
        button: true,
        selected: selected,
        label: mood.label,
        child: GestureDetector(
          onTap: onTap,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AspectRatio(
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
                // The Semantics wrapper already names this mood; without an
                // empty label here a screen reader says it twice.
                semanticsLabel: '',
              ),
            ),
            ),
          ]),
        ));
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
  static const double _heartSize = 64;

  /// Big enough to hold a fully expanded incoming ripple without clipping —
  /// [Stack] clips by default, so this and [_incomingGrowth] move together.
  static const double _stageSize = 96;

  static const double _incomingGrowth = 32;
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
        growth: 24,
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
        .catchError((Object e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not send the heartbeat. Try again.')));
      }
    });
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
    // heart. Notification delivery is owned by the app root.
    ref.listen(todayHeartbeatCountsProvider, (prev, next) {
      if (prev == null || next.partner <= prev.partner) return;
      _spawnIncomingRipples();
      _beatCtrl.forward(from: 0);
    });

    ref.watch(homeClockProvider);
    final mood = ref.watch(partnerMoodProvider);
    final pair = ref.watch(currentPairProvider).valueOrNull;
    final enabled = pair?.isLinked == true;
    final title = !enabled
        ? 'A heartbeat for your person'
        : mood == null
            ? 'Send $partnerName a heartbeat'
            : '$partnerName is feeling ${mood.label.toLowerCase()} ${mood.emoji}';
    final text =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: AppText.subtitle()),
      const SizedBox(height: AppSpace.xs),
      Text(
          !enabled
              ? 'Connect with your partner on Us'
              : mood == null
                  ? 'A little hello, just because'
                  : 'Send a little love back',
          style: AppText.body()),
      const SizedBox(height: AppSpace.sm),
      if (counts.mine == 0 && counts.partner == 0)
        Text('No heartbeats yet today', style: AppText.caption())
      else
        Wrap(spacing: 10, runSpacing: 4, children: [
          Text('You sent ${counts.mine}', style: AppText.caption()),
          Text('$partnerName sent ${counts.partner}', style: AppText.caption()),
        ]),
    ]);
    final action = Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
          width: _stageSize,
          height: _stageSize,
          child: Stack(alignment: Alignment.center, children: [
            for (final r in _ripples)
              _RippleRing(key: ValueKey(r.id), ripple: r, baseSize: _heartSize),
            AnimatedBuilder(
                animation: Listenable.merge([_scaleCtrl, _beatCtrl]),
                builder: (context, child) => Transform.scale(
                    scale: (1 + _scaleCtrl.value) * _beat.value, child: child),
                child: Semantics(
                    button: true,
                    enabled: enabled,
                    label: 'Send a heartbeat',
                    child: GestureDetector(
                        onTap: enabled ? _onTap : null,
                        child: Opacity(
                            opacity: enabled ? 1 : .45,
                            child: Container(
                              width: _heartSize,
                              height: _heartSize,
                              decoration: BoxDecoration(
                                  gradient: AppGradients.brand,
                                  shape: BoxShape.circle,
                                  boxShadow: AppElevation.glow),
                              child: const AppIcon(CupertinoIcons.heart_fill,
                                  color: Colors.white, size: 32),
                            ))))),
          ])),
      Text(enabled ? 'Tap to send' : 'Pair first',
          style: AppText.caption(), textAlign: TextAlign.center),
    ]);
    // 🔴 One card, holding both halves. The heartbeat and the mood
    // check-in were two separate surfaces asking the same question a few
    // pixels apart; they are now stacked inside a single shell. Neither
    // half's own layout was altered — this is a merge of the containers,
    // not a redesign of what is in them.
    final heartbeat = LayoutBuilder(builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) / 14 > 1.5;
        if (constraints.maxWidth < 250 || largeText) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                const SizedBox(height: AppSpace.md),
                Center(child: action),
              ]);
        }
        return Row(children: [
          Expanded(child: text),
          const SizedBox(width: 12),
          SizedBox(width: _stageSize, child: action)
        ]);
      });

    return Container(
      key: const ValueKey('home-heartbeat'),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm, vertical: AppSpace.sm),
      decoration: _homeCardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        heartbeat,
        const SizedBox(height: AppSpace.sm),
        const _MoodCard(),
      ]),
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
              color: r.bloom ? r.color.withValues(alpha: 0.14 * fade) : null,
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

BoxDecoration _homeCardDecoration() => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.xl),
    border: Border.all(color: AppColors.border));

void _shareDay(BuildContext context, WidgetRef ref) {
  ref.read(dayPhotoTargetProvider.notifier).state = DayPhotoTarget.widget;
  context.push(Routes.flowers);
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(homeClockProvider).valueOrNull ?? DateTime.now();
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final name = profile?.petName ?? profile?.displayName ?? 'there';
    final partnerName = partner?.petName ?? partner?.displayName;
    final zone = partner?.timezone;
    final local =
        zone == null ? null : tz.TZDateTime.from(now, safeLocation(zone));
    final distance = profileDistanceLabel(profile, partner);
    final period = now.hour < 12
        ? 'morning'
        : now.hour < 18
            ? 'afternoon'
            : 'evening';
    return LayoutBuilder(builder: (context, box) {
      final gap = box.maxWidth < 320
          ? 4.0
          : box.maxWidth < 500
              ? 6.0
              : 16.0;
      final deckWidth = math.min(360.0, (box.maxWidth - gap) * .52);
      final heading =
          AppText.display().copyWith(fontSize: box.maxWidth < 320 ? 26 : 30);
      final greeting = Column(
        key: const ValueKey('home-greeting'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good $period,',
              key: const ValueKey('greeting-title'), style: heading),
          const SizedBox(height: 2),
          Row(children: [
            Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: heading.copyWith(color: AppColors.brandDark))),
            const SizedBox(width: AppSpace.xxs),
            Text(greetingFlower, style: const TextStyle(fontSize: 22)),
          ]),
          if (local != null && partnerName != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
                '$partnerName · ${partner?.city?.split(',').first.trim() ?? zoneCity(zone!)} · ${DateFormat('h:mm a').format(local).replaceAll(' ', '\u00a0')}',
                style: AppText.body()),
          ],
          if (distance != null) ...[
            const SizedBox(height: 2),
            Text(distance, style: AppText.body()),
          ],
        ],
      );
      return Padding(
        key: const ValueKey('home-my-day'),
        padding: const EdgeInsets.only(top: 16),
        child: Row(
            key: const ValueKey('my-day-side-by-side'),
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: greeting),
              SizedBox(width: gap),
              SizedBox(width: deckWidth, child: const _DayArch()),
            ]),
      );
    });
  }
}

class _DayArch extends ConsumerStatefulWidget {
  const _DayArch();
  @override
  ConsumerState<_DayArch> createState() => _DayArchState();
}

class _DayArchState extends ConsumerState<_DayArch> {
  bool _mineInFront = false;
  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myDayPhotoProvider);
    final theirs = ref.watch(partnerDayPhotoProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final name = partner?.petName ?? partner?.displayName ?? 'Your partner';
    final both = mine != null && theirs != null;
    final mineFront = theirs == null || (both && _mineInFront);
    return Column(
        key: const ValueKey('home-photo-deck'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: LayoutBuilder(builder: (context, box) {
                    final w = box.maxWidth;
                    final compact = w < 240;
                    final cardWidth = w * (compact ? .80 : .76);
                    final rearWidth = w * .66;
                    final textScale =
                        MediaQuery.textScalerOf(context).scale(14) / 14;
                    final h = math.max(cardWidth / .72,
                            compact ? 170.0 : 280.0) *
                        math.pow(math.max(1.0, textScale), 1.5);
                    Widget card({required bool own, required bool front}) {
                      final msg = own ? mine : theirs;
                      final label = own ? 'Your day' : "$name’s day";
                      final shape = BorderRadius.vertical(
                          top: Radius.circular(cardWidth / 2),
                          bottom: const Radius.circular(AppRadius.lg));
                      return AnimatedPositioned(
                          key: ValueKey(
                              own ? 'my-day-photo' : 'partner-day-photo'),
                          duration: AppMotion.standard,
                          curve: AppMotion.easeOut,
                          left: front ? 0 : w - rearWidth - (h - 32) * .055,
                          top: front ? 0 : (compact ? 16 : 24),
                          width: front ? cardWidth : rearWidth,
                          height: front ? h : h - (compact ? 24 : 32),
                          child: AnimatedRotation(
                              turns: front ? 0 : 3 / 360,
                              duration: AppMotion.standard,
                              curve: AppMotion.easeOut,
                              child: ClipRRect(
                                  borderRadius: shape,
                                  child: CustomPaint(
                                      foregroundPainter: msg == null
                                          ? _EmptyArchOutline(
                                              shape,
                                              own
                                                  ? AppColors.brand
                                                  : AppColors.border,
                                              dashed: own)
                                          : null,
                                      child: Material(
                                          color: own
                                              ? Color.alphaBlend(
                                                  AppColors.blush
                                                      .withValues(alpha: .5),
                                                  AppColors.surface)
                                              : AppColors.surfaceSubtle,
                                          child: InkWell(
                                            onTap: msg == null
                                                ? (own
                                                    ? () =>
                                                        _shareDay(context, ref)
                                                    : null)
                                                : () {
                                                    if (both && !front) {
                                                      setState(() =>
                                                          _mineInFront = own);
                                                    } else {
                                                      _open(msg, label);
                                                    }
                                                  },
                                            child: msg == null
                                                ? (front
                                                    ? _empty(name, own, compact)
                                                    : Align(
                                                        alignment:
                                                            const Alignment(
                                                                1, 0),
                                                        child: AppIcon(
                                                            CupertinoIcons
                                                                .photo,
                                                            size: compact
                                                                ? 24
                                                                : 40,
                                                            color: AppColors
                                                                .muted
                                                                .withValues(
                                                                    alpha:
                                                                        .65))))
                                                : Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                        HomeDayPhoto(
                                                            message: msg),
                                                        if (front)
                                                          Positioned(
                                                              left: 0,
                                                              right: 0,
                                                              bottom: 0,
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .fromLTRB(
                                                                        8,
                                                                        24,
                                                                        8,
                                                                        12),
                                                                decoration: const BoxDecoration(
                                                                    gradient: LinearGradient(
                                                                        begin: Alignment
                                                                            .topCenter,
                                                                        end: Alignment.bottomCenter,
                                                                        colors: [
                                                                      Colors
                                                                          .transparent,
                                                                      Colors
                                                                          .black54
                                                                    ])),
                                                                child: Text(
                                                                    '${own ? 'You' : name} · ${DateFormat('h:mm a').format(msg.sentAt.toLocal())}',
                                                                    style: AppText
                                                                        .caption(
                                                                            Colors.white)),
                                                              )),
                                                      ]),
                                          ))))));
                    }

                    return GestureDetector(
                        onHorizontalDragEnd: both
                            ? (_) =>
                                setState(() => _mineInFront = !_mineInFront)
                            : null,
                        child: SizedBox(
                            height: h + 8,
                            child: Stack(clipBehavior: Clip.none, children: [
                              card(own: !mineFront, front: false),
                              card(own: mineFront, front: true),
                            ])));
                  }))),
        ]);
  }

  Widget _empty(String name, bool own, bool compact) => Padding(
        padding: compact
            ? const EdgeInsets.fromLTRB(6, 4, 6, 4)
            : const EdgeInsets.fromLTRB(16, 36, 16, 24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Spacer(),
          AppIcon(own ? CupertinoIcons.camera : CupertinoIcons.photo,
              size: compact ? 24 : 44, color: AppColors.brand),
          SizedBox(height: compact ? 4 : 16),
          Text(own ? 'Your day starts here' : '$name’s day',
              textAlign: TextAlign.center,
              style: compact
                  ? AppText.caption(AppColors.ink)
                      .copyWith(fontWeight: FontWeight.w600)
                  : AppText.title()),
          const SizedBox(height: 6),
          Text(own ? 'Share a little moment' : 'Their photo will appear here',
              textAlign: TextAlign.center,
              style: compact
                  ? AppText.caption().copyWith(fontSize: 11)
                  : AppText.body(AppColors.muted)),
          if (own) ...[
            SizedBox(height: compact ? 8 : 20),
            Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: BoxDecoration(
                      gradient: AppGradients.cta,
                      borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    onTap: () => _shareDay(context, ref),
                    child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: compact ? 6 : 12,
                            vertical: compact ? 10 : 14),
                        child: Center(
                            child: Text('Share your day',
                                textAlign: TextAlign.center,
                                style: compact
                                    ? AppText.caption(Colors.white)
                                    : AppText.subtitle(Colors.white)))),
                  ),
                )),
          ],
          const Spacer(),
          SizedBox(height: compact ? 4 : 20),
          Text(own ? 'Your day' : '$name’s day',
              style: AppText.caption().copyWith(fontSize: compact ? 11 : 12.5)),
        ]),
      );

  void _open(FlowerMessage message, String who) {
    final mine = ref.read(myDayPhotosProvider);
    final index = mine.indexWhere((m) => m.id == message.id);
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => index >= 0
            ? MyDaysViewer(initialIndex: index)
            : DayPhotoViewer(message: message, who: who)));
  }
}

/// Shared by the live photo stack and the noninteractive widget preview.
class HomeDayPhoto extends ConsumerWidget {
  const HomeDayPhoto({super.key, required this.message});
  final FlowerMessage message;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = message.imagePath;
    if (path == null) return const Center(child: AppIcon(CupertinoIcons.photo));
    final url = ref.watch(dayPhotoUrlProvider(path));
    Widget unavailable() => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AppIcon(CupertinoIcons.photo),
          const SizedBox(height: 8),
          Text('Photo unavailable', style: AppText.caption()),
        ]));
    return url.when(
        loading: () =>
            Center(child: Text('Loading photo…', style: AppText.caption())),
        error: (_, __) => unavailable(),
        data: (value) => value == null
            ? unavailable()
            : Image.network(value,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => unavailable()));
  }
}

class _HomeBar extends ConsumerWidget {
  const _HomeBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(children: [
        Expanded(
            child: Text(AppConstants.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title().copyWith(fontWeight: FontWeight.w700))),
        IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push(Routes.notifications),
            icon: Badge(
                isLabelVisible: ref.watch(unseenActivityCountProvider) > 0,
                backgroundColor: AppColors.brand,
                child: AppIcon(CupertinoIcons.bell, color: AppColors.ink))),
        Semantics(
            label: 'Us, your couple page',
            button: true,
            child: Material(
                color: AppColors.surface,
                shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
                child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => context.push(Routes.us),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(
                              width: 44,
                              height: 28,
                              child: Stack(children: [
                                UserAvatar(
                                    ref.watch(userProfileProvider).valueOrNull,
                                    size: 28),
                                Positioned(
                                    left: 16,
                                    child: UserAvatar(
                                        ref
                                            .watch(partnerProfileProvider)
                                            .valueOrNull,
                                        size: 28)),
                              ])),
                          const SizedBox(width: 8),
                          Text('Us', style: AppText.caption(AppColors.ink)),
                          const SizedBox(width: 4),
                          const AppIcon(CupertinoIcons.chevron_down, size: 12),
                        ]))))),
      ]);
}

class _EmptyArchOutline extends CustomPainter {
  _EmptyArchOutline(this.shape, this.color, {this.dashed = true});
  final bool dashed;
  final BorderRadius shape;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(shape.toRRect((Offset.zero & size).deflate(1)));
    final paint = Paint()
      ..color = color.withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 10) {
        canvas.drawPath(
            metric.extractPath(offset, math.min(offset + 5, metric.length)),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EmptyArchOutline oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.color != color ||
      oldDelegate.dashed != dashed;
}

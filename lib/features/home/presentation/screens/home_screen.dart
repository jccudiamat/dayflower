import 'package:dayflower/core/widgets/app_icon.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../../../tulip/data/flower_repository.dart';
import '../../../tulip/domain/photo_shape.dart';
import '../../../../core/frames/photo_frames.dart';
import '../../../tulip/presentation/widgets/share_your_day.dart';
import '../../../activity/data/activity_repository.dart';
import '../widgets/home_upcoming_events.dart';
import '../widgets/home_throwback.dart';
import '../widgets/home_map_card.dart';
import '../widgets/home_widget_gallery.dart';
import '../../domain/home_moments.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/storage_image.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/models/user_profile.dart';

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

  /// Wide enough to hold a fully expanded incoming ripple, which is how
  /// much of the row the heart takes.
  static const double _stageSize = 96;

  /// Only as tall as the heart: the ripples spill past it (the stage does
  /// not clip), rather than a 96pt stage setting the height of the whole
  /// card round a 64pt heart.
  static const double _stageHeight = _heartSize;

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
    // One line under the title only when it tells you something to do. The
    // "send a little love back" line said again what the heart beside it
    // says, and cost the card a line of height.
    final text =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: AppText.subtitle()),
      if (!enabled) ...[
        const SizedBox(height: AppSpace.xs),
        Text('Connect with your partner on Us', style: AppText.body()),
      ],
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
          height: _stageHeight,
          child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
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
      // 🔴 No "Tap to send" under it. It said what a heart on a card already
      // says, and with the heart's stage it made the right half twice the
      // height of the words beside it, so the card was that tall too.
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
  ref.read(dayPhotoTargetProvider.notifier).state = DayPhotoTarget.myDay;
  context.push(Routes.flowers);
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(homeClockProvider).valueOrNull ?? DateTime.now();
    final profile = ref.watch(userProfileProvider).valueOrNull;
    // Live, so a note they leave arrives while you are looking.
    final partner = ref.watch(partnerProfileStreamProvider).valueOrNull ??
        ref.watch(partnerProfileProvider).valueOrNull;
    final name = profile?.petName ?? profile?.displayName ?? 'there';
    final partnerName =
        partner?.petName ?? partner?.displayName ?? 'Your partner';
    final linked = ref.watch(currentPairProvider).valueOrNull?.isLinked ?? false;
    final note = partner?.freshNote;
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
      // 🔴 **Their note, where the greeting was.** The line under the
      // greeting (their city, their time, the miles) said again what the
      // map card below says in full, so it is gone. In its place is a note
      // for them, and theirs to you takes the greeting's place: the first
      // thing on Home is something they said today, and the greeting is
      // what shows on a day they have not.
      final greeting = Column(
        key: const ValueKey('home-greeting'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note != null)
            _PartnerNote(
              note: note,
              from: partnerName,
              writtenAt: partner!.homeNoteAt!,
              reaction: profile?.reactionTo(partner.homeNoteAt),
              style: heading,
            )
          else ...[
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
          ],
          // Nobody to leave one for until you are paired.
          if (linked) ...[
            const SizedBox(height: AppSpace.sm),
            _NoteField(partnerName: partnerName),
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
  /// The day in front, by [_idOf]. Null until one is chosen: then it is
  /// their newest, or mine if they have none today.
  String? _frontId;

  /// A day's message id, or who it is for an empty one.
  static String _idOf(_Day day) =>
      day.message?.id ?? (day.own ? 'mine-empty' : 'theirs-empty');

  /// The day [by] along from [from], going round: past the last is the
  /// first again, so a swipe never meets a wall.
  void _turn(List<_Day> days, int from, int by) => setState(
      () => _frontId = _idOf(days[(from + by) % days.length]));

  /// How far a drag across the deck has gone, to read a slow one by.
  double _dragged = 0;

  @override
  Widget build(BuildContext context) {
    // 🔴 **Every day, not the newest of each.** The deck held two cards,
    // your newest day and theirs, and a swipe only swapped them: whatever
    // else either of you had posted today was only in the viewer. It now
    // holds all of them, theirs first (Home is a window into their day)
    // and then yours, and a swipe goes through them one by one. Someone
    // with no day yet is still in it, as the empty arch that says so, and
    // for you, offers the camera.
    final mine = ref.watch(myDayPhotosProvider);
    final theirs = ref.watch(partnerDayPhotosProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final name = partner?.petName ?? partner?.displayName ?? 'Your partner';
    final days = <_Day>[
      if (theirs.isEmpty)
        (own: false, message: null)
      else
        for (final m in theirs) (own: false, message: m),
      if (mine.isEmpty)
        (own: true, message: null)
      else
        for (final m in mine) (own: true, message: m),
    ];
    var front = days.indexWhere((d) => _idOf(d) == _frontId);
    if (front < 0) front = theirs.isNotEmpty ? 0 : days.indexWhere((d) => d.own);
    // There are always two at least, one for each of you.
    final rear = (front + 1) % days.length;
    // A photo on paper in front covers the arch behind it: the paper is
    // what the deck shows, not a polaroid with an arch peeking round it.
    final paperInFront = days[front].message?.isOnPaper ?? false;
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
                    Widget card({required _Day day, required bool front}) {
                      final own = day.own;
                      final msg = day.message;
                      final shape = BorderRadius.vertical(
                          top: Radius.circular(cardWidth / 2),
                          bottom: const Radius.circular(AppRadius.lg));
                      // Behind: to the front. In front: open it, among
                      // the rest of that one of you's days.
                      void tapped(FlowerMessage msg) {
                        if (!front) {
                          setState(() => _frontId = _idOf(day));
                        } else {
                          _open(msg, own: own);
                        }
                      }

                      String caption(FlowerMessage msg) =>
                          '${own ? 'You' : name} · ${DateFormat('h:mm a').format(msg.sentAt.toLocal())}';
                      return AnimatedPositioned(
                          // By day, so a day moving from behind to the
                          // front slides there rather than jumping.
                          key: ValueKey('deck-${_idOf(day)}'),
                          duration: AppMotion.standard,
                          curve: AppMotion.easeOut,
                          left: front ? 0 : w - rearWidth - (h - 32) * .055,
                          top: front
                              ? (msg != null && msg.isOnPaper ? -_paperRise : 0)
                              : (compact ? 16 : 24),
                          // A photo on paper in front takes the space round
                          // the deck as well as the deck: see _paperReach.
                          width: front
                              ? (msg != null && msg.isOnPaper
                                  ? w + _paperReach
                                  : cardWidth)
                              : rearWidth,
                          height: front
                              ? (msg != null && msg.isOnPaper
                                  ? h + 8 + _paperRise + _paperDrop
                                  : h)
                              : h - (compact ? 24 : 32),
                          child: KeyedSubtree(
                              key: ValueKey(
                                  own ? 'my-day-photo' : 'partner-day-photo'),
                              child: AnimatedOpacity(
                              // Covered by the paper in front.
                              opacity: !front && paperInFront ? 0 : 1,
                              duration: AppMotion.standard,
                              child: IgnorePointer(
                                  ignoring: !front && paperInFront,
                                  child: AnimatedRotation(
                              turns: front ? 0 : 3 / 360,
                              duration: AppMotion.standard,
                              curve: AppMotion.easeOut,
                              // The arch is a window into their day. A photo
                              // already on paper is laid on the page instead.
                              child: msg != null && msg.isOnPaper
                                  ? _TapedDay(
                                      message: msg,
                                      caption: front ? caption(msg) : null,
                                      onTap: () => tapped(msg))
                                  : ClipRRect(
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
                                                : () => tapped(msg),
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
                                                                    caption(msg),
                                                                    style: AppText
                                                                        .caption(
                                                                            Colors.white)),
                                                              )),
                                                      ]),
                                          )))))))));
                    }

                    return GestureDetector(
                        // Swipe only: on Home a tap opens the day.
                        onHorizontalDragStart: (_) => _dragged = 0,
                        onHorizontalDragUpdate: (d) => _dragged += d.delta.dx,
                        onHorizontalDragEnd: (d) {
                          final v = d.primaryVelocity ?? 0;
                          final left = v.abs() > 100 ? v < 0 : _dragged < 0;
                          if (v.abs() <= 100 && _dragged.abs() < 24) return;
                          // Left for the next, as a carousel goes.
                          _turn(days, front, left ? 1 : days.length - 1);
                        },
                        child: SizedBox(
                            height: h + 8,
                            child: Stack(clipBehavior: Clip.none, children: [
                              card(day: days[rear], front: false),
                              card(day: days[front], front: true),
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

  /// The viewer, on [message], among the rest of that one of you's days:
  /// theirs page through theirs, yours through yours and on to the camera.
  void _open(FlowerMessage message, {required bool own}) {
    final days =
        ref.read(own ? myDayPhotosProvider : partnerDayPhotosProvider);
    final index = days.indexWhere((m) => m.id == message.id);
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            DaysViewer(own: own, initialIndex: index < 0 ? 0 : index)));
  }
}

/// One card in the deck: a day of theirs or of mine, or the empty arch of
/// whichever of us has none.
typedef _Day = ({bool own, FlowerMessage? message});

/// Shared by the live photo stack and the noninteractive widget preview.
class HomeDayPhoto extends ConsumerWidget {
  const HomeDayPhoto(
      {super.key, required this.message, this.fit = BoxFit.cover});
  final FlowerMessage message;

  /// Cover for a photo in the arch; contain for one on its own paper, whose
  /// edges are the point of it.
  final BoxFit fit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = message.imagePath;
    if (path == null) return const Center(child: AppIcon(CupertinoIcons.photo));
    Widget unavailable() => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AppIcon(CupertinoIcons.photo),
          const SizedBox(height: 8),
          Text('Photo unavailable', style: AppText.caption()),
        ]));
    return StorageImage.dayPhoto(path,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        placeholder:
            Center(child: Text('Loading photo…', style: AppText.caption())),
        error: (retry) =>
            GestureDetector(onTap: retry, child: unavailable()));
  }
}

/// Ink, not a theme colour: it is written on paper, and paper is the same
/// colour in dark mode.
const _pen = Color(0xFF3A3146);

/// What a note can be answered with.
const _noteReactions = ['❤️', '🥰', '😂', '🥺', '😘', '🌷'];

/// Their note to you, where the greeting goes.
///
/// Tap to read it whole (it is cut short if it will not fit), hold to react.
/// Your reaction shows beside who it is from, and on their Home beside the
/// note they wrote.
class _PartnerNote extends ConsumerWidget {
  const _PartnerNote({
    required this.note,
    required this.from,
    required this.writtenAt,
    required this.style,
    this.reaction,
  });

  final String note;
  final String from;
  final DateTime writtenAt;
  final TextStyle style;

  /// Yours to it, if you have reacted.
  final String? reaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Note from $from: $note',
      hint: 'Tap to read it, hold to react',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _read(context, ref),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _react(context, ref);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note,
                key: const ValueKey('partner-note'),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(
                    fontSize: (style.fontSize ?? 30) * .86, height: 1.15)),
            const SizedBox(height: AppSpace.xxs),
            Row(children: [
              Flexible(
                child: Text('from $from',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption()),
              ),
              if (reaction != null) ...[
                const SizedBox(width: 6),
                Text(reaction!,
                    key: const ValueKey('my-note-reaction'),
                    style: const TextStyle(fontSize: 16)),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _read(BuildContext context, WidgetRef ref) async {
    final react = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('From $from'),
        content: Text(note, style: AppText.title()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('React'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (react == true && context.mounted) await _react(context, ref);
  }

  Future<void> _react(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => AppBottomSheet(
        title: 'React to $from’s note',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final emoji in _noteReactions)
                  Semantics(
                    button: true,
                    selected: emoji == reaction,
                    label: 'React $emoji',
                    excludeSemantics: true,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(sheet, emoji),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: emoji == reaction
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.blush,
                                border: Border.all(color: AppColors.brand))
                            : null,
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                  ),
              ],
            ),
            if (reaction != null) ...[
              const SizedBox(height: AppSpace.sm),
              TextButton(
                // Empty means take it back.
                onPressed: () => Navigator.pop(sheet, ''),
                child: const Text('Take my reaction back'),
              ),
            ],
          ],
        ),
      ),
    );
    if (picked == null) return;
    final me = ref.read(currentUserIdProvider);
    if (me == null) return;
    try {
      await ref.read(userRepositoryProvider)
          .setNoteReaction(me, picked.isEmpty ? null : picked, writtenAt);
      ref.invalidate(userProfileProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't react to that. Try again?")));
      }
    }
  }
}

/// Your note to them, on a torn scrap of paper under the greeting: on their
/// Home in place of theirs, for a day. Type, press done, and it is there.
///
/// Their reaction to it shows at its right. While you are writing, how much
/// room is left does, and a way to send it. Emptied and sent, it comes down.
class _NoteField extends ConsumerStatefulWidget {
  const _NoteField({required this.partnerName});

  final String partnerName;

  @override
  ConsumerState<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends ConsumerState<_NoteField> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;

  /// The note the field last showed, so one written on another phone, or
  /// one that has just expired, replaces what is in it.
  String? _shown;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final me = ref.read(currentUserIdProvider);
    if (me == null || _saving) return;
    final current = ref.read(userProfileProvider).valueOrNull?.freshNote ?? '';
    final text = _text.text.trim();
    if (text == current) {
      _focus.unfocus();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .setHomeNote(me, text.isEmpty ? null : text);
      ref.invalidate(userProfileProvider);
      _focus.unfocus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(text.isEmpty
                ? 'Your note is down.'
                : 'On ${widget.partnerName}’s Home for 24 hours.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't leave that note. Try again?")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(userProfileProvider).valueOrNull;
    final partner = ref.watch(partnerProfileStreamProvider).valueOrNull ??
        ref.watch(partnerProfileProvider).valueOrNull;
    final note = mine?.freshNote;
    // What is up, unless it is being rewritten.
    if (!_focus.hasFocus && note != _shown) {
      _shown = note;
      _text.text = note ?? '';
    }
    final reaction =
        note == null ? null : partner?.reactionTo(mine?.homeNoteAt);
    final editing = _focus.hasFocus;
    final left = UserProfile.noteLimit - _text.text.characters.length;
    // Small enough that "Type your message here..." fits on the scrap in
    // one line, as a line written on a scrap would.
    final ink = AppText.note(_pen).copyWith(fontSize: 12.5, height: 1.2);

    return Container(
      key: const ValueKey('home-note-field'),
      constraints: const BoxConstraints(minHeight: 54),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/note_paper.webp'),
          fit: BoxFit.fill,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              focusNode: _focus,
              enabled: !_saving,
              minLines: 1,
              maxLines: 2,
              inputFormatters: [
                LengthLimitingTextInputFormatter(UserProfile.noteLimit),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _send(),
              style: ink,
              cursorColor: _pen,
              // ⚠️ Every border named, not just `border`: the theme's
              // enabled and focused outlines otherwise still draw, a box
              // inside the paper.
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                // Scaled to fit rather than cut short: on a narrow phone
                // the scrap is a few pixels too short for it.
                hint: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('Type your message here...',
                      maxLines: 1,
                      style: ink.copyWith(color: _pen.withValues(alpha: .5))),
                ),
              ),
            ),
          ),
          if (editing) ...[
            Text('$left',
                style: AppText.caption(_pen.withValues(alpha: .6))),
            IconButton(
              tooltip: 'Leave this note',
              visualDensity: VisualDensity.compact,
              onPressed: _saving ? null : _send,
              icon: const AppIcon(CupertinoIcons.paperplane_fill,
                  size: 18, color: _pen),
            ),
          ] else if (reaction != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Semantics(
                label: '${widget.partnerName} reacted $reaction',
                excludeSemantics: true,
                child: Text(reaction,
                    key: const ValueKey('note-reaction'),
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── The space a photo on paper in front is given ──────────────────────
//
// 🔴 **It came out smaller than the arch it replaced**, twice. A polaroid is
// squarer than the arch, so at the arch's width it was shorter; and the
// frame's canvas has clear margins round the tilted sheet (a quarter of the
// sunny polaroid's width), so fitting the canvas shrank the paper again.
// It now fits what the frame actually draws (PhotoFrame.content) into the
// deck plus the room round it: into the page's right margin, up into the
// space under the top bar, and down toward the map. Never left, where the
// greeting is, and never so far that it touches the next thing.

/// Into the page's 20pt right margin, leaving 8.
const _paperReach = 12.0;

/// Up into the 32pt between the top bar and the deck, leaving 14.
const _paperRise = 18.0;

/// Down into the 24pt before the map, leaving 14.
const _paperDrop = 10.0;

/// A day photo taken on paper, a frame or a strip, laid on Home as it is.
///
/// 🔴 **The arch is a window into the other one's day.** A photo that came
/// with its own paper was cut into it all the same, so a polaroid sat inside
/// a second frame with its tape and torn edges cropped off, and the paper
/// the photo was taken on was the one thing that did not show. It is taped
/// to the page now, whole, with the shadow a sheet of paper casts.
///
/// Whose day and when is written **on the paper**, in the blank strip under
/// the photo where a pen would put it, turned to the paper's own tilt. A
/// label floating under the picture read as something else's caption.
///
/// 🔴 **Paper with nowhere to write gets nothing.** A label stuck over the
/// bottom of an illustrated frame covered the drawing, and whose day it is
/// and when is on the viewer a tap away. The words go on the paper or not
/// at all.
class _TapedDay extends StatelessWidget {
  const _TapedDay({required this.message, required this.onTap, this.caption});

  final FlowerMessage message;
  final VoidCallback onTap;

  /// Who and when. Only on the card in front.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final path = message.imagePath!;
    final frame = frameById(message.frameId);
    // The frame's own shape where it is known, which is exactly the
    // picture's; from the name otherwise; square as a last resort, which
    // the frames nearly are.
    final aspect = frame?.aspect ?? photoAspectOf(path) ?? 1.0;
    // What is fitted to the space: only what the frame draws, not its clear
    // margins. The whole picture is drawn round it, margins spilling past,
    // where they are clear anyway.
    final drawn = frame?.content ?? const Rect.fromLTWH(0, 0, 1, 1);
    final strip = frame?.captionStrip;
    final caption = this.caption;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AspectRatio(
          key: const ValueKey('taped-day-paper'),
          aspectRatio: aspect * drawn.width / drawn.height,
          child: LayoutBuilder(builder: (context, box) {
            final size =
                Size(box.maxWidth / drawn.width, box.maxHeight / drawn.height);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -drawn.left * size.width,
                  top: -drawn.top * size.height,
                  width: size.width,
                  height: size.height,
                  child: _picture(path, size, frame, strip, caption),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  /// Whose day and when, on the photo's bottom-left corner, turned with it.
  Widget _stamp(FrameWindow window, Size size, String caption) {
    final (:corner, :angle) = window.bottomLeftIn(size);
    final width = window.boundsIn(size).width;
    // In from the corner by a little of the photo's width: the outline runs
    // a few pixels under the paper, and a stamp sits clear of the edge.
    final inset = width * .07;
    return Positioned(
      left: corner.dx,
      bottom: size.height - corner.dy,
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.only(left: inset, bottom: inset * .8),
          child: Text(caption,
              key: const ValueKey('taped-day-caption'),
              maxLines: 1,
              style: AppText.caption(Colors.white).copyWith(
                  fontSize: (width * .075).clamp(9.0, 14.0),
                  fontWeight: FontWeight.w600,
                  height: 1,
                  shadows: const [
                    Shadow(
                        color: Color(0x99000000),
                        blurRadius: 4,
                        offset: Offset(0, 1)),
                  ])),
        ),
      ),
    );
  }

  /// The whole picture at [size], its shadow, and what is written on it.
  Widget _picture(String path, Size size, PhotoFrame? frame,
      FrameCaptionStrip? strip, String? caption) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The paper's own shadow, cut to its torn edges rather than to a
        // box: the photo, blurred, in shadow colour.
        Transform.translate(
          offset: const Offset(0, 4),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: .22), BlendMode.srcIn),
              child: StorageImage.dayPhoto(path,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  placeholder: const SizedBox.shrink(),
                  error: (_) => const SizedBox.shrink()),
            ),
          ),
        ),
        HomeDayPhoto(message: message, fit: BoxFit.contain),
        // On a polaroid (paper with a blank strip), stamped on the photo's
        // bottom-left corner the way a camera stamps a print, and turned
        // with it. Not on the strip: that is the paper, and the time is
        // about the picture.
        if (caption != null && strip != null && frame!.windows.isNotEmpty)
          _stamp(frame.windows.first, size, caption),
      ],
    );
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

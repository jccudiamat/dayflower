import '../widgets/today_story.dart';
import '../../../../core/widgets/user_avatar.dart';
import 'package:dayflower/core/widgets/app_icon.dart';
import 'dart:math' as math;
import 'dart:async';

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
import '../../../greetings/presentation/monthsary_envelope.dart';
import '../../../reunion/data/reunion_repository.dart';
import '../../../dates/presentation/widgets/reunion_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            const SliverPadding(
              padding: AppSpace.screen,
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  _HomeHeader(),
                  SizedBox(height: AppSpace.sm),
                  LocationPreview(),
                  SizedBox(height: AppSpace.sm),
                  MonthsaryEnvelope(),
                  _MoodCard(),
                  ReceivedFlowerPreview(),
                  SizedBox(height: AppSpace.xs),
                  ComingUpPreview(),
                  _HomeReunion(),
                  MemoryCallback(),
                  _HomeActions(),
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
    final theirMood = ref.watch(partnerMoodProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final theirName =
        partner?.petName ?? partner?.displayName ?? 'Your partner';

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
          const _HeartbeatCard(embedded: true),
          if (theirMood != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
                '$theirName is feeling ${theirMood.label.toLowerCase()} ${theirMood.emoji}',
                style: AppText.body(AppColors.muted)),
          ],
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Expanded(
                child: Text('HOW ARE YOU FEELING?', style: AppText.label()),
              ),
              Text(
                mood?.label ?? 'Tap one',
                style: AppText.caption(
                  mood == null ? AppColors.muted : AppColors.brand,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final m in Mood.values)
                  Padding(
                      padding: const EdgeInsets.only(right: AppSpace.xxs),
                      child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Semantics(
                              button: true,
                              selected: mood == m,
                              label: m.label,
                              child: _MoodChip(
                                  mood: m,
                                  selected: mood == m,
                                  onTap: () => ref
                                      .read(moodProvider.notifier)
                                      .select(m))))),
              ])),
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
          duration: AppMotion.duration(context, AppMotion.micro),
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
  const _HeartbeatCard({this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<_HeartbeatCard> createState() => _HeartbeatCardState();
}

class _HeartbeatCardState extends ConsumerState<_HeartbeatCard>
    with TickerProviderStateMixin {
  late final AnimationController _scaleCtrl;

  /// Double-thump (lub-dub) played on the receiving side only.
  late final AnimationController _beatCtrl;
  late final Animation<double> _beat;

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

  void _onTap() {
    HapticFeedback.mediumImpact();
    if (!MediaQuery.disableAnimationsOf(context)) {
      _scaleCtrl.forward().then((_) {
        if (mounted) _scaleCtrl.reverse();
      });
    }

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
            content: Text('Your heartbeat couldn’t send. Try again.')));
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
      if (!MediaQuery.disableAnimationsOf(context)) {
        _beatCtrl.forward(from: 0);
      }
    });

    return Container(
        padding: widget.embedded
            ? EdgeInsets.zero
            : const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border:
                widget.embedded ? null : Border.all(color: AppColors.border)),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('A little closer', style: AppText.subtitle()),
                Text(
                    '${counts.mine + counts.partner} little moments shared today',
                    style: AppText.caption()),
              ])),
          Semantics(
              label: 'Send some love to $partnerName',
              button: true,
              child: IconButton(
                onPressed: _onTap,
                tooltip: 'Send some love',
                icon: AnimatedBuilder(
                    animation: Listenable.merge([_scaleCtrl, _beatCtrl]),
                    builder: (context, child) => Transform.scale(
                        scale: MediaQuery.disableAnimationsOf(context)
                            ? 1
                            : (1 + _scaleCtrl.value) * _beat.value,
                        child: child),
                    child: const AppIcon(CupertinoIcons.heart_fill,
                        color: AppColors.brand, size: 36)),
              )),
        ]));
  }
}

/// One expanding ring. Several of these, staggered, make the incoming pulse.
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

    final distance = profileDistanceLabel(profile, partner);

    // Bottom-aligned against the arch, not top-aligned: the greeting is the
    // heavier block and hanging it from the top left it floating above a
    // tall panel. The padding keeps it off the arch's baseline rather than
    // sitting flush with it.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greetingFor(DateTime.now()), style: AppText.title()),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        myName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.hero(AppColors.ink),
                      ),
                    ),
                    const SizedBox(width: AppSpace.xxs),
                    // A different bloom each time the app opens — see
                    // greetingFlower for why it is picked once per launch
                    // rather than once per build.
                    Text(greetingFlower, style: const TextStyle(fontSize: 22)),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),

                // Where they are and what time it is there. One line, because
                // it is one thought.
                if (partnerName != null && partnerTime != null)
                  Text(
                    // Their town when they have picked one, the timezone's
                    // namesake city otherwise — "Manila" for everybody in
                    // Asia/Manila, which is where this line started.
                    '$partnerName · ${partner?.city?.split(',').first.trim() ?? zoneCity(partnerZone!)} · '
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
        ),
        const SizedBox(width: AppSpace.sm),
        const _DayArch(),
      ],
    );
  }
}

/// The arched panel beside the greeting: a two-card deck, theirs in front.
///
/// **Why a deck rather than two halves.** Splitting the arch 50/50 gave each
/// photo a 132×96 box — a *landscape* letterbox. The camera shoots
/// `ResolutionPreset.high`, which is 720×1280 in portrait, so `BoxFit.cover`
/// into that kept 41% of the height and threw away 59% of it from the
/// centre — which on a selfie is the band from the chin down. The best
/// possible day, where both of you posted, rendered both of you worst.
///
/// Whichever card is in front now gets almost the whole arch, where a 9:16
/// photo loses about 9% off its sides and nothing else. The other sits
/// behind it, slightly smaller and dimmed, with a band of its arch showing
/// above — enough to say it is there. A horizontal swipe trades them.
///
/// ⚠️ **The peek is carved out of the arch, not added above it.** Both cards
/// are [_peek] shorter than the panel and the front one is aligned to the
/// bottom, so the back one's crescent lands inside the same 132×194 box the
/// arch has always occupied. Lifting the back card out of the box instead
/// would have painted it over the collapsing top bar, and grown the header
/// by 22pt to avoid that.
class _DayArch extends ConsumerStatefulWidget {
  const _DayArch();

  static const double width = 132;
  static const double aspect = 0.68; // width ÷ height
  static double get height => width / aspect;

  /// How much of the back card shows above the front one.
  static const double peek = 12;

  static const shape = BorderRadius.only(
    topLeft: Radius.circular(64),
    topRight: Radius.circular(64),
    bottomLeft: Radius.circular(AppRadius.lg),
    bottomRight: Radius.circular(AppRadius.lg),
  );

  @override
  ConsumerState<_DayArch> createState() => _DayArchState();
}

class _DayArchState extends ConsumerState<_DayArch>
    with SingleTickerProviderStateMixin {
  /// 0 = their day in front, 1 = yours.
  ///
  /// Animated rather than toggled: without the movement a swipe just looks
  /// like the photo changed, and there is nothing to say the other one is
  /// still there.
  late final AnimationController _swap;

  @override
  void initState() {
    super.initState();
    // Initialize while mounted, even when neither person has a day photo.
    // Otherwise the first access can happen in dispose when leaving Home.
    _swap = AnimationController(vsync: this, duration: AppMotion.standard);
  }

  /// The back card, relative to the front one.
  static const double _backScale = 0.95;
  static const double _backDim = 0.30;

  @override
  void dispose() {
    _swap.dispose();
    super.dispose();
  }

  /// Their day starts in front and returns there, always. It is what you
  /// opened the app for; yours is the receipt that you posted.
  void _bringForward({required bool mine}) =>
      mine ? _swap.forward() : _swap.reverse();

  @override
  Widget build(BuildContext context) {
    final theirs = ref.watch(partnerDayPhotoProvider);
    final mine = ref.watch(myDayPhotoProvider);

    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final theirName = partner?.petName ?? partner?.displayName ?? 'Their';

    return SizedBox(
      width: _DayArch.width,
      height: _DayArch.height,
      child: _content(theirs, mine, theirName),
    );
  }

  Widget _content(
    FlowerMessage? theirs,
    FlowerMessage? mine,
    String theirName,
  ) {
    // Both: a deck. Either direction swaps — with exactly two cards, "left"
    // and "right" mean the same thing, and honouring the direction would
    // make half of all swipes silently do nothing.
    if (theirs != null && mine != null) {
      return GestureDetector(
        onHorizontalDragEnd: (_) => _bringForward(mine: _swap.value < 0.5),
        child: AnimatedBuilder(
          animation: _swap,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_swap.value);
            final theirsInFront = t < 0.5;

            final theirCard = _deckCard(
              key: ValueKey(theirs.id),
              message: theirs,
              depth: t,
              // Tapping the front card opens it; tapping the sliver of the
              // back one brings it forward, which is the same thing the
              // swipe does and a much easier target to find.
              onTap: () => theirsInFront
                  ? _open(theirs, "$theirName's day")
                  : _bringForward(mine: false),
            );
            final myCard = _deckCard(
              key: ValueKey(mine.id),
              message: mine,
              depth: 1 - t,
              onTap: () => theirsInFront
                  ? _bringForward(mine: true)
                  : _open(mine, 'Your day'),
            );

            return Stack(
              children: [
                // Painted back to front. The keys carry each card's element
                // through the reorder, so the photo does not get rebuilt —
                // and its signed URL not re-fetched — every time they trade.
                if (theirsInFront) ...[
                  myCard,
                  theirCard
                ] else ...[
                  theirCard,
                  myCard,
                ],
                _DeckDots(mineIsFront: !theirsInFront),
              ],
            );
          },
        ),
      );
    }

    // One: it fills the arch. Half a panel with an empty space under it
    // would read as something failing to load.
    final only = theirs ?? mine;
    if (only != null) {
      return ClipRRect(
        borderRadius: _DayArch.shape,
        child: _DayPhoto(
          message: only,
          onTap: () => _open(
            only,
            only == mine ? 'Your day' : "$theirName's day",
          ),
        ),
      );
    }

    // Nothing to look at, so the tap does the only useful thing instead:
    // opens the camera so there is something here next time.
    return ClipRRect(
      borderRadius: _DayArch.shape,
      child: _DayEmpty(onTap: () {
        ref.read(dayPhotoTargetProvider.notifier).state = DayPhotoTarget.widget;
        context.push(Routes.flowers);
      }),
    );
  }

  /// One card in the deck.
  ///
  /// [depth] runs 0 (front: full size, undimmed, sitting at the bottom of
  /// the panel) to 1 (back: scaled down from its top edge, dimmed, sitting
  /// at the very top). Everything between is interpolated, so the two cards
  /// pass through each other rather than popping.
  Widget _deckCard({
    required Key key,
    required FlowerMessage message,
    required double depth,
    required VoidCallback onTap,
  }) {
    return Positioned(
      key: key,
      left: 0,
      right: 0,
      top: _DayArch.peek * (1 - depth),
      height: _DayArch.height - _DayArch.peek,
      child: Transform.scale(
        scale: 1 + (_backScale - 1) * depth,
        // From the top edge, not the centre: scaling about the middle would
        // pull the back card's top down by as much as its position raises
        // it, and the crescent would collapse to nothing.
        alignment: Alignment.topCenter,
        child: ClipRRect(
          borderRadius: _DayArch.shape,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _DayPhoto(message: message, onTap: onTap),
              // A scrim, not opacity. Fading the card would show the one
              // underneath *through* it, which reads as a rendering fault
              // rather than as depth.
              IgnorePointer(
                child: Opacity(
                  opacity: _backDim * depth,
                  child: Container(color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(FlowerMessage message, String who) {
    // ⚠️ My own days open as the **pager**, theirs as the single photo.
    // There is only ever one of theirs live at a time; mine can be seven,
    // and opening the newest with no way to reach the other six would hide
    // them behind a card that looks like one photo.
    final mine = ref.read(myDayPhotosProvider);
    final index = mine.indexWhere((m) => m.id == message.id);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => index >= 0
            ? MyDaysViewer(initialIndex: index)
            : DayPhotoViewer(message: message, who: who),
      ),
    );
  }
}

/// Two dots, because "swipe to see the other one" is otherwise invisible.
///
/// Inside the arch rather than under it: the header's height is set by the
/// arch, so hanging an indicator below would push the whole greeting block
/// down by a line for the sake of two dots.
class _DeckDots extends StatelessWidget {
  const _DeckDots({required this.mineIsFront});

  final bool mineIsFront;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 10,
      child: IgnorePointer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dot(active: !mineIsFront),
            const SizedBox(width: 5),
            _dot(active: mineIsFront),
          ],
        ),
      ),
    );
  }

  Widget _dot({required bool active}) => Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // White with a shadow rather than a palette colour: these sit on
          // an arbitrary photo and have to stay legible on a white one.
          color: Colors.white.withValues(alpha: active ? 1 : .45),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .35),
              blurRadius: 3,
            ),
          ],
        ),
      );
}

/// One day photo, filling whatever box it is given.
class _DayPhoto extends ConsumerWidget {
  const _DayPhoto({required this.message, this.onTap});

  final FlowerMessage message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚠️ Watched from a provider, never signed inline. Calling
    // `signedPhotoUrl` in build hands FutureBuilder a brand new Future on
    // every rebuild — one signing round-trip per frame once anything here
    // animates, with the placeholder flashing between each. See
    // dayPhotoUrlProvider.
    final url = ref.watch(dayPhotoUrlProvider(message.imagePath!)).valueOrNull;

    return GestureDetector(
      onTap: onTap,
      child: url == null
          ? Container(color: AppColors.surfaceSubtle)
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              // A failed image inside a decorative panel should look like
              // the empty state, not like a broken page.
              errorBuilder: (_, __, ___) =>
                  Container(color: AppColors.surfaceSubtle),
            ),
    );
  }
}

/// Nothing shared today, by either of them.
class _DayEmpty extends StatelessWidget {
  const _DayEmpty({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
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

/* ── Top bar ─────────────────────────────── */

/// The app's wordmark on the left and Notifications on the right.
///
/// Lives in a `floating`/`snap` SliverAppBar, so it gets out of the way as
/// soon as you start reading and comes back whole on the first flick up.
class _HomeBar extends ConsumerWidget {
  const _HomeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // Wordmark only. The tulip already appears beside the name in the
        // greeting directly below, and twice in one glance made it read as
        // decoration rather than as the app's mark.
        Text(
          AppConstants.appName,
          style: AppText.title(AppColors.ink).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push(Routes.notifications),
          icon: Badge(
            isLabelVisible: ref.watch(unseenActivityCountProvider) > 0,
            backgroundColor: AppColors.brand,
            child: AppIcon(CupertinoIcons.bell, color: AppColors.ink),
          ),
        ),
        IconButton(
            tooltip: 'Our story',
            onPressed: () => context.push(Routes.us),
            icon: UserAvatar(ref.watch(partnerProfileProvider).valueOrNull,
                size: 32)),
      ],
    );
  }
}

/// Entry points previously supplied by the Camera tab and Settings.
class _HomeActions extends ConsumerWidget {
  const _HomeActions();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
        spacing: AppSpace.sm,
        children: [
          TextButton.icon(
            onPressed: () {
              ref.read(dayPhotoTargetProvider.notifier).state =
                  DayPhotoTarget.widget;
              context.push(Routes.flowers);
            },
            icon: const AppIcon(CupertinoIcons.camera),
            label: const Text('Share your day'),
          ),
        ],
      );
}

/// Same countdown card as Events; editing stays in Together.
class _HomeReunion extends ConsumerStatefulWidget {
  const _HomeReunion();
  @override
  ConsumerState<_HomeReunion> createState() => _HomeReunionState();
}

class _HomeReunionState extends ConsumerState<_HomeReunion> {
  late final Timer _ticker;
  DateTime _now = DateTime.now();
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reunion = ref.watch(reunionProvider).valueOrNull;
    if (reunion == null || !reunion.happensAt.isAfter(_now)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md, bottom: AppSpace.md),
      child: ReunionCard(
          title: reunion.title,
          place: reunion.destination,
          when: reunion.happensAt,
          now: _now,
          onTap: () => context.push(Routes.events)),
    );
  }
}

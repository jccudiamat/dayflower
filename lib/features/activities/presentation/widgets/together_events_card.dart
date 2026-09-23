import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../dates/data/event_repository.dart';
import '../../../home/domain/home_moments.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/together_assets.dart';
import 'together_art.dart';
import 'together_card.dart';

/// Events: how many days are coming up, the next three, and a calendar.
///
/// The same list Home's upcoming card and the hero count from —
/// [homeMomentsProvider] — so "3 coming up" here is never a different
/// three from anywhere else.
class TogetherEventsCard extends ConsumerWidget {
  const TogetherEventsCard({super.key});

  static const _shown = 3;

  /// The calendar's width. Its height follows the art's shape.
  static const _artWidth = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moments = ref.watch(homeMomentsProvider);
    final now = ref.watch(homeClockProvider).valueOrNull ?? DateTime.now();
    final loading = ref.watch(currentPairProvider).isLoading ||
        ref.watch(customEventsProvider).isLoading;
    final more = moments.length - _shown;

    return TogetherCard(
      tint: TogetherTint.lavender,
      padding: const EdgeInsets.all(TogetherStyle.padTight),
      onTap: () => context.push(Routes.events),
      // 🔴 The calendar hangs into the card's top-right corner rather than
      // sitting in a column of its own. Beside the header it took the
      // width "5 coming up" needed, and at 360pt that wrapped to "5
      // coming / up"; here it only has to clear the list below it.
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          top: -6,
          right: -12,
          child: TogetherCalendarArt(month: now, width: _artWidth),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: _artWidth - 12),
              child: TogetherCardHeader(
                icon: CupertinoIcons.calendar,
                iconColor: TogetherStyle.iconEvents,
                title: 'Events',
                subtitle: loading
                    ? null
                    : moments.isEmpty
                        ? 'Nothing planned yet'
                        : '${moments.length} coming up',
              ),
            ),
            const SizedBox(height: AppSpace.compact),
            if (loading)
              const TogetherSkeleton(lines: 3)
            else if (moments.isEmpty)
              Text('Add the days that matter to you both.',
                  style: TogetherStyle.tagline())
            else ...[
              for (final moment in moments.take(_shown)) _EventLine(moment),
              if (more > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('+$more more', style: TogetherStyle.listMeta()),
                ),
            ],
          ],
        ),
      ]),
    );
  }
}

class _EventLine extends StatelessWidget {
  const _EventLine(this.moment);

  final HomeMoment moment;

  static final _date = DateFormat('d MMM');

  /// Shorter than the moment's own title where the card is narrow and the
  /// kind already says it: "Anniversary", not "Our anniversary".
  String get _label => switch (moment.kind) {
        HomeMomentKind.anniversary => 'Anniversary',
        HomeMomentKind.monthsary => 'Our monthsary',
        _ => moment.title,
      };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: TogetherStyle.eventDot(moment.kind.name),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(_label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TogetherStyle.listTitle()),
          ),
          const SizedBox(width: 6),
          Text(_date.format(moment.date), style: TogetherStyle.listMeta()),
        ]),
      );
}

/// The calendar illustration, showing this month rather than the one it
/// was drawn with.
///
/// 🔴 The art was drawn saying "OCT". `tool/shrink_together.py` erases the
/// word from the band between the two hearts, and this paints the real
/// month in the same place, in the art's own ink. The fractions below are
/// where that script says the word was — re-run it and keep them in step
/// if the calendar art is ever replaced.
class TogetherCalendarArt extends StatelessWidget {
  const TogetherCalendarArt({
    super.key,
    required this.month,
    required this.width,
  });

  final DateTime month;
  final double width;

  /// Width over height of the shipped calendar_hearts.webp.
  static const aspect = 360 / 346;

  /// Where the word sat, as fractions of the shipped image: its centre,
  /// and the box it filled.
  static const labelCentre = Offset(.4871, .2408);
  static const labelWidth = .20;
  static const labelHeight = .085;

  static final _format = DateFormat('MMM');

  /// "OCT", "NOV" — what is printed on the band.
  static String labelFor(DateTime month) => _format.format(month).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final height = width / aspect;
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(children: [
          Positioned.fill(
            child: TogetherArt(
              TogetherAssets.eventsCalendar,
              fallbackIcon: CupertinoIcons.calendar,
              width: width,
              height: height,
            ),
          ),
          Positioned(
            left: width * (labelCentre.dx - labelWidth / 2),
            top: height * (labelCentre.dy - labelHeight / 2),
            width: width * labelWidth,
            height: height * labelHeight,
            // Fitted to the band, never to the reader's text size: it is
            // part of the picture, and a month that grew with the font
            // would spill off the calendar.
            child: FittedBox(
              child: Text(labelFor(month),
                  textScaler: TextScaler.noScaling,
                  style: TogetherStyle.calendarMonth()),
            ),
          ),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';

/// The next time you are in the same place, counted down to the second.
///
/// Copied from a reference the user supplied, including its artwork —
/// `tool/make_reunion.py` cuts the illustration out of that image with an
/// alpha ramp on its left edge, so it fades into the card's own gradient
/// rather than showing a seam wherever the two pinks disagree.
///
/// ⚠️ **The seconds are the point.** A countdown in whole days is a fact you
/// could work out from a calendar; one that moves is the distance being
/// closed while you look at it. That is also why this card is worth its own
/// ticker rather than folding into the list of upcoming dates.
class ReunionCard extends StatelessWidget {
  const ReunionCard({
    super.key,
    required this.title,
    required this.place,
    required this.when,
    required this.now,
    this.onTap,
  });

  final String title;

  /// Where you will be. Null when the event has no place on it — the line
  /// then reads as just the date rather than "· May 12".
  final String? place;

  final DateTime when;

  /// Passed in rather than read from the clock, so every countdown on the
  /// screen ticks off the same second and none of them disagree by one.
  final DateTime now;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final left = when.difference(now);
    final past = left.isNegative;
    final days = past ? 0 : left.inDays;
    final hrs = past ? 0 : left.inHours % 24;
    final mins = past ? 0 : left.inMinutes % 60;
    final secs = past ? 0 : left.inSeconds % 60;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_top, _bottom],
          ),
          border: Border.all(color: _edge),
          boxShadow: AppElevation.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            children: [
              // ⚠️ Right-aligned and allowed to overflow the card's right
              // edge rather than stretched to fit. The couple sits at a
              // fixed distance from the corner on any width; scaling it to
              // the card would make them smaller on a small phone, which is
              // where the card has least room to say anything at all.
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Image.asset(
                  'assets/images/reunion.png',
                  fit: BoxFit.fitHeight,
                  alignment: Alignment.centerRight,
                  // Decoration. A missing asset must not cost the countdown.
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✈️', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          title,
                          style: AppText.subtitle(_ink)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            _stamp(place, when),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: AppText.caption(_inkSoft),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // ⚠️ The numbers are held to the left **58%** of the
                    // card. The couple owns the right of it, and text laid
                    // out at its natural width walked straight under them —
                    // on a narrow phone the seconds ended up on his suitcase.
                    // A fraction rather than a fixed width, because the
                    // illustration is anchored to the right edge and so its
                    // encroachment scales with the card.
                    FractionallySizedBox(
                      widthFactor: 0.58,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The number, at the size the reference gives it
                          // — big enough to read across a room, which is how
                          // somebody checks a countdown whose answer they
                          // already roughly know.
                          //
                          // ⚠️ Scaled down rather than clipped: a reunion a
                          // year out is three digits, and "365 days" is wider
                          // than the two the reference was drawn around.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('$days',
                                    style: AppText.display(_ink).copyWith(
                                      fontSize: 46,
                                      height: 1,
                                      fontWeight: FontWeight.w700,
                                    )),
                                const SizedBox(width: 8),
                                Text('days',
                                    style: AppText.title(_ink)
                                        .copyWith(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Scales down rather than wrapping or clipping: three
                          // units on one line is the shape of the thing, and a
                          // seconds counter that dropped to a second row would
                          // move the whole card every time it ticked.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                _Unit(value: hrs, label: 'hrs'),
                                const SizedBox(width: 10),
                                _Unit(value: mins, label: 'min'),
                                const SizedBox(width: 10),
                                _Unit(value: secs, label: 'sec'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Text('💗', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text('Dayflower', style: AppText.caption(_inkSoft)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Tokyo · May 12, 2025", or just the date when there is no place.
  static String _stamp(String? place, DateTime when) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final date = '${months[when.month - 1]} ${when.day}, ${when.year}';
    return (place == null || place.isEmpty) ? date : '$place · $date';
  }
}

/// One of the three smaller units, number bold and label quiet.
class _Unit extends StatelessWidget {
  const _Unit({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$value',
          style: AppText.subtitle(_ink).copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            // ⚠️ Tabular, so the seconds do not shove the minutes sideways
            // every time they tick past a wider digit.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 3),
        Text(label, style: AppText.caption(_inkSoft)),
      ],
    );
  }
}

// Sampled from the reference rather than picked, so the card and the artwork
// cut out of it are the same pink.
const _top = Color(0xFFF9EDF1);
const _bottom = Color(0xFFF2D6E0);
const _edge = Color(0xFFEFD5DF);
const _ink = Color(0xFF3A2A46);
const _inkSoft = Color(0xFF7A6480);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dates/data/event_repository.dart';
import '../../home/domain/home_moments.dart';
import '../../pairing/data/pair_repository.dart';
import '../../reunion/data/reunion_repository.dart';
import '../../travel/data/map_pin_repository.dart';

/// The three things the hero counts down to: the next milestone, the next
/// reunion, and the next place you mean to go.
///
/// Nothing here is new data. The first two come from [homeMomentsProvider],
/// the same list Home's upcoming card reads, so the two screens can never
/// disagree about how many days are left. The trip comes from the pins on
/// Our Map.
class TogetherNextUp {
  const TogetherNextUp({
    required this.now,
    this.milestone,
    this.reunion,
    this.trip,
    this.milestoneLoading = false,
    this.reunionLoading = false,
    this.tripLoading = false,
  });

  final DateTime now;

  /// The next monthsary — or the anniversary, on the one day a year the two
  /// coincide and [collectHomeMoments] keeps only the anniversary.
  final HomeMoment? milestone;

  /// The soonest reunion still ahead, whether it lives on the reunion row or
  /// was added as an event of kind `reunion`.
  final HomeMoment? reunion;

  /// The most recently pinned place you have not been yet.
  ///
  /// ⚠️ **A place, never a date.** Pins carry no date, so this row shows
  /// where and not when. Inventing a month to match the mockup would put a
  /// plan on the screen that neither of them made.
  final MapPin? trip;

  /// Still waiting on the first answer. Kept apart from "nothing there" so
  /// the hero does not flash "No reunion planned yet" at a couple who have
  /// one, every time the tab opens.
  final bool milestoneLoading, reunionLoading, tripLoading;
}

/// "Palawan, Philippines" → "Palawan". The city picker's names lead with
/// the place and trail the country, and the row has room for one.
String placeName(String place) {
  final head = place.split(',').first.trim();
  return head.isEmpty ? place.trim() : head;
}

final togetherNextUpProvider = Provider.autoDispose<TogetherNextUp>((ref) {
  final now = ref.watch(homeClockProvider).valueOrNull ?? DateTime.now();
  final moments = ref.watch(homeMomentsProvider);

  // Sorted soonest first already, so the first match is the next one.
  HomeMoment? first(bool Function(HomeMoment) test) {
    for (final moment in moments) {
      if (test(moment)) return moment;
    }
    return null;
  }

  final pins = ref.watch(mapPinsProvider);
  MapPin? trip;
  for (final pin in pins.valueOrNull ?? const <MapPin>[]) {
    // Oldest first from the stream; the last one standing is the newest.
    if (!pin.visited) trip = pin;
  }

  return TogetherNextUp(
    now: now,
    milestone: first((m) =>
        m.kind == HomeMomentKind.monthsary ||
        m.kind == HomeMomentKind.anniversary),
    reunion: first((m) => m.kind == HomeMomentKind.reunion),
    trip: trip,
    milestoneLoading: ref.watch(currentPairProvider).isLoading,
    reunionLoading: ref.watch(reunionProvider).isLoading ||
        ref.watch(customEventsProvider).isLoading,
    tripLoading: pins.isLoading,
  );
});

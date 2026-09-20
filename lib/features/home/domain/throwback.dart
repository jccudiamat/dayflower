import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tulip/data/flower_repository.dart';
import 'home_moments.dart';

/// Something the two of you made on this date, in an earlier year.
class Throwback {
  const Throwback({required this.message, required this.yearsAgo});

  final FlowerMessage message;
  final int yearsAgo;

  /// "A year ago today", or "3 years ago today".
  String get heading =>
      yearsAgo == 1 ? 'A year ago today' : '$yearsAgo years ago today';
}

/// Finds a photo from this same calendar day in a previous year.
///
/// 🔴 **The same day, or nothing.** The obvious shortcut is to grab the oldest
/// photo to hand and caption it "a year ago today", which is a lie roughly 364
/// days out of 365. A section that is silent most of the time and right when
/// it speaks is worth more than one that is always there and usually wrong.
///
/// ⚠️ Compares month and day only, in whatever local zone the clock is in. A
/// photo taken late at night one side of the world can land on the next day
/// the other side, so this will occasionally miss by one. Better than the
/// alternative, which is inventing an anniversary.
Throwback? findThrowback(List<FlowerMessage> messages, DateTime now) {
  Throwback? best;
  for (final m in messages) {
    if (m.imagePath == null) continue;
    final sent = m.sentAt.toLocal();
    final years = now.year - sent.year;
    if (years < 1) continue;
    if (sent.month != now.month || sent.day != now.day) continue;
    // The most recent match: last year beats five years ago, because the
    // nearer one is the one they are likelier to remember.
    if (best == null || years < best.yearsAgo) {
      best = Throwback(message: m, yearsAgo: years);
    }
  }
  return best;
}

final throwbackProvider = Provider.autoDispose<Throwback?>((ref) {
  final messages = ref.watch(flowerMessagesProvider).valueOrNull;
  if (messages == null) return null;
  final now = ref.watch(homeClockProvider).valueOrNull ?? DateTime.now();
  return findThrowback(messages, now);
});

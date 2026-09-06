import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';
import '../domain/call.dart';

/// What the pair's calling allowance is, per month.
///
/// **Null means unlimited, and that is the important case.** A self-hosted
/// media server has no quota at all, so every surface that shows the meter
/// must be able to show nothing instead — a ring reading 0% of infinity is
/// a control measuring nothing, and worse than an absent one.
///
/// Two ceilings, not two buckets: a shared pool of minutes that either kind
/// of call spends, and a further cap on video alone from the data
/// allowance. A single "hours left" figure would be wrong for one of the
/// two modes always, which is why nothing here returns one.
class CallAllowance {
  const CallAllowance({
    required this.totalMinutes,
    required this.videoMinutes,
  });

  /// Call minutes of **either kind**, per month.
  ///
  /// ⚠️ **One shared pool, not a voice budget.** Providers meter connection
  /// time regardless of what is flowing, so a minute of video spends this
  /// exactly as fast as a minute of voice. Modelling the two as independent
  /// buckets — the first shape of this class — overstated the remainder by
  /// up to double, which is the precise surprise the whole feature exists
  /// to prevent.
  ///
  /// Whole-call minutes, not participant-minutes: providers bill per
  /// participant, so a two-person call spends two of theirs for one of
  /// ours. The halving is done once, here.
  final int totalMinutes;

  /// A further ceiling on **video only**, from the data cap.
  ///
  /// Video runs a few hundred times the bitrate of Opus, so on a hosted
  /// free tier the transfer allowance runs out long before the minutes do.
  /// Voice has no equivalent — 50 GB is tens of thousands of voice minutes,
  /// far more than the minute pool allows — so there is no voice twin of
  /// this field.
  final int videoMinutes;

  /// Zero or less means uncapped, per ceiling.
  bool get limitsTotal => totalMinutes > 0;
  bool get limitsVideo => videoMinutes > 0;

  /// Read from `.env`, so changing plan or self-hosting is config rather
  /// than a release. Absent or zero means unlimited — which is also what a
  /// build with no `LIVEKIT_URL` gets, since a build that cannot call
  /// cannot run out.
  static CallAllowance? get configured {
    final total = int.tryParse(dotenv.env['CALL_TOTAL_MINUTES'] ?? '') ?? 0;
    final video = int.tryParse(dotenv.env['CALL_VIDEO_MINUTES'] ?? '') ?? 0;
    if (total <= 0 && video <= 0) return null;
    return CallAllowance(totalMinutes: total, videoMinutes: video);
  }
}

/// This month's calling, and what is left of it.
class CallUsage {
  const CallUsage({
    this.voice = Duration.zero,
    this.video = Duration.zero,
    this.calls = 0,
    this.allowance,
  });

  final Duration voice;
  final Duration video;

  /// Finished calls this month, both kinds. Not shown anywhere yet; kept
  /// because "we called each other 40 times this month" is a Us-page number
  /// in a way that "we used 68% of a quota" never will be.
  final int calls;

  /// Null when this build has no quota to run out of.
  final CallAllowance? allowance;

  /// Whether *anything* is capped.
  ///
  /// ⚠️ Not `allowance != null`. An allowance whose ceilings are both zero
  /// is a self-hosted build with nothing to run out of — and since
  /// `int.tryParse('') ?? 0` is how an unset `.env` parses, treating that
  /// object as "metered" made every unmetered build report itself spent.
  bool get isMetered =>
      allowance != null && (allowance!.limitsTotal || allowance!.limitsVideo);

  /// Every minute called this month, of either kind. What the shared pool
  /// is measured against.
  Duration get total => voice + video;

  Duration spent(CallMode mode) => mode == CallMode.video ? video : voice;

  /// How full the shared minute pool is, 0–1 and uncapped above.
  double get totalFraction {
    final plan = allowance;
    if (plan == null || !plan.limitsTotal) return 0;
    return total.inSeconds / (plan.totalMinutes * 60);
  }

  /// How full video's own data ceiling is.
  double get videoFraction {
    final plan = allowance;
    if (plan == null || !plan.limitsVideo) return 0;
    return video.inSeconds / (plan.videoMinutes * 60);
  }

  /// The ring reads whichever ceiling is closest.
  ///
  /// Not an average: an average would show 50% while video sat at 99%, and
  /// the first thing the user learned about the limit would be a call that
  /// failed.
  double get fraction =>
      totalFraction > videoFraction ? totalFraction : videoFraction;

  /// Minutes left in the shared pool, or null if it is uncapped.
  Duration? get totalLeft {
    final plan = allowance;
    if (plan == null || !plan.limitsTotal) return null;
    return _floor(Duration(minutes: plan.totalMinutes) - total);
  }

  /// What is left for a call of this kind, or **null when nothing caps it**.
  ///
  /// Nullable rather than "a very large Duration" so callers cannot render
  /// infinity as a figure, and cannot mistake unlimited for empty — the
  /// confusion that made a self-hosted build refuse to place calls.
  ///
  /// Video answers to both ceilings and takes the tighter, because running
  /// out of either one stops it.
  Duration? left(CallMode mode) {
    final pool = totalLeft;
    if (mode == CallMode.voice) return pool;

    final plan = allowance;
    final byData = plan == null || !plan.limitsVideo
        ? null
        : _floor(Duration(minutes: plan.videoMinutes) - video);

    if (pool == null) return byData;
    if (byData == null) return pool;
    return pool < byData ? pool : byData;
  }

  /// Usage can overshoot: the count runs a few percent light and a call in
  /// progress is not counted until it ends. "−12 min left" is a number
  /// nobody can act on.
  static Duration _floor(Duration d) => d.isNegative ? Duration.zero : d;

  Duration? get voiceLeft => left(CallMode.voice);
  Duration? get videoLeft => left(CallMode.video);

  /// This kind of call cannot be placed any more.
  ///
  /// Per-mode, because video answers to a ceiling voice does not: with the
  /// data cap spent but minutes to spare, a voice call is still fine, and
  /// refusing it would be refusing the cheap thing because the expensive
  /// one ran out.
  bool isSpent(CallMode mode) => left(mode) == Duration.zero;

  /// Neither kind can be placed. Only used for the card's copy — the call
  /// itself is refused per-mode by [isSpent].
  bool get isExhausted =>
      isMetered && isSpent(CallMode.voice) && isSpent(CallMode.video);

  /// Enough gone to be worth mentioning, but not yet worth interrupting.
  /// Below this the meter stays off every surface — see PROGRESS.md § Calls.
  static const noticeAt = 0.7;

  /// Where the remaining time starts riding the ended-call line in the
  /// thread, because by here it changes what you would do next.
  static const warnAt = 0.9;

  bool get shouldShow => isMetered && fraction >= noticeAt;
  bool get shouldWarn => isMetered && fraction >= warnAt;

  /// When the buckets refill — the first of next month, locally. Shown on
  /// the exhausted screen, because a limit with no stated end reads as the
  /// feature having been taken away.
  static DateTime get resetsOn {
    final now = DateTime.now();
    return now.month == 12
        ? DateTime(now.year + 1, 1)
        : DateTime(now.year, now.month + 1);
  }

  factory CallUsage.fromMap(
    Map<String, dynamic> map,
    CallAllowance? allowance,
  ) =>
      CallUsage(
        voice: Duration(seconds: _int(map['voice_seconds'])),
        video: Duration(seconds: _int(map['video_seconds'])),
        calls: _int(map['calls']),
        allowance: allowance,
      );

  /// `sum()` and `count()` come back as bigints, which PostgREST may render
  /// as a number or, past 2^53, as a string. Same defence as CoupleStats.
  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

/// This month's calling, counted in Postgres.
///
/// Kept off the message stream on purpose: the thread is capped and paged,
/// so a client-side sum would quietly stop counting once a couple talked
/// enough — the exact failure `coupleStatsProvider` documents, and the one
/// nobody reports because a plateau looks plausible.
final callUsageProvider = FutureProvider.autoDispose<CallUsage>((ref) async {
  final allowance = CallAllowance.configured;
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) {
    return CallUsage(allowance: allowance);
  }

  // Nothing to count against, so nothing to count. Saves a round trip on
  // every self-hosted build.
  if (allowance == null) return const CallUsage();

  final rows = await ref.watch(supabaseClientProvider).rpc<List<dynamic>>(
    'call_usage',
    params: {
      'p_pair': pair.id,
      // The month boundary is the reader's own — see migration 0027.
      'p_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
    },
  );
  if (rows.isEmpty) return CallUsage(allowance: allowance);
  return CallUsage.fromMap(
    (rows.first as Map).cast<String, dynamic>(),
    allowance,
  );
});

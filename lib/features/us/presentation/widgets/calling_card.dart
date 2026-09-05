import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../../calls/data/call_usage.dart';

/// How much calling the two of you have left this month.
///
/// ## Why it lives on Us and not on the chat
///
/// The allowance is **shared** — one media account, both of you drawing on
/// it — so it is a "we" number, and Us is where this app keeps those. Put
/// on the chat header it would sit beside their mood, turning "how are they
/// feeling" into "how much talking is left"; put on Home it would be a
/// utility gauge on the app's emotional surface.
///
/// ## Why it is usually not here at all
///
/// Nothing renders below 70% ([CallUsage.noticeAt]). Nobody wants to be
/// told they have used a fifth of their relationship, and a meter that is
/// always on teaches people to ration something the app exists to
/// encourage. It appears when it starts to matter and not before — and on a
/// self-hosted build, where there is no quota, it never appears at all.
class CallingCard extends ConsumerWidget {
  const CallingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(callUsageProvider).valueOrNull;
    if (usage == null || !usage.shouldShow) return const SizedBox.shrink();

    final spent = (usage.fraction * 100).clamp(0, 100).round();
    final low = usage.shouldWarn;

    // Owns its own leading gap, so the Us page can list it unconditionally
    // without leaving a double space on the months it stays hidden.
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ProgressRing(
              fraction: usage.fraction,
              // Pink only once it is nearly gone. Purple is this app's
              // ordinary accent; the shift is the whole signal, so nothing
              // else on the card needs to shout.
              color: low ? AppColors.brand : AppColors.secondary,
              trackColor: AppColors.surfaceSubtle,
              size: 58,
              center: Text(
                '$spent%',
                style:
                    AppText.label(low ? AppColors.brand : AppColors.secondary)
                        .copyWith(fontSize: 12.5, letterSpacing: 0),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Calling this month',
                    style: AppText.subtitle().copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // The translation line. A single "hours left" would be a
                  // lie for one of the two modes — video is capped by data
                  // and voice by minutes, and they empty at wildly different
                  // rates — so both are named and the reader picks.
                  Text(
                    _remaining(usage),
                    style: AppText.caption(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "about 6 hr of video, or 30 hr of voice" — rounded hard, because a
  /// figure to the minute invites arithmetic nobody should be doing about
  /// talking to someone they love.
  String _remaining(CallUsage usage) {
    // Null means that bucket is uncapped, which is a different sentence
    // from "none left" — the card must never render infinity as a figure.
    final video = usage.videoLeft;
    final voice = usage.voiceLeft;

    if (usage.isExhausted) return 'Spent. Comes back on the 1st.';
    if (video == Duration.zero) {
      return voice == null
          ? 'Video is spent · voice is unlimited'
          : 'Video is spent · about ${_rough(voice)} of voice left';
    }
    if (voice == Duration.zero) {
      return video == null
          ? 'Voice is spent · video is unlimited'
          : 'Voice is spent · about ${_rough(video)} of video left';
    }
    if (video == null) return 'About ${_rough(voice!)} of voice left';
    if (voice == null) return 'About ${_rough(video)} of video left';
    return 'About ${_rough(video)} of video, or ${_rough(voice)} of voice';
  }

  static String _rough(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final hours = d.inMinutes / 60;
    // One decimal below three hours, whole hours above: "2.5 hr" is useful,
    // "31.4 hr" is false precision on an estimate that is already a few
    // percent light (see migration 0027).
    return hours < 3 ? '${hours.toStringAsFixed(1)} hr' : '${hours.round()} hr';
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../calls/data/call_usage.dart';
import '../../../calls/domain/call.dart';
import '../../../calls/domain/call_notifier.dart';
import '../../data/flower_repository.dart';

/// A call, in the thread.
///
/// **This is the load-bearing half of the calling feature.** Local
/// notifications cannot wake a backgrounded app (PROGRESS.md §
/// Notifications), so nothing in this app can ring a phone that isn't
/// already open. What can reach the other person is a row in the
/// conversation — realtime-delivered, unread-badged, and still there an hour
/// later. So the invitation is the product, and the ring, when push exists,
/// will be an accelerator on top of it.
///
/// Two renderings, because a call is two different things depending on
/// whether it is still happening:
///  - **live** — an invitation, with a Join that means it;
///  - **over** — a line of history, centred and quiet like a date divider.
class CallBubble extends ConsumerWidget {
  const CallBubble({super.key, required this.message, required this.isMine});

  final FlowerMessage message;
  final bool isMine;

  static final _time = DateFormat.jm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = message.call;
    if (mode == null) return const SizedBox.shrink();

    return message.isLiveCall
        ? _live(context, ref, mode)
        : _ended(mode, ref.watch(callUsageProvider).valueOrNull);
  }

  /// The invitation. Deliberately the only thing in the thread that carries
  /// the signature gradient — design.md spends it once per screen region on
  /// the primary action, and while a call is live, joining it is that.
  Widget _live(BuildContext context, WidgetRef ref, CallMode mode) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.blushMid),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppGradients.cta,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(mode.icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mode.label,
                            style: AppText.subtitle().copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Started ${_time.format(message.sentAt)}'
                            ' · still going',
                            style: AppText.caption(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  ref.read(callNotifierProvider.notifier).join(message);
                  context.push(Routes.call);
                },
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(gradient: AppGradients.cta),
                  child: Text(
                    // "Join", not "Answer": the call may have been going for
                    // twenty minutes, and answering something that stopped
                    // ringing long ago reads as a missed call, not an open
                    // door.
                    isMine ? 'Rejoin' : 'Join',
                    style: AppText.subtitle(Colors.white).copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// History. Centred and unstyled — a finished call is not a message
  /// either of you wrote, and giving it a bubble would put words in the
  /// thread that nobody said.
  ///
  /// Carries what is left of the month's calling, but **only past 90%**,
  /// and only here. Just after a call is the one honest moment to mention a
  /// limit: before one it would make you hesitate to ring your partner,
  /// which is the app arguing against its own purpose.
  Widget _ended(CallMode mode, CallUsage? usage) {
    final duration = message.callDuration;
    // A call with no end timestamp that has aged out of `isLiveCall` was
    // abandoned rather than finished — both apps died, or the hang-up never
    // landed. Reporting a two-hour duration for it would be a lie the row
    // cannot support, so it reads as missed instead.
    final abandoned = message.callEndedAt == null;

    final label = abandoned
        ? '${mode.label} · no answer'
        : '${mode.label} · ${describeCallDuration(duration ?? Duration.zero)}';

    // The remainder in the currency of the call just finished — how much
    // video is left after a video call, voice after a voice call. Quoting
    // both would turn a one-line record into a billing statement.
    // Null covers both "not worth mentioning yet" and "this bucket is
    // uncapped" — neither should put a figure in the thread.
    final left =
        usage == null || !usage.shouldWarn ? null : usage.left(mode);

    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              abandoned ? CupertinoIcons.phone_down : mode.icon,
              size: 12,
              color: AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(label, style: AppText.caption()),
            if (left != null) ...[
              Text(' · ', style: AppText.caption()),
              Text(
                left == Duration.zero
                    ? 'none left this month'
                    : '${describeCallDuration(left)} left this month',
                // Tinted, not red: running low is information, not an
                // error, and a warning colour in the middle of the thread
                // would read as something having gone wrong between you.
                style: AppText.caption(AppColors.secondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

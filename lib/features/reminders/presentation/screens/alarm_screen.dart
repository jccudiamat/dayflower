import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../data/reminder_repository.dart';
import '../../data/reminder_scheduler.dart';

/// The ringing screen — what a reminder alarm looks like when it goes off.
///
/// Reached two ways, both of which land here with the reminder's id:
///  - the alarm's **full-screen intent**, which starts the app over the
///    lock screen (see `showWhenLocked` on MainActivity), and
///  - tapping the notification, whether the app was running or not.
///
/// It is deliberately outside the bottom-nav shell. An alarm is not a place
/// in the app you navigated to; it is an interruption with exactly two ways
/// out, and offering the tab bar would invite a third.
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key, required this.reminderId});

  final String reminderId;

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> {
  Timer? _clock;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The sound and vibration are the OS's, not ours — but the notification
    // stays up because it is `ongoing`, so silence it the moment the screen
    // is actually in front of someone. Looking at the alarm is
    // acknowledging it.
    ReminderScheduler.stopRinging(widget.reminderId);
    // The big clock has to tick or it reads as a screenshot.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Reminder? get _reminder => (ref.watch(remindersProvider).valueOrNull ??
          const <Reminder>[])
      .firstWhereOrNull((r) => r.id == widget.reminderId);

  Future<void> _act(Future<void> Function(ReminderRepository) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(reminderRepositoryProvider));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update that: $e')),
        );
      }
    }
    if (!mounted) return;
    _leave();
  }

  /// An alarm dismissed from a cold start has nothing to pop back to, so
  /// this goes *to* Home rather than popping.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminder = _reminder;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final now = DateTime.now();

    // The row can be missing for honest reasons — deleted by the partner,
    // or the list has not loaded yet in a cold start. Either way there is
    // still a ringing phone to deal with, so the screen renders and offers
    // the way out rather than showing an error.
    final title = reminder?.title ?? 'Reminder';
    final from = reminder == null
        ? null
        : reminder.isFromPartner(ref.watch(currentUserIdProvider))
            ? (partner?.petName ?? partner?.displayName)
            : null;

    return PopScope(
      // Back must not be a third way out. Snooze and Done are the exits —
      // that is what stops an alarm being dismissed by reflex.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.darkCanvas,
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.hero),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  Text(
                    DateFormat('h:mm').format(now),
                    style: AppText.display(AppColors.onDark).copyWith(
                      fontSize: 68,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    DateFormat('a  ·  EEEE d MMMM').format(now),
                    style: AppText.caption(AppColors.onDarkMuted),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  _RingingBell(emoji: reminder?.emoji ?? '⏰'),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppText.hero(AppColors.onDark),
                  ),
                  if (reminder?.note?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      reminder!.note!.trim(),
                      textAlign: TextAlign.center,
                      style: AppText.note(AppColors.onDarkMuted),
                    ),
                  ],
                  if (from != null) ...[
                    const SizedBox(height: AppSpace.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.sm, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text('$from set this for you 💗',
                          style: AppText.caption(AppColors.onDark)),
                    ),
                  ],
                  const Spacer(flex: 3),
                  GradientButton(
                    label: _busy ? 'Just a sec…' : 'Done',
                    loading: _busy,
                    onPressed: reminder == null
                        ? _leave
                        : () => _act((repo) => repo.markDone(reminder)),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  OutlinePillButton(
                    label: 'Snooze ${kSnoozeDuration.inMinutes} minutes',
                    dark: true,
                    onPressed: _busy || reminder == null
                        ? null
                        : () => _act(
                              (repo) => repo.snooze(reminder, kSnoozeDuration),
                            ),
                  ),
                  if (reminder != null && reminder.repeats) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      'Repeats ${reminder.repeat.label.toLowerCase()}',
                      style: AppText.label(AppColors.onDarkMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bell that rocks. The only motion on the screen, because an alarm that
/// sits perfectly still looks like it has already been dealt with.
class _RingingBell extends StatefulWidget {
  const _RingingBell({required this.emoji});
  final String emoji;

  @override
  State<_RingingBell> createState() => _RingingBellState();
}

class _RingingBellState extends State<_RingingBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(
        // ±0.12 rad. Enough to read as ringing, small enough not to look
        // like a cartoon.
        angle: (_controller.value - 0.5) * 0.24,
        child: child,
      ),
      child: Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
        ),
        child: Text(widget.emoji, style: const TextStyle(fontSize: 44)),
      ),
    );
  }
}

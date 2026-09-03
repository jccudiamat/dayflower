import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../../core/widgets/ios_back_button.dart';
import '../../data/activity_models.dart';
import '../../data/activity_repository.dart';
import '../widgets/activity_timeline.dart';

/// Everything that has happened, grouped by day.
///
/// Sub-route of Home rather than of the Activities hub, even though the
/// word overlaps: this is reached from the Home section and the tab under
/// it should stay lit on the tab you came from. (The Activities hub is a
/// menu of features — reminders, finance, chapters — not a log.)
class ActivityFeedScreen extends ConsumerStatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  ConsumerState<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends ConsumerState<ActivityFeedScreen> {
  /// The watermark as it was when this screen opened.
  ///
  /// Held rather than watched, because opening the screen immediately moves
  /// the real one. Without this the "new" dots would clear under the user's
  /// eyes on the first frame — they would never see which entries were the
  /// ones they hadn't read.
  DateTime? _seenOnEntry;
  bool _capturedEntry = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: reading the watermark provider during build is
    // what a post-frame callback exists to avoid, and the write has to
    // happen after the read or it marks itself seen.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final seen = await ref.read(activityLastSeenProvider.future);
      if (!mounted) return;
      setState(() {
        _seenOnEntry = seen;
        _capturedEntry = true;
      });
      await markActivityFeedSeen(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(activityFeedProvider);
    // Watched unconditionally, not read inside the branch below. A
    // conditional watch loses its subscription the moment the condition
    // flips, and this provider is autoDispose — the read in initState
    // depends on this keeping it alive.
    final seenAsync = ref.watch(activityLastSeenProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IosBackButton(onTap: () => context.go(Routes.home)),
                  const SizedBox(width: AppSpace.xs),
                  const Expanded(
                    child: FeatureScreenHeader(
                      title: 'Activity',
                      subtitle: 'Everything the two of you have been up to',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Expanded(
              child: feed.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => _Notice(
                  emoji: '🌧️',
                  title: "Couldn't load your activity",
                  body: '$error',
                ),
                data: (all) => all.isEmpty
                    ? const _Notice(
                        emoji: '🌱',
                        title: 'Nothing yet',
                        body: 'Set a reminder, add a goal or start a photo '
                            'strip — it turns up here for both of you.',
                      )
                    : _GroupedTimeline(
                        activities: all,
                        // Until the entry watermark has been captured,
                        // fall back to the live one — so nothing is drawn
                        // as already-seen on the first frame.
                        lastSeen: _capturedEntry
                            ? _seenOnEntry
                            : seenAsync.valueOrNull,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Day headings over the same timeline Home draws.
///
/// The rail restarts inside each day rather than running through the
/// heading: a dashed line crossing "Yesterday" would say those two entries
/// are adjacent when a heading has just said they are not.
class _GroupedTimeline extends StatelessWidget {
  const _GroupedTimeline({required this.activities, required this.lastSeen});

  final List<Activity> activities;
  final DateTime? lastSeen;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Activity>>{};
    for (final a in activities) {
      groups.putIfAbsent(_dayLabel(a.createdAt), () => []).add(a);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.sm, 0, AppSpace.sm, AppSpace.md),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
                top: AppSpace.xs, bottom: AppSpace.xs, left: 2),
            child: Text(entry.key.toUpperCase(), style: AppText.label()),
          ),
          ActivityTimeline(activities: entry.value, lastSeen: lastSeen),
          const SizedBox(height: AppSpace.xs),
        ],
      ],
    );
  }

  static String _dayLabel(DateTime when) {
    final now = DateTime.now();
    final day = DateTime(when.year, when.month, when.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    // Within the week the weekday is friendlier than a date; beyond it the
    // weekday stops being enough to place anything.
    if (difference < 7) return DateFormat('EEEE').format(when);
    if (when.year == now.year) return DateFormat('d MMMM').format(when);
    return DateFormat('d MMMM y').format(when);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.emoji, required this.title, required this.body});

  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 34)),
            const SizedBox(height: AppSpace.xs),
            Text(title, style: AppText.title()),
            const SizedBox(height: AppSpace.xxs),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppText.caption(AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

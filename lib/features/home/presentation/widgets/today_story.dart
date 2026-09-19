import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/zone_distance.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/story_components.dart';
import '../../../../core/widgets/timezone_picker.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../../tulip/data/flower_repository.dart';
import '../../../dates/data/event_repository.dart';
import '../../../us/domain/couple_dates.dart';
import '../../../memories/data/relationship_memory.dart';
import '../../../memories/presentation/widgets/memory_tile.dart';

class LocationPreview extends ConsumerStatefulWidget {
  const LocationPreview({super.key, this.openMap = true});
  final bool openMap;
  @override
  ConsumerState<LocationPreview> createState() => _LocationPreviewState();
}

class _LocationPreviewState extends ConsumerState<LocationPreview> {
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(userProfileProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    Widget city(UserProfile? p, String fallback) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              p?.city?.split(',').first ??
                  (p?.timezone == null ? fallback : zoneCity(p!.timezone)),
              style: AppText.subtitle()),
          Text(
              p?.timezone == null
                  ? 'Choose a time zone'
                  : DateFormat('h:mm a')
                      .format(tz.TZDateTime.now(safeLocation(p!.timezone))),
              style: AppText.caption(AppColors.body)),
        ]);
    return Material(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
            onTap: widget.openMap ? () => context.push(Routes.ourMap) : null,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
                padding: const EdgeInsets.all(AppSpace.sm),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: city(me, 'You')),
                        const Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: AppSpace.xs),
                            child: AppIcon(CupertinoIcons.airplane,
                                color: AppColors.secondary)),
                        Expanded(child: city(partner, 'Your partner'))
                      ]),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                          profileDistanceLabel(me, partner) ??
                              'Close, wherever you are.',
                          style: AppText.body(AppColors.ink)),
                      const SizedBox(height: AppSpace.xxs),
                      Text('Based on your shared cities',
                          style: AppText.caption()),
                      if (widget.openMap)
                        Align(
                            alignment: Alignment.centerRight,
                            child: Text('See on map →',
                                style: AppText.caption(AppColors.secondary))),
                    ]))));
  }
}

class ComingUpPreview extends ConsumerWidget {
  const ComingUpPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = ref.watch(currentPairProvider).valueOrNull?.togetherSince;
    final events = <({DateTime date, String title})>[
      if (start != null)
        (date: nextMonthsary(start, now), title: 'Our monthsary'),
      for (final row in ref.watch(customEventsProvider).valueOrNull ??
          <Map<String, dynamic>>[])
        if (DateTime.tryParse('${row['date']}') case final date?)
          if (!date.isBefore(today))
            (date: date, title: row['title'] as String? ?? 'Our next moment'),
    ]..sort((a, b) => a.date.compareTo(b.date));
    if (events.isEmpty) return const SizedBox.shrink();
    final event = events.first;
    final days = DateTime(event.date.year, event.date.month, event.date.day)
        .difference(today)
        .inDays;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const StorySection('Coming up'),
      UtilityRow(
          icon: CupertinoIcons.calendar,
          title: event.title,
          subtitle:
              '${days == 0 ? 'Today' : days == 1 ? 'Tomorrow' : 'In $days days'} · ${DateFormat('d MMMM').format(event.date)}',
          onTap: () => context.push(Routes.events)),
    ]);
  }
}

class MemoryCallback extends ConsumerWidget {
  const MemoryCallback({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final memories = ref.watch(relationshipMemoriesProvider).valueOrNull ?? [];
    final sameDay = memories.where((m) =>
        m.date.year < now.year &&
        m.date.month == now.month &&
        m.date.day == now.day);
    final past = memories.where((m) => now.difference(m.date).inDays >= 7);
    final memory = sameDay.firstOrNull ?? past.firstOrNull;
    if (memory == null) return const SizedBox.shrink();
    final years = now.year - memory.date.year;
    return Column(children: [
      StorySection(sameDay.isNotEmpty
          ? (years == 1 ? 'A year ago today' : '$years years ago today')
          : 'A little look back'),
      MemoryTile(memory: memory)
    ]);
  }
}

class ReceivedFlowerPreview extends ConsumerWidget {
  const ReceivedFlowerPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserIdProvider);
    final messages = ref.watch(flowerMessagesProvider).valueOrNull ?? [];
    final flower = messages
        .where((m) =>
            m.senderId != user &&
            (m.flower != null || m.isBouquet) &&
            m.isFreshForWidget)
        .firstOrNull;
    if (flower == null) return const SizedBox.shrink();
    final memory = buildRelationshipMemories(
        messages: [flower], chapters: [], moments: [], places: []).single;
    return Column(children: [
      const StorySection('A little something for you'),
      MemoryTile(memory: memory)
    ]);
  }
}

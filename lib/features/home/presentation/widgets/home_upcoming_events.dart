import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../dates/data/event_repository.dart';
import '../../../reunion/data/reunion_repository.dart';
import '../../domain/home_moments.dart';

class HomeUpcomingEvents extends ConsumerStatefulWidget {
  const HomeUpcomingEvents({super.key});
  @override
  ConsumerState<HomeUpcomingEvents> createState() => _HomeUpcomingEventsState();
}

class _HomeUpcomingEventsState extends ConsumerState<HomeUpcomingEvents> {
  String? _selectedId;
  @override
  Widget build(BuildContext context) {
    final events = ref.watch(homeMomentsProvider);
    final now = ref.watch(homeClockProvider).valueOrNull ?? DateTime.now();
    final custom = ref.watch(customEventsProvider);
    final reunion = ref.watch(reunionProvider);
    var index = events.indexWhere((e) => e.id == _selectedId);
    if (index < 0) index = 0;
    final event = events.isEmpty ? null : events[index];
    void move(int step) =>
        setState(() => _selectedId = events[(index + step) % events.length].id);
    final failed = custom.hasError || reunion.hasError;
    return Column(
        key: const ValueKey('home-upcoming'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Coming up', style: AppText.title()),
          const SizedBox(height: AppSpace.sm),
          if (event == null && (custom.isLoading || reunion.isLoading))
            Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Text('Loading your dates…', style: AppText.body()))
          else if (event != null || !failed)
            GestureDetector(
                onHorizontalDragEnd: events.length > 1
                    ? (d) => move((d.primaryVelocity ?? 0) > 0 ? -1 : 1)
                    : null,
                child: Material(
                  color: event?.kind == HomeMomentKind.reunion
                      ? AppColors.surfaceSubtle
                      : AppColors.blush,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      side: BorderSide(color: AppColors.border)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                      onTap: () => event == null
                          ? context.push('${Routes.events}?add=1')
                          : _details(event),
                      child: Padding(
                          padding: const EdgeInsets.all(AppSpace.md),
                          child: LayoutBuilder(builder: (context, box) {
                            final content = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (event != null) ...[
                                    Text(event.countdown(now).toUpperCase(),
                                        style:
                                            AppText.label(AppColors.brandDark)),
                                    const SizedBox(height: AppSpace.xs),
                                  ],
                                  Text(
                                      event?.title ??
                                          'Make a date to look forward to',
                                      style: AppText.title()),
                                  const SizedBox(height: AppSpace.xs),
                                  Text(
                                      event == null
                                          ? 'Add a birthday, reunion or special day.'
                                          : event.kind ==
                                                  HomeMomentKind.monthsary
                                              ? 'Another month of us'
                                              : DateFormat('MMM d, yyyy')
                                                  .format(event.date),
                                      style: AppText.body()),
                                  const SizedBox(height: AppSpace.md),
                                  Text(
                                      event == null
                                          ? 'Add a date ›'
                                          : 'View details ›',
                                      style: AppText.subtitle(
                                          AppColors.brandDark)),
                                ]);
                            final art = Image.asset(
                                'assets/images/home_event_${event?.artwork ?? 'calendar'}.${event?.artwork == 'monthsary' ? 'webp' : 'png'}',
                                width: 116,
                                height: 140,
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                                cacheWidth: 348);
                            if (box.maxWidth < 260 ||
                                MediaQuery.textScalerOf(context).scale(14) >
                                    21) {
                              return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    content,
                                    const SizedBox(height: AppSpace.sm),
                                    Align(
                                        alignment: Alignment.centerRight,
                                        child: art)
                                  ]);
                            }
                            return Row(children: [
                              Expanded(child: content),
                              const SizedBox(width: 8),
                              art
                            ]);
                          }))),
                )),
          if (events.length > 1)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                  tooltip: 'Previous event',
                  onPressed: () => move(-1),
                  icon: const AppIcon(CupertinoIcons.chevron_left, size: 16)),
              Semantics(
                  liveRegion: true,
                  child: Text('${index + 1} of ${events.length}',
                      style: AppText.caption())),
              IconButton(
                  tooltip: 'Next event',
                  onPressed: () => move(1),
                  icon: const AppIcon(CupertinoIcons.chevron_right, size: 16)),
            ]),
          if (failed)
            TextButton.icon(
                onPressed: () {
                  ref.invalidate(customEventsProvider);
                  ref.invalidate(reunionProvider);
                },
                icon: const AppIcon(CupertinoIcons.refresh, size: 16),
                label: const Text('Some dates couldn’t load. Retry')),
        ]);
  }

  void _details(HomeMoment event) {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                              tooltip: 'Close event',
                              onPressed: () => Navigator.pop(sheet),
                              icon: const AppIcon(CupertinoIcons.xmark))),
                      Text(event.title, style: AppText.hero()),
                      const SizedBox(height: AppSpace.sm),
                      Text(DateFormat('EEEE, MMMM d, yyyy').format(event.date),
                          style: AppText.body()),
                      if (event.kind == HomeMomentKind.reunion)
                        Text(DateFormat('h:mm a').format(event.date),
                            style: AppText.body()),
                      if (event.location.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: AppSpace.sm),
                            child: Text(event.location, style: AppText.body())),
                      if (event.note.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: AppSpace.sm),
                            child: Text(event.note, style: AppText.body())),
                      const SizedBox(height: AppSpace.md),
                      OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheet);
                            context.push(Routes.events);
                          },
                          child: const Text('Open Events')),
                    ]))));
  }
}

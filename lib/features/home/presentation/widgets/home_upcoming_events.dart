import 'dart:async';
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

class _HomeUpcomingEventsState extends ConsumerState<HomeUpcomingEvents>
    with WidgetsBindingObserver {
  Timer? _rotation;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restartRotation();
  }

  void _restartRotation() {
    _rotation?.cancel();
    _rotation = Timer.periodic(
        const Duration(seconds: 5), (_) => _move(1, automatic: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _rotation?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _move(int step, {bool automatic = false}) {
    if (!mounted) return;
    if (automatic) {
      if (!_foreground ||
          ModalRoute.of(context)?.isCurrent != true ||
          MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.accessibleNavigationOf(context)) {
        return;
      }
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top >= MediaQuery.sizeOf(context).height ||
          top + box.size.height <= 0) {
        return;
      }
    }
    final events = ref.read(homeMomentsProvider);
    if (events.length < 2) return;
    final found = events.indexWhere((e) => e.id == _selectedId);
    final index = found < 0 ? 0 : found;
    setState(() => _selectedId = events[(index + step) % events.length].id);
    if (!automatic) _restartRotation();
  }

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
            ClipRect(
                child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                            position: Tween<Offset>(
                                    begin: const Offset(.15, 0),
                                    end: Offset.zero)
                                .animate(animation),
                            child: child)),
                    child: GestureDetector(
                        key: ValueKey(event?.id ?? 'empty-event'),
                        onHorizontalDragEnd: events.length > 1
                            ? (d) =>
                                _move((d.primaryVelocity ?? 0) > 0 ? -1 : 1)
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
                              onTap: () => context.push(Routes.events),
                              child: Padding(
                                  padding: const EdgeInsets.all(AppSpace.md),
                                  child: LayoutBuilder(builder: (context, box) {
                                    final content = Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (event != null) ...[
                                            Text(
                                                event
                                                    .countdown(now)
                                                    .toUpperCase(),
                                                style: AppText.label(
                                                    AppColors.brandDark)),
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
                                                          HomeMomentKind
                                                              .monthsary
                                                      ? 'Another month of us'
                                                      : DateFormat(
                                                              'MMM d, yyyy')
                                                          .format(event.date),
                                              style: AppText.body()),
                                          const SizedBox(height: AppSpace.md),
                                          Text(
                                              event == null
                                                  ? 'Add a date ›'
                                                  : 'View events ›',
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
                                        MediaQuery.textScalerOf(context)
                                                .scale(14) >
                                            21) {
                                      return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            content,
                                            const SizedBox(height: AppSpace.sm),
                                            Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: art)
                                          ]);
                                    }
                                    return Row(children: [
                                      Expanded(child: content),
                                      const SizedBox(width: 8),
                                      art
                                    ]);
                                  }))),
                        )))),
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
}

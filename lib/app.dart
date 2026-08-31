import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'app_router.dart';
import 'core/models/avatar_flower.dart';
import 'core/services/app_notifications.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/data/user_repository.dart';
import 'features/heartbeat/data/heartbeat_nudge.dart';
import 'features/heartbeat/data/heartbeat_repository.dart';
import 'features/reminders/data/reminder_repository.dart';
import 'features/reminders/data/reminder_scheduler.dart';
import 'features/tulip/data/flower_repository.dart';
import 'features/updates/data/update_repository.dart';
import 'features/updates/presentation/widgets/update_sheet.dart';
import 'features/widget/widget_sync.dart';

class DayflowerApp extends ConsumerStatefulWidget {
  const DayflowerApp({super.key});

  @override
  ConsumerState<DayflowerApp> createState() => _DayflowerAppState();
}

class _DayflowerAppState extends ConsumerState<DayflowerApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetTaps;

  @override
  void initState() {
    super.initState();
    // Resume is when a new build is most likely to be waiting: the phone was
    // put down while the APK was being published on the desktop.
    WidgetsBinding.instance.addObserver(this);
    _wireWidgetLaunches();
    _wireAlarmTaps();
    // ref.listen only fires on change, so seed the widget with whatever is
    // already pinned once the first frame has settled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncWidget(ref.read(widgetFlowerProvider));
        ReminderScheduler.sync(ref.read(myOpenRemindersProvider));
        HeartbeatNudge.sync(
            sentToday: ref.read(todayHeartbeatCountsProvider).mine > 0);
        ref.read(updateControllerProvider.notifier).check();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Throttled inside the controller — coming back to the app twenty times
    // an hour must not mean twenty manifest fetches.
    if (lifecycle == AppLifecycleState.resumed) {
      ref.read(updateControllerProvider.notifier).check();
    }
  }

  /// Reminder alarms, both ways they can arrive.
  ///
  /// The cold start is the important one: an alarm's full-screen intent
  /// launches the app from dead, and the launch payload is the only record
  /// of which reminder is ringing. The ValueNotifier covers taps that land
  /// while the app is already up, where the plugin's callback has no
  /// context to navigate with.
  Future<void> _wireAlarmTaps() async {
    ringingReminderId.addListener(_openRingingAlarm);
    final launch = await AppNotifications.launchResponse();
    final id = ReminderScheduler.reminderIdOf(launch?.payload);
    // Snooze and Done were already handled in the background isolate; only
    // a plain tap should open the screen.
    if (id != null && launch?.actionId == null) {
      ringingReminderId.value = id;
    }
  }

  void _openRingingAlarm() {
    final id = ringingReminderId.value;
    if (id == null || !mounted) return;
    // Cleared immediately, so leaving the alarm screen can't be undone by
    // this same notifier firing again on a later rebuild.
    ringingReminderId.value = null;
    // Router gates still apply — an alarm on a signed-out phone lands on
    // Welcome rather than on a screen with nothing behind it.
    ref.read(routerProvider).go(Routes.alarmFor(id));
  }

  /// Widget taps — both the cold start and while the app is already running.
  Future<void> _wireWidgetLaunches() async {
    if (!DayflowerWidgets.isSupported) return;
    try {
      final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (launchUri != null) _openTulip();
      _widgetTaps = HomeWidget.widgetClicked.listen((_) => _openTulip());
    } catch (e) {
      debugPrint('widget launch wiring failed: $e');
    }
  }

  void _openTulip() {
    // Router gates still apply — a signed-out tap lands on Welcome.
    // Straight to the thread: the widget shows a flower, and the tap means
    // "show me that", not "show me a list with it in".
    ref.read(routerProvider).go(Routes.chat);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetTaps?.cancel();
    ringingReminderId.removeListener(_openRingingAlarm);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Keep the home-screen widget in step with the flower the partner last
    // pinned to it. Watching from the root means the realtime stream stays
    // alive app-wide, so a flower arriving while the user is elsewhere still
    // updates the widget.
    ref.listen<FlowerMessage?>(
      widgetFlowerProvider,
      (_, received) => _syncWidget(received),
    );
    ref.listen<bool>(
      sentFlowerTodayProvider,
      (_, __) => _syncWidget(ref.read(widgetFlowerProvider)),
    );
    ref.listen<({int mine, int partner})>(
      todayHeartbeatCountsProvider,
      (prev, counts) {
        _syncHeartbeat(prev, counts);
        // Sending cancels today's nudge and arms tomorrow's; the count also
        // drops back to zero at midnight, which re-arms today's.
        if (prev?.mine != counts.mine) {
          HeartbeatNudge.sync(sentToday: counts.mine > 0);
        }
      },
    );

    // Reminders my partner sets for me arrive over realtime and have to be
    // handed to the OS to become actual alarms. Listening from the root is
    // what makes that happen wherever the user happens to be in the app —
    // and it is the only place it happens, so a reminder created while the
    // recipient's app is closed is not scheduled until they next open it.
    // See the class doc on ReminderScheduler.
    ref.listen<List<Reminder>>(
      myOpenRemindersProvider,
      (_, mine) => ReminderScheduler.sync(mine),
    );

    // A newly published build interrupts wherever the user happens to be.
    // The sheet hangs off the router's navigator, not this context: this
    // widget sits *above* MaterialApp, so there is no Navigator beneath it.
    ref.listen<UpdateStage>(
      updateControllerProvider.select((state) => state.stage),
      (previous, stage) {
        if (stage != UpdateStage.available ||
            previous == UpdateStage.available) {
          return;
        }
        final navigatorContext =
            router.routerDelegate.navigatorKey.currentContext;
        if (navigatorContext == null) return;
        showUpdateSheet(
          navigatorContext,
          mandatory: ref.read(updateControllerProvider).mandatory,
        );
      },
    );

    return MaterialApp.router(
      title: 'Dayflower',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      // Both are no-ops once DevicePreview is disabled (release), but without
      // them the app ignores the frame and keeps rendering at the real window
      // size — the picker would appear to do nothing.
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
    );
  }

  /// Their avatar flower's emoji, for the widget's story header.
  String get _partnerFlower {
    final partner = ref.read(partnerProfileProvider).valueOrNull;
    return (partner?.flower ?? AvatarFlower.fallback).emoji;
  }

  String get _partnerName {
    final partner = ref.read(partnerProfileProvider).valueOrNull;
    return partner?.petName ?? partner?.displayName ?? 'your partner';
  }

  void _syncWidget(FlowerMessage? received) {
    if (!DayflowerWidgets.isSupported) return;
    DayflowerWidgets.syncFlower(
      received: received,
      sentToday: ref.read(sentFlowerTodayProvider),
      partnerName: _partnerName,
      partnerFlower: _partnerFlower,
      // Passed as a callback rather than importing the repository into the
      // widget layer: widget_sync has no Riverpod container and runs from a
      // background isolate too, where providers do not exist.
      downloadPhoto: ref.read(flowerRepositoryProvider).downloadPhoto,
    );
  }

  void _syncHeartbeat(
    ({int mine, int partner})? prev,
    ({int mine, int partner}) counts,
  ) {
    if (!DayflowerWidgets.isSupported) return;
    // Which way the beat went decides the ripple colour. The first emission
    // has no previous value — that's the initial load, not a new pulse.
    final bool? pulseSent = prev == null
        ? null
        : counts.mine > prev.mine
            ? true
            : counts.partner > prev.partner
                ? false
                : null;
    DayflowerWidgets.syncHeartbeat(
      mine: counts.mine,
      partner: counts.partner,
      partnerName: _partnerName,
      pulseSent: pulseSent,
    );
  }
}

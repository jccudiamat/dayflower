import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'app_router.dart';
import 'core/models/avatar_flower.dart';
import 'core/services/app_notifications.dart';
import 'core/services/partner_alerts.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/supabase_provider.dart';
import 'features/activity/data/activity_models.dart';
import 'features/activity/data/activity_repository.dart';
import 'core/models/pair.dart';
import 'core/models/user_profile.dart';
import 'features/onboarding/data/user_repository.dart';
import 'features/pairing/data/pair_repository.dart';
import 'features/heartbeat/data/heartbeat_nudge.dart';
import 'features/heartbeat/data/heartbeat_repository.dart';
import 'features/reminders/data/reminder_repository.dart';
import 'features/reminders/data/reminder_scheduler.dart';
import 'features/tulip/data/flower_repository.dart';
import 'features/calls/data/call_alerts.dart';
import 'features/calls/domain/call_notifier.dart';
import 'features/calls/data/call_pip.dart';
import 'features/calls/data/call_repository.dart';
import 'features/calls/domain/call.dart';
import 'features/updates/data/update_alerts.dart';
import 'features/updates/data/update_repository.dart';
import 'features/updates/presentation/widgets/update_screen.dart';
import 'features/widget/widget_sync.dart';

class DayflowerApp extends ConsumerStatefulWidget {
  const DayflowerApp({super.key});

  @override
  ConsumerState<DayflowerApp> createState() => _DayflowerAppState();
}

class _DayflowerAppState extends ConsumerState<DayflowerApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetTaps;

  /// Whether the app is actually on screen.
  ///
  /// This is the switch every alert in the app hangs off: a notification
  /// posted while the user is looking at the thread is noise, and the
  /// screen they are looking at already says the same thing better. Seeded
  /// as resumed because that is what a cold start is — the first lifecycle
  /// callback does not arrive until something changes.
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  bool get _foreground => _lifecycle == AppLifecycleState.resumed;

  /// Android only ever shows the notification prompt once, so asking twice
  /// is harmless — but asking on every rebuild is sloppy, and this makes
  /// the "exactly once per launch" obvious to whoever reads it next.
  bool _askedForNotifications = false;

  /// ⚠️ Built once, not per build. `Router` add/removes its callback every
  /// time this changes identity, and a new one each frame is churn with a
  /// window where the back button belongs to nobody.
  late final _backDispatcher = _UpdateBackButtonDispatcher(ref);

  @override
  void initState() {
    super.initState();
    // Resume is when a new build is most likely to be waiting: the phone was
    // put down while the APK was being published on the desktop.
    WidgetsBinding.instance.addObserver(this);
    // Native tells us when the floating window opens and closes.
    wirePipMode(ref);
    _wireWidgetLaunches();
    _wireAlarmTaps();
    _wireNotificationRoutes();
    // ref.listen only fires on change, so seed the widget with whatever is
    // already pinned once the first frame has settled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncWidget(ref.read(widgetFlowerProvider));
        ReminderScheduler.sync(ref.read(myOpenRemindersProvider));
        HeartbeatNudge.sync(
            sentToday: ref.read(todayHeartbeatCountsProvider).mine > 0);
        ref.read(updateControllerProvider.notifier).check();
        _maybeAskForNotifications(ref.read(currentPairProvider));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    _lifecycle = lifecycle;
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

  /// Every notification that is not a reminder alarm: a message, a photo,
  /// an activity, a published build. All of them want one thing — open a
  /// route — so they share one payload shape and land here.
  Future<void> _wireNotificationRoutes() async {
    AppNotifications.pendingRoute.addListener(_openPendingRoute);
    final launch = await AppNotifications.launchResponse();
    final route = AppNotifications.routeOf(launch?.payload);
    if (route != null) AppNotifications.pendingRoute.value = route;
  }

  void _openPendingRoute() {
    final route = AppNotifications.pendingRoute.value;
    if (route == null || !mounted) return;
    // Cleared first, so navigating away again cannot be undone by this same
    // notifier firing on a later rebuild — same reasoning as the alarm.
    AppNotifications.pendingRoute.value = null;
    // Router gates still apply: a tap on a signed-out phone lands on
    // Welcome rather than on a screen with nothing behind it.
    ref.read(routerProvider).go(route);
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
    //
    // The widget's "Send message" pill lands here too, which is the point
    // of it: a home-screen widget cannot host a text field, so the honest
    // version of that control is a door to the place that can take one.
    // The tulip beside it never reaches this method — it is a background
    // action and deliberately costs no app launch.
    ref.read(routerProvider).go(Routes.chat);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetTaps?.cancel();
    ringingReminderId.removeListener(_openRingingAlarm);
    AppNotifications.pendingRoute.removeListener(_openPendingRoute);
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
    // Changing your picture has to reach their home screen too — without
    // this the widget keeps the old face until the next flower arrives.
    ref.listen<AsyncValue<UserProfile?>>(
      partnerProfileProvider,
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

    // The pair resolving is the cue to ask for notification permission —
    // and the post-frame read in initState covers the case where it had
    // already resolved before this listener existed.
    ref.listen<AsyncValue<Pair?>>(
      currentPairProvider,
      (_, next) => _maybeAskForNotifications(next),
    );

    // A message or a photo landing while the app is in the background is
    // the whole ask behind notifications — "so they'd know without opening
    // the app". Listening from the root is what makes the realtime stream
    // stay connected wherever the user is, and PartnerAlerts decides which
    // of these are actually new. See its class doc for how far this
    // reaches: a killed process hears nothing.
    ref.listen<AsyncValue<List<FlowerMessage>>>(
      flowerMessagesProvider,
      (_, next) => _alertMessages(next.valueOrNull ?? const []),
    );

    // Same idea, quieter channel: a reminder set, a goal ticked off, half a
    // photo strip waiting on you.
    ref.listen<AsyncValue<List<Activity>>>(
      activityFeedProvider,
      (_, next) => _alertActivity(next.valueOrNull ?? const []),
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

    // ⚠️ Tells the Activity whether it may shrink into the floating window
    // on Home/recents. `onUserLeaveHint` fires on every exit from the app,
    // so without this leaving the home screen would float a call that is
    // not happening. Only Dart knows one is live.
    ref.listen<CallSession?>(callNotifierProvider, (_, session) {
      CallPip.setCallActive(
        session != null && !session.status.isTerminal,
      );
    });

    // 🔴 An incoming call used to raise **nothing**. The ring lived entirely
    // inside the app — the provider fires, the shell pushes the call screen
    // — which with Dayflower in the background is a screen nobody is looking
    // at. Calls went unanswered with the phone in a pocket and no sign they
    // had rung.
    //
    // ⚠️ Still only reaches a phone whose app is alive; see CallAlerts.
    ref.listen<FlowerMessage?>(incomingCallProvider, (previous, next) {
      if (next == null) {
        // Answered, declined, or gave up — all of them arrive here as the
        // provider going null, and the notification is `ongoing`, so
        // nothing else would ever take it off the lock screen.
        CallAlerts.stop();
        return;
      }
      CallAlerts.ring(
        callId: next.id,
        callerName: _partnerName,
        isVideo: next.call == CallMode.video,
        foreground: _foreground,
      );
    });

    // A newly published build interrupts wherever the user happens to be.
    // This listener no longer shows anything — it exists for the
    // notification, which is the half that only makes sense at the moment
    // the news arrives.
    ref.listen<UpdateStage>(
      updateControllerProvider.select((state) => state.stage),
      (previous, stage) {
        if (stage != UpdateStage.available ||
            previous == UpdateStage.available) {
          return;
        }
        // Posted before the sheet is raised, and it no-ops when the app is
        // on screen — the sheet is the better answer whenever there is one.
        // This is only for the check that finished after the phone was put
        // down. See UpdateAlerts for why that is as far as it goes.
        final release = ref.read(updateControllerProvider).release;
        if (release != null) {
          UpdateAlerts.announce(release, foreground: _foreground);
        }

        // 🔴 The sheet used to be raised here, on the router's navigator.
        // It flashed for a frame at launch and vanished: a modal pushed
        // that way is a *pageless* route bound to the page on top at the
        // time — the splash — and the gate redirect that replaced splash
        // with home took the sheet down with it. UpdateGate sits above the
        // Navigator now and needs nothing raised; it appears because the
        // state says so. See its class doc.
      },
    );

    return MaterialApp.router(
      title: 'Dayflower',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // 🔴 **Spelled out rather than `routerConfig: router`, and it has to
      // be.** `MaterialApp.router` asserts that `routerConfig` is the *only*
      // router argument — passing `backButtonDispatcher` beside it trips
      // "If the routerConfig is provided, all the other router delegates
      // must not be provided" and the whole app renders as Flutter's error
      // box: red in debug, a **flat grey rectangle** in release, which is
      // what it looked like on the phone.
      //
      // ⚠️ And the release build did not even fail loudly — assertions are
      // compiled out — so the dispatcher was simply dropped and the back
      // button never reached the updater at all. Silently wrong is the
      // reason this is written out longhand.
      //
      // GoRouter cannot take the dispatcher either: it hardcodes its own
      // `RootBackButtonDispatcher` in the constructor and the field is
      // final.
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
      backButtonDispatcher: _backDispatcher,
      // Both are no-ops once DevicePreview is disabled (release), but without
      // them the app ignores the frame and keeps rendering at the real window
      // size — the picker would appear to do nothing.
      locale: DevicePreview.locale(context),
      // ⚠️ UpdateGate goes *inside* DevicePreview's frame, not around it, or
      // the updater would paint over the device chrome in the preview
      // instead of inside the phone.
      builder: (context, child) =>
          DevicePreview.appBuilder(context, UpdateGate(child: child)),
    );
  }

  /// Asks for notification permission, once, and only once there is
  /// somebody to be notified about.
  ///
  /// Deliberately not at first launch: Android shows this prompt exactly
  /// once and never again, so spending it on the welcome screen — before
  /// the app has shown what it would notify you about — is spending it on
  /// a "no". By the time a pair is linked, every alert in the app has
  /// something real behind it.
  void _maybeAskForNotifications(AsyncValue<Pair?> pair) {
    if (_askedForNotifications) return;
    if (pair.valueOrNull?.isLinked != true) return;
    _askedForNotifications = true;
    PartnerAlerts.requestPermission();
  }

  /// Turns the whole thread into notification candidates.
  ///
  /// Everything they ever sent goes in, not just what looks new — the mark
  /// that decides "new" is persisted inside PartnerAlerts, because this
  /// widget is rebuilt and this process is killed far too often to be
  /// trusted with it.
  void _alertMessages(List<FlowerMessage> messages) {
    final myId = ref.read(currentUserIdProvider);
    if (myId == null) return;
    final from = _partnerName;

    PartnerAlerts.messages(
      foreground: _foreground,
      items: [
        for (final m in messages)
          if (m.senderId != myId)
            (
              at: m.sentAt,
              title: from,
              body: m.alertLine,
              // A photo sent straight to the home screen is not in the
              // thread at all, so opening the thread would show an empty
              // room. Home is where that one actually is.
              route: m.toChat ? Routes.chat : Routes.home,
            ),
      ],
    );
  }

  void _alertActivity(List<Activity> activities) {
    final myId = ref.read(currentUserIdProvider);
    if (myId == null) return;
    final from = _partnerName;

    PartnerAlerts.activity(
      foreground: _foreground,
      items: [
        for (final a in activities)
          // Your own entries never notify you. You were there.
          if (!a.isMine(myId) && a.actorId != null)
            (
              at: a.createdAt,
              title: a.sentence(myUserId: myId, partnerName: from),
              body: a.title,
              // Straight to the thing itself — the reminder, the chapter,
              // the camera — rather than to the list it is listed in.
              route: a.route ?? Routes.activityFeed,
            ),
      ],
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
      // Their actual face on the home screen when they have uploaded one.
      // The flower stays underneath as the fallback — same chain as every
      // other avatar in the app.
      partnerAvatarPath:
          ref.read(partnerProfileProvider).valueOrNull?.avatarPath,
      downloadAvatar: ref.read(userRepositoryProvider).downloadAvatar,
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

/// Lets the update layer answer the back button before the router does.
///
/// ⚠️ **The Router's dispatcher is the only hook that works here.** The
/// updater covers the whole screen from *above* the Router — see the class
/// doc on `UpdateGate` for why it has to — which leaves it with no route of
/// its own. `PopScope` needs a route; `BackButtonListener` needs a `Router`
/// ancestor and throws without one. Both are below this layer, not above it.
///
/// Without this, pressing back on a full-screen updater would quietly pop
/// the screen hidden behind it, or leave the app on the last route.
class _UpdateBackButtonDispatcher extends RootBackButtonDispatcher {
  _UpdateBackButtonDispatcher(this._ref);

  final WidgetRef _ref;

  @override
  Future<bool> invokeCallback(Future<bool> defaultValue) async {
    final state = _ref.read(updateControllerProvider);
    if (updateIsShowing(state, _ref.read(updateDismissedProvider))) {
      // Swallowed either way — the router must not act on a press aimed at
      // a screen it cannot see. A required update simply has no way past it;
      // mid-download there is no half of a download worth going back to.
      if (!state.mandatory && !state.busy) dismissUpdate(_ref);
      return true;
    }
    return super.invokeCallback(defaultValue);
  }
}

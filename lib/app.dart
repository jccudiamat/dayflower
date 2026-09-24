import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'app_router.dart';
import 'core/models/avatar_flower.dart';
import 'core/services/app_notifications.dart';
import 'core/services/partner_alerts.dart';
import 'core/services/pulse_alerts.dart';
import 'features/heartbeat/data/incoming_heartbeats.dart';
import 'features/heartbeat/data/pulse_alert_prefs.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_prefs.dart';
import 'core/providers/supabase_provider.dart';
import 'features/activity/data/activity_models.dart';
import 'features/activity/data/activity_repository.dart';
import 'core/models/pair.dart';
import 'core/models/user_profile.dart';
import 'features/onboarding/data/user_repository.dart';
import 'features/pairing/data/pair_repository.dart';
import 'features/home/data/mood_prefs.dart';
import 'features/heartbeat/data/heartbeat_nudge.dart';
import 'features/heartbeat/data/heartbeat_repository.dart';
import 'features/reminders/data/reminder_repository.dart';
import 'features/reminders/data/reminder_scheduler.dart';
import 'features/tulip/data/flower_repository.dart';
import 'features/calls/data/call_alerts.dart';
import 'features/calls/data/caller_avatar.dart';
import 'features/calls/data/native_calls.dart';
import 'features/calls/domain/call_notifier.dart';
import 'features/calls/data/call_pip.dart';
import 'features/presence/data/presence_repository.dart';
import 'features/push/data/push_repository.dart';
import 'features/push/data/push_service.dart';
import 'features/calls/presentation/screens/call_screen.dart';
import 'features/calls/data/call_repository.dart';
import 'features/calls/domain/call.dart';
import 'features/updates/data/update_alerts.dart';
import 'features/updates/data/update_repository.dart';
import 'features/updates/presentation/widgets/update_screen.dart';
import 'features/reunion/data/reunion_repository.dart';
import 'features/widget/widget_sync.dart';

class DayflowerApp extends ConsumerStatefulWidget {
  const DayflowerApp({super.key});

  @override
  ConsumerState<DayflowerApp> createState() => _DayflowerAppState();
}

class _DayflowerAppState extends ConsumerState<DayflowerApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetTaps;
  final _incomingHeartbeats = IncomingHeartbeats();

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
    // "Active now" in the chat header. Started here rather than by the chat
    // screen: being active means having the app open, not having this one
    // screen open, and a partner reading your photos is plainly around.
    ref.read(presencePingerProvider).start();
    // Native tells us when the floating window opens and closes.
    wirePipMode(ref);
    _wireWidgetLaunches();
    _wireAlarmTaps();
    _wireNotificationRoutes();
    _wireNativeCallButtons();
    // ref.listen only fires on change, so seed the widget with whatever is
    // already pinned once the first frame has settled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncWidget(ref.read(widgetFlowerProvider));
        _syncReminders(ref.read(pairOpenRemindersProvider));
        _syncHeartbeatNudge();
        ref.read(updateControllerProvider.notifier).check();
        _maybeAskForNotifications(ref.read(currentPairProvider));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    _lifecycle = lifecycle;
    // Stop claiming to be here the moment the app leaves the screen, and ping
    // immediately on the way back rather than up to a minute later.
    if (lifecycle == AppLifecycleState.resumed) {
      ref.read(presencePingerProvider).start();
      // The hearts waiting in the shade have now been seen. Clears the
      // notification and the running count behind it — see PulseAlerts.seen.
      unawaited(PulseAlerts.seen());
      // Yesterday's mood is not today's. Checked on the way back in, which
      // is when a day has actually turned under somebody — see
      // MoodPrefs.refresh for why this is not a midnight timer.
      ref.read(moodProvider.notifier).refresh();
      _syncHeartbeatNudge();
    } else {
      ref.read(presencePingerProvider).stop();
    }
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
    if (launch != null && CallAlerts.handleTap(launch)) return;
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
    // Welcome rather than on a screen with nothing behind it. Held through
    // them, or an alarm that launched the app lands on Home.
    goWhenReady(ref, Routes.alarmFor(id));
  }

  /// Every notification that is not a reminder alarm: a message, a photo,
  /// an activity, a published build. All of them want one thing — open a
  /// route — so they share one payload shape and land here.
  Future<void> _wireNotificationRoutes() async {
    AppNotifications.pendingRoute.addListener(_openPendingRoute);
    final launch = await AppNotifications.launchResponse();
    // tapRouteOf, not AppNotifications.routeOf: a reminder's run-up ping
    // has its own payload, and reading it with routeOf alone is what opened
    // a tapped "new reminder" on Home when the app had been closed.
    final route = tapRouteOf(launch?.payload);
    if (route != null) AppNotifications.pendingRoute.value = route;
  }

  void _openPendingRoute() {
    final route = AppNotifications.pendingRoute.value;
    if (route == null || !mounted) return;
    // Cleared first, so navigating away again cannot be undone by this same
    // notifier firing on a later rebuild — same reasoning as the alarm.
    AppNotifications.pendingRoute.value = null;
    // Router gates still apply: a tap on a signed-out phone lands on
    // Welcome rather than on a screen with nothing behind it. And the
    // destination is held through them - see goWhenReady.
    goWhenReady(ref, route);
  }

  /// Runs a provider-listener body once the container has settled.
  ///
  /// 🔴 **Riverpod runs `ref.listen` callbacks synchronously, in the middle
  /// of rebuilding the provider that fired them.** Every callback below then
  /// reads more providers — the partner's name, the user id, the day photos
  /// — and each of those reads can rebuild something that the rebuild
  /// already in flight is *iterating over*. Riverpod moves a rebuilding
  /// provider's dependency map aside as `_previousDependencies` and each
  /// `ref.watch` **removes** an entry from it, so the collision surfaces as
  /// a bare `ConcurrentModificationError` out of the framework's own guts,
  /// with no line of this app in the stack.
  ///
  /// That is the crash the user saw on **every sign-in**: the auth event
  /// rebuilds the whole graph at once, which is the one moment enough of
  /// these fire together to collide.
  ///
  /// A microtask cannot land mid-flush — the frame that drives it is
  /// synchronous end to end — so the body runs with the container settled
  /// and every value final rather than half-rebuilt.
  ///
  /// ⚠️ Everything here is a *side effect*: a notification, an OS alarm, a
  /// home-screen widget. None of it belongs inside a provider rebuild, and
  /// none of it is worse for happening a microtask later.
  void _settled(void Function() body) {
    scheduleMicrotask(() {
      if (mounted) body();
    });
  }

  /// Widget taps — both the cold start and while the app is already running.
  Future<void> _wireWidgetLaunches() async {
    if (!DayflowerWidgets.isSupported) return;
    try {
      final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (launchUri != null) _openWidgetTarget(launchUri);
      _widgetTaps = HomeWidget.widgetClicked.listen(_openWidgetTarget);
    } catch (e) {
      debugPrint('widget launch wiring failed: $e');
    }
  }

  /// Where a widget tap lands.
  ///
  /// ⚠️ There is more than one widget now, so the URI has to be read rather
  /// than assumed. Every tap used to open the conversation, which was right
  /// when the only widget was a flower and wrong the moment a countdown
  /// appeared beside it.
  void _openWidgetTarget(Uri? uri) {
    if (uri?.host == 'events') {
      // Router gates still apply — a signed-out tap lands on Welcome.
      ref.read(routerProvider).go(Routes.events);
      return;
    }
    _openTulip();
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
    // 🔴 **Watched here, and watched first.** routerGateProvider is what
    // drives the `authState → currentUserId → userProfile → pair` chain and
    // writes the snapshot the router's redirect reads; nothing else watches
    // it, and a provider nobody watches is a provider that never resolves —
    // build 19 left the app on the splash screen forever that way.
    //
    // First, because the router is created on the line below and its very
    // first redirect runs against whatever the gate holds at that moment.
    ref.watch(routerGateProvider);
    final router = ref.watch(routerProvider);

    // Keep the home-screen widget in step with the flower the partner last
    // pinned to it. Watching from the root means the realtime stream stays
    // alive app-wide, so a flower arriving while the user is elsewhere still
    // updates the widget.
    ref.listen<FlowerMessage?>(
      widgetFlowerProvider,
      (_, received) => _settled(() => _syncWidget(received)),
    );
    ref.listen<bool>(
      sentFlowerTodayProvider,
      (_, __) => _settled(() => _syncWidget(ref.read(widgetFlowerProvider))),
    );
    // Changing your picture has to reach their home screen too — without
    // this the widget keeps the old face until the next flower arrives.
    ref.listen<AsyncValue<UserProfile?>>(
      partnerProfileProvider,
      (_, __) => _settled(() => _syncWidget(ref.read(widgetFlowerProvider))),
    );
    // The countdown on the home screen comes from the same row as the card
    // on Events, so editing one moves the other. Watching from the root
    // keeps that stream alive app-wide — a partner changing the date while
    // this phone sits on the chat screen still reaches its widget.
    ref.listen<AsyncValue<Reunion?>>(
      reunionProvider,
      (_, next) => _settled(() => _syncReunion(next.valueOrNull)),
    );
    ref.listen<({int mine, int partner})>(
      todayHeartbeatCountsProvider,
      (prev, counts) => _settled(() {
        _syncHeartbeat(prev, counts);
      }),
    );

    // Listen to rows, not daily totals: loading or reconnecting isn't a tap.
    ref.listen<AsyncValue<List<Heartbeat>>>(heartbeatsProvider, (_, next) {
      _settled(() {
        final pair = ref.read(currentPairProvider).valueOrNull;
        final userId = ref.read(currentUserIdProvider);
        final beats = ref.read(heartbeatsProvider).asData?.value;
        if (pair?.isLinked != true || userId == null || beats == null) return;
        final partnerId = pair!.partnerIdFor(userId);
        if (partnerId == null) return;
        final incoming = _incomingHeartbeats.take(
          pairId: pair.id,
          userId: userId,
          partnerId: partnerId,
          beats: beats,
          now: DateTime.now(),
        );
        if (incoming.count > 0 && ref.read(pulseAlertsEnabledProvider)) {
          unawaited(PulseAlerts.handleIncoming(
            from: _partnerName,
            pulses: incoming.count,
            // Non-null whenever the count is — see IncomingHeartbeats.take.
            newestAt: incoming.newestAt ?? DateTime.now(),
            // ⚠️ Was never passed. Watching the home screen ripple and
            // getting a tray notification about the ripple is the app
            // telling you what you are looking at.
            foreground: _foreground,
          ));
        }
        _syncHeartbeatNudge();
      });
    });

    // The pair resolving is the cue to ask for notification permission —
    // and the post-frame read in initState covers the case where it had
    // already resolved before this listener existed.
    ref.listen<AsyncValue<Pair?>>(
      currentPairProvider,
      (_, next) => _settled(() {
        _maybeAskForNotifications(next);
        _syncHeartbeatNudge();
        if (next.valueOrNull?.isLinked != true) _incomingHeartbeats.reset();
      }),
    );

    // A message or a photo landing while the app is in the background is
    // the whole ask behind notifications — "so they'd know without opening
    // the app". Listening from the root is what makes the realtime stream
    // stay connected wherever the user is, and PartnerAlerts decides which
    // of these are actually new. See its class doc for how far this
    // reaches: a killed process hears nothing.
    ref.listen<AsyncValue<List<FlowerMessage>>>(
      flowerMessagesProvider,
      (_, next) => _settled(() => _alertMessages(next.valueOrNull ?? const [])),
    );

    // Same idea, quieter channel: a reminder set, a goal ticked off, half a
    // photo strip waiting on you.
    ref.listen<AsyncValue<List<Activity>>>(
      activityFeedProvider,
      (_, next) => _settled(() => _alertActivity(next.valueOrNull ?? const [])),
    );

    // Reminders my partner sets for me arrive over realtime and have to be
    // handed to the OS to become actual alarms. Listening from the root is
    // what makes that happen wherever the user happens to be in the app —
    // and it is the only place it happens, so a reminder created while the
    // recipient's app is closed is not scheduled until they next open it.
    // See the class doc on ReminderScheduler.
    ref.listen<List<Reminder>>(
      pairOpenRemindersProvider,
      (_, all) => _settled(() => _syncReminders(all)),
    );

    // ⚠️ Registered on sign-in, not at launch. A token written before there
    // is a session has nobody to attach to — PushRepository.register
    // correctly does nothing — and the phone would then stay silent until
    // the next reinstall rotated the token.
    ref.listen<String?>(currentUserIdProvider, (previous, userId) {
      if (userId != null && userId != previous) {
        _settled(
            () => PushService.registerFor(ref.read(pushRepositoryProvider)));
      }
    });

    // ⚠️ Tells the Activity whether it may shrink into the floating window
    // on Home/recents. `onUserLeaveHint` fires on every exit from the app,
    // so without this leaving the home screen would float a call that is
    // not happening. Only Dart knows one is live.
    _rememberCallerFace();

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
        //
        // ⚠️ `settle` rather than `stop`: it takes the ring down either
        // way, and when nothing here ended the call it leaves a missed-call
        // notice behind. Told which call from `previous`, because `next` is
        // null by definition at this point.
        CallAlerts.settle(
          callerName: _partnerName,
          isVideo: previous?.call == CallMode.video,
        );
        return;
      }
      _settled(() async => CallAlerts.ring(
            callId: next.id,
            callerName: _partnerName,
            isVideo: next.call == CallMode.video,
            foreground: _foreground,
            callerAvatar: await _partnerAvatar(),
          ));
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
        _settled(() {
          final release = ref.read(updateControllerProvider).release;
          if (release != null) {
            UpdateAlerts.announce(release, foreground: _foreground);
          }
        });

        // 🔴 The sheet used to be raised here, on the router's navigator.
        // It flashed for a frame at launch and vanished: a modal pushed
        // that way is a *pageless* route bound to the page on top at the
        // time — the splash — and the gate redirect that replaced splash
        // with home took the sheet down with it. UpdateGate sits above the
        // Navigator now and needs nothing raised; it appears because the
        // state says so. See its class doc.
      },
    );

    // 🔴 **Set before the tree is described, and the key is what makes it
    // land.** The palette lives in global state so ~950 `AppColors.x` call
    // sites did not have to learn about a BuildContext — the cost is that a
    // colour already baked into a `const` widget deeper down is not
    // reconsidered on rebuild. Changing the key throws that element tree
    // away, so every widget is inflated afresh and reads the new palette.
    // Without it the mode changes and half the screen keeps the old one.
    final mode = ref.watch(themeModeProvider);
    AppColors.use(mode);

    return MaterialApp.router(
      key: ValueKey(mode),
      title: 'Dayflower',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
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
      // ⚠️ CallPipGate outermost. In the floating window it replaces
      // everything — the app, the updater, all of it — because the window is
      // a few hundred points wide and a call is the only thing worth putting
      // in one.
      builder: (context, child) => DevicePreview.appBuilder(
        context,
        CallPipGate(child: UpdateGate(child: child)),
      ),
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

  /// Answer and Decline on the call notification's own buttons.
  ///
  /// 🔴 CallStyle draws those buttons itself, so their taps arrive as
  /// Activity intents and never touch flutter_local_notifications — none of
  /// the plugin's action handling sees them. Routed to the same places a tap
  /// on the plugin's actions goes, so there is one behaviour rather than two
  /// that drift.
  void _wireNativeCallButtons() {
    NativeCalls.onAction((action, callId) {
      if (action == 'decline') {
        ref.read(callNotifierProvider.notifier).decline();
        return;
      }
      // The card rather than a button - or the full-screen intent on a
      // locked phone: the ring screen, with nothing decided.
      if (action == 'open') {
        AppNotifications.pendingRoute.value = Routes.call;
        return;
      }
      // ⚠️ Parked rather than answered here. The call screen answers it on
      // the way in, which is the same path the lock-screen Answer already
      // took, and it works whether or not a session exists yet.
      CallAlerts.pendingAnswerId = callId;
      AppNotifications.pendingRoute.value = Routes.call;
    });
  }

  String get _partnerName {
    final partner = ref.read(partnerProfileProvider).valueOrNull;
    return partner?.petName ?? partner?.displayName ?? 'your partner';
  }

  /// The caller's face, for the call notification.
  ///
  /// 🔴 Read from disk, never fetched here. The first ring after a cold
  /// start had no photo because the partner's profile had not resolved yet,
  /// so there was nothing to fetch and the notification went out with no
  /// icon — the letter circle. Warmed by [_rememberCallerFace] instead, well
  /// before the phone rings. See CallerAvatar.
  Future<Uint8List?> _partnerAvatar() => CallerAvatar.cached();

  /// Keeps the caller's face on disk, so the next ring already has it.
  ///
  /// 🔴 **Called from build, and it has to be.** ref.listen is only legal
  /// during a build; from initState it does nothing useful, which is exactly
  /// what it did — the cache was never written and the first ring still had
  /// no photo, reported as "no avatar sent".
  ///
  /// ⚠️ Watches rather than reads: the profile arrives after the first
  /// frame, and on a cold start it arrives after the call row does.
  void _rememberCallerFace() {
    ref.listen<AsyncValue<UserProfile?>>(partnerProfileProvider,
        (previous, next) {
      final path = next.valueOrNull?.avatarPath;
      if (path == null || path.isEmpty) {
        if (previous?.valueOrNull?.avatarPath != null) CallerAvatar.forget();
        return;
      }
      if (previous?.valueOrNull?.avatarPath == path) return;
      _settled(() async {
        final url = await ref.read(avatarUrlProvider(path).future);
        if (url != null) await CallerAvatar.remember(url);
      });
    });
  }

  void _syncWidget(FlowerMessage? received) {
    if (!DayflowerWidgets.isSupported) return;
    // ⚠️ Their *other* live days, excluding the one already in `received`.
    // Including it would show the newest photo twice per rotation, which
    // reads as the widget stuttering rather than cycling.
    final theirDays = ref
        .read(partnerDayPhotosProvider)
        .where((m) => m.id != received?.id)
        .toList(growable: false);

    DayflowerWidgets.syncFlower(
      received: received,
      alsoLive: theirDays,
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

  /// Hands the whole pair's reminders to the scheduler, and announces any
  /// that were just set.
  ///
  /// ⚠️ Both halves of the couple, deliberately — see
  /// [pairOpenRemindersProvider]. The scheduler needs to know which of them
  /// are mine so only my own reminder takes over my screen, and it needs
  /// their name so the copy can say whose each one is.
  void _syncReminders(List<Reminder> reminders) {
    final myId = ref.read(currentUserIdProvider);
    ReminderScheduler.sync(
      reminders,
      myUserId: myId,
      partnerName: _partnerName,
    );
    ReminderScheduler.announceNew(
      reminders,
      myUserId: myId,
      partnerName: _partnerName,
    );
  }

  void _syncReunion(Reunion? reunion) {
    if (!DayflowerWidgets.isSupported) return;
    DayflowerWidgets.syncReunion(
      title: reunion?.title,
      place: reunion?.destination,
      // Null clears it. A reunion that has been deleted must not leave a
      // countdown frozen on the home screen counting to a date nobody has.
      happensAt: reunion?.happensAt,
    );
  }

  void _syncHeartbeatNudge() {
    final pair = ref.read(currentPairProvider).valueOrNull;
    final beats = ref.read(heartbeatsProvider).asData?.value;
    final userId = ref.read(currentUserIdProvider);
    final now = DateTime.now();
    final sentToday = beats?.any((beat) =>
            beat.senderId == userId &&
            beat.sentAt.year == now.year &&
            beat.sentAt.month == now.month &&
            beat.sentAt.day == now.day) ??
        false;
    unawaited(HeartbeatNudge.sync(
      sentToday: sentToday,
      eligible: pair?.isLinked == true && userId != null && beats != null,
    ));
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
/// Where the back button goes when there is nothing left to pop, or null to
/// let the press fall through to the Activity.
///
/// 🔴 Every tab is a dead end. The bottom bar navigates with go(), which
/// replaces the stack rather than growing it, so on Chat, Dayflower,
/// Memories or Together there is no history behind the current page and the
/// back button went straight out to the launcher. Back should leave the
/// section first, the same as pressing Home in the bar.
///
/// ⚠️ Home returns null, meaning "not handled" — the press falls through to
/// the Activity, which is how the app closes and how a live call becomes the
/// floating window over the launcher. Answering it here would keep the press
/// inside Dart and quietly cost both.
String? backFallbackRoute(String here) =>
    here == Routes.home ? null : Routes.home;

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

    // A pushed screen pops normally: details, sheets, the booth, anything
    // reached with push().
    if (await super.invokeCallback(defaultValue)) return true;

    // 🔴 Nothing left to pop, and that is the normal state of a tab.
    // The bottom bar navigates with go(), which replaces the stack rather
    // than growing it, so every tab is a dead end with no history behind
    // it — and the back button went straight past the app and out to the
    // launcher. Leaving Chat, Memories or Together should land on Home, the
    // same as pressing Home in the bar.
    final router = _ref.read(routerProvider);
    final fallback =
        backFallbackRoute(router.routeInformationProvider.value.uri.path);
    if (fallback != null) {
      router.go(fallback);
      return true;
    }

    // 🔴 The press would leave the app. With a call up that is the moment it
    // becomes the floating window over the launcher — not a moment sooner.
    //
    // ⚠️ Asked for from here rather than from `onBackPressed`, which is
    // where it used to live and where it fired far too early: that check ran
    // *before* the press was handed to Flutter, so during a call the call
    // screen never popped and the app just left. Everything above this line
    // — popping the call screen back to the conversation, then leaving the
    // section — now happens first, exactly as it does without a call.
    final call = _ref.read(callNotifierProvider);
    if (call != null && !call.status.isTerminal && await CallPip.enter()) {
      return true;
    }

    // ⚠️ On Home it really does close, on the first press. Android's
    // convention is that back leaves the app from the root, and a
    // "press again to exit" toast is a second thing to learn in exchange
    // for guarding against a press people meant.
    return false;
  }
}

import 'dart:io';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dayflower/features/home/domain/home_moments.dart';
import 'package:dayflower/features/greetings/presentation/monthsary_envelope.dart';
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/features/activities/presentation/screens/activities_screen.dart';
import 'package:dayflower/features/tulip/presentation/screens/flowers_screen.dart';
import 'package:dayflower/features/tulip/presentation/screens/blooms_screen.dart';
import 'package:dayflower/features/booth/presentation/screens/booth_screen.dart';
import 'package:dayflower/features/booth/data/strip_repository.dart';
import 'package:dayflower/features/chapters/data/chapter_repository.dart';
import 'package:dayflower/features/chapters/presentation/screens/chapters_screen.dart';
import 'package:dayflower/features/finance/data/finance_repository.dart';
import 'package:dayflower/features/reminders/data/reminder_repository.dart';
import 'package:dayflower/features/presence/data/presence_repository.dart';
import 'package:dayflower/features/reunion/data/reunion_repository.dart';
import 'package:dayflower/features/activity/presentation/screens/activity_feed_screen.dart';
import 'package:dayflower/features/activity/data/activity_models.dart';
import 'package:dayflower/features/settings/presentation/screens/settings_screen.dart';

import 'package:dayflower/core/models/pair.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/core/theme/app_colors.dart';
import 'package:dayflower/features/activity/data/activity_repository.dart';
import 'package:dayflower/features/calls/data/call_usage.dart';
import 'package:dayflower/features/dates/presentation/screens/events_screen.dart';
import 'package:dayflower/features/gifts/presentation/screens/gifts_screen.dart';
import 'package:dayflower/features/gifts/data/gift_favorites_repository.dart';
import 'package:dayflower/features/dates/data/event_repository.dart';
import 'support/trust_fakes.dart';
import 'package:dayflower/features/heartbeat/data/heartbeat_repository.dart';
import 'package:dayflower/features/home/presentation/screens/home_screen.dart';
import 'package:dayflower/features/home/data/mood_prefs.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/pairing/data/pair_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/us/data/couple_stats.dart';
import 'package:dayflower/features/us/presentation/screens/us_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

// Offline data only: the real screens are rendered without signing in or
// writing to the shared backend. Screenshots are opt-in review artifacts.
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');
var _boundary = GlobalKey();

Future<GoRouter> _pump(WidgetTester tester, String route,
    {double width = 390,
    bool hasStart = true,
    bool filled = false,
    double height = 844,
    double textScale = 1,
    bool unpaired = false,
    Mood? partnerMood,
    Future<bool> Function(Uri)? openLink}) async {
  _boundary = GlobalKey();
  debugNetworkImageHttpClientProvider = () => _PhotoClient();
  addTearDown(() {
    debugNetworkImageHttpClientProvider = null;
  });
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: route, routes: [
    GoRoute(
        path: Routes.activities, builder: (_, __) => const ActivitiesScreen()),
    GoRoute(path: Routes.chat, builder: (_, __) => const FlowersScreen()),
    GoRoute(path: Routes.blooms, builder: (_, __) => const BloomsScreen()),
    GoRoute(path: Routes.booth, builder: (_, __) => const BoothScreen()),
    GoRoute(path: Routes.chapters, builder: (_, __) => const ChaptersScreen()),
    GoRoute(path: Routes.settings, builder: (_, __) => const SettingsScreen()),
    GoRoute(
        path: Routes.notifications,
        builder: (_, __) => const ActivityFeedScreen(notificationsOnly: true)),
    GoRoute(
        path: Routes.activityFeed,
        builder: (_, __) => const ActivityFeedScreen()),
    GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
    GoRoute(path: Routes.us, builder: (_, __) => const UsScreen()),
    GoRoute(
        path: Routes.events,
        builder: (_, state) =>
            EventsScreen(addOnOpen: state.uri.queryParameters['add'] == '1')),
    GoRoute(
        path: Routes.gifts,
        builder: (_, s) => GiftsScreen(
            occasion: s.uri.queryParameters['occasion'], openLink: openLink)),
    for (final route in [Routes.flowers])
      GoRoute(
          path: route,
          builder: (_, __) =>
              const Scaffold(body: Text('Existing destination'))),
  ]);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [
      pairGreetingProvider.overrideWith((ref) async => null),
      homeClockProvider.overrideWith((ref) => Stream.value(_now)),
      heartbeatRepositoryProvider.overrideWithValue(_beats),
      dayPhotoUrlProvider
          .overrideWith((ref, path) async => 'https://preview.invalid/$path'),
      customEventsProvider.overrideWith((ref) => Stream.value(const [])),
      activityFeedProvider.overrideWith((ref) => Stream.value([
            for (final (id, actor, title) in [
              ('mine', 'preview-a', 'Your reminder'),
              ('partner', 'preview-b', 'A photo strip is waiting on you'),
            ])
              Activity(
                  id: id,
                  pairId: 'preview',
                  actorId: actor,
                  kind: ActivityKind.stripWaiting,
                  title: title,
                  emoji: '📸',
                  subjectId: null,
                  meta: const {},
                  createdAt: DateTime.now()),
          ])),
      monthlyGoalsProvider.overrideWith((ref) => Stream.value([])),
      monthlyChaptersProvider.overrideWith((ref) => Stream.value([])),
      chapterMomentsProvider.overrideWith((ref) => Stream.value([])),
      remindersProvider.overrideWith((ref) => Stream.value([])),
      financeAccountsProvider.overrideWith((ref) => Stream.value([])),
      reunionProvider.overrideWith((ref) => Stream.value(null)),
      flowerMessagesProvider.overrideWith((ref) => Stream.value([])),
      openStripsProvider.overrideWith((ref) => Stream.value([])),
      partnerLastActiveProvider.overrideWith((ref) async => null),
      partnerProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      giftFavoritesRepositoryProvider.overrideWithValue(MemoryFavorites()),
      eventRepositoryProvider.overrideWithValue(MemoryEvents()),
      currentUserIdProvider.overrideWithValue('preview-a'),
      currentPairProvider.overrideWith((ref) async => Pair(
            id: 'preview',
            userA: 'preview-a',
            userB: unpaired ? null : 'preview-b',
            inviteCode: 'PREVIEW',
            togetherSince: hasStart ? DateTime(2022, 4, 16) : null,
          )),
      userProfileProvider.overrideWith((ref) async => const UserProfile(
          id: 'preview-a', displayName: 'Hubby', timezone: 'Asia/Dubai')),
      partnerProfileProvider.overrideWith((ref) async => const UserProfile(
          id: 'preview-b', displayName: 'Wifey', timezone: 'Asia/Manila')),
      unreadMessageCountProvider.overrideWithValue(0),
      coupleStatsProvider.overrideWith((ref) async =>
          const CoupleStats(hearts: 128, flowers: 42, photos: 36, streak: 7)),
      callUsageProvider.overrideWith((ref) async => const CallUsage()),
      partnerMoodProvider.overrideWithValue(filled ? Mood.loved : partnerMood),
      todayHeartbeatCountsProvider.overrideWithValue(
          filled ? (mine: 3, partner: 2) : (mine: 0, partner: 0)),
      myDayPhotoProvider.overrideWithValue(filled ? _mine : null),
      myDayPhotosProvider.overrideWithValue(filled ? [_mine] : []),
      partnerDayPhotoProvider.overrideWithValue(filled ? _theirs : null),
      recentActivitiesProvider.overrideWithValue(const AsyncData([])),
      unseenActivityCountProvider.overrideWithValue(0),
      activityLastSeenProvider.overrideWith((ref) async => null),
    ],
    child: RepaintBoundary(
        key: _boundary,
        child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.current,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
            routerConfig: router)),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return router;
}

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

final _now = DateTime(2026, 9, 15, 15);
final _mine = FlowerMessage(
    id: 'mine',
    pairId: 'preview',
    senderId: 'preview-a',
    imagePath: 'me.png',
    sentAt: _now,
    toWidget: true);
final _theirs = FlowerMessage(
    id: 'theirs',
    pairId: 'preview',
    senderId: 'preview-b',
    imagePath: 'partner.png',
    sentAt: _now,
    toWidget: true);
final _beats = _HeartbeatFake();

class _HeartbeatFake extends HeartbeatRepository {
  _HeartbeatFake()
      : super(SupabaseClient('https://example.invalid', 'offline'));
  int sends = 0;
  bool fail = false;
  @override
  Future<void> send({required String pairId, required String senderId}) async {
    if (fail) throw StateError('offline');
    sends++;
  }
}

class _PhotoClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _PhotoRequest(url);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhotoRequest implements HttpClientRequest {
  _PhotoRequest(this.url);
  final Uri url;
  @override
  Future<HttpClientResponse> close() async => _PhotoResponse(
      File('test/fixtures/home/${url.pathSegments.last}').readAsBytesSync());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhotoResponse extends Stream<List<int>> implements HttpClientResponse {
  _PhotoResponse(this.bytes);
  final List<int> bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .35);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    tz.initializeTimeZones();
    for (final (family, asset) in [
      ('TikTokSans', 'assets/fonts/tiktok/TikTokSans.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      (
        'packages/cupertino_icons/CupertinoIcons',
        'packages/cupertino_icons/assets/CupertinoIcons.ttf'
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
    final emoji = File('C:/Windows/Fonts/seguiemj.ttf');
    if (_capture && await emoji.exists()) {
      await (FontLoader('TikTokSans')
            ..addFont(emoji.readAsBytes().then((b) => ByteData.sublistView(b))))
          .load();
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _beats.sends = 0;
    _beats.fail = false;
  });
  tearDown(() {
    debugNetworkImageHttpClientProvider = null;
  });

  _homeTest(
      'Home fits phones, wider screens and large text with consistent type',
      (tester) async {
    for (final (width, scale, filled) in [
      (390.0, 1.0, false),
      (390.0, 1.0, true),
      (320.0, 1.0, false),
      (320.0, 1.0, true),
      (320.0, 2.0, false),
      (390.0, 2.0, false),
      (740.0, 1.0, false),
      (900.0, 1.0, false),
      (900.0, 1.0, true),
      (900.0, 2.0, true)
    ]) {
      await _pump(tester, Routes.home,
          width: width, textScale: scale, filled: filled, hasStart: filled);
      await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('my-day-side-by-side')), findsOneWidget);
      expect(
          (tester.widget(find.byKey(const ValueKey('greeting-title'))) as Text)
              .style
              ?.fontSize,
          width - 40 < 320 ? 26 : 30);
      expect(tester.widget(find.byKey(const ValueKey('home-my-day'))),
          isA<Padding>());
      expect(find.byType(MonthsaryEnvelope), findsNothing);
      expect(find.text('HOW ARE YOU FEELING?'), findsOneWidget);
      final greetingRect =
          tester.getRect(find.byKey(const ValueKey('home-greeting')));
      final photoRect =
          tester.getRect(find.byKey(const ValueKey('home-photo-deck')));
      expect(greetingRect.right, lessThan(photoRect.left));
      expect(greetingRect.center.dy, closeTo(photoRect.center.dy, 1));
      expect(photoRect.left - greetingRect.right, lessThanOrEqualTo(16));
      expect(find.byKey(const ValueKey('my-day-photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('partner-day-photo')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _screenshot(tester,
          'home-${width.toInt()}-${scale.toInt()}-${filled ? 'filled' : 'empty'}-top');
      for (final section in [
        'home-heartbeat',
        'home-upcoming',
        'home-widget-gallery'
      ]) {
        await _reveal(tester, find.byKey(ValueKey(section)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (width == 390 && scale == 1) {
          await _screenshot(
              tester, 'home-${filled ? 'filled' : 'empty'}-$section');
        }
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  _homeTest('Review full Home and its dark appearance', (tester) async {
    await _pump(tester, Routes.home, filled: true, height: 2200);
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();
    await _screenshot(tester, 'home-full-filled');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    AppColors.use(AppMode.dark);
    try {
      await _pump(tester, Routes.home, filled: true, height: 2200);
      await tester.pumpAndSettle();
      await _screenshot(tester, 'home-full-dark');
      expect(tester.takeException(), isNull);
    } finally {
      AppColors.use(AppMode.light);
    }
  });

  _homeTest('Empty photo opens capture, Us and notification routes still work',
      (tester) async {
    final router = await _pump(tester, Routes.home, hasStart: false);
    await _reveal(tester, find.text('Share your day'));
    await tester.tap(find.text('Share your day'));
    await tester.pumpAndSettle();
    expect(find.text('Existing destination'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1500));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Us, your couple page'));
    await tester.pumpAndSettle();
    expect(find.byType(UsScreen), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityFeedScreen), findsOneWidget);
  });

  _homeTest(
      'Heartbeat sends once, surfaces failure, and disables before pairing',
      (tester) async {
    await _pump(tester, Routes.home);
    final heart = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Send a heartbeat');
    await _reveal(tester, heart);
    await tester.tap(heart);
    await tester.pumpAndSettle();
    expect(_beats.sends, 1);
    _beats.fail = true;
    await tester.tap(heart);
    await tester.pumpAndSettle();
    expect(
        find.text('Could not send the heartbeat. Try again.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, Routes.home, unpaired: true);
    expect((tester.widget(heart) as Semantics).properties.enabled, false);
  });

  _homeTest(
      'Stack switches ownership; widget previews do not send and have individual setup',
      (tester) async {
    await _pump(tester, Routes.home, filled: true);
    await _reveal(tester, find.byKey(const ValueKey('my-day-photo')));
    await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('partner-day-photo'))),
        const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('my-day-photo'))).dx,
        lessThan(tester
            .getTopLeft(find.byKey(const ValueKey('partner-day-photo')))
            .dx));
    await _reveal(tester, find.byKey(const ValueKey('home-widget-gallery')));
    await tester.pumpAndSettle();
    for (final title in ['My Day', 'Heartbeat', 'Reunion']) {
      final setup = find.byWidgetPredicate((w) =>
          w is Semantics && w.properties.label == 'Set up $title widget');
      await _reveal(tester, setup);
      await tester.tap(setup);
      await tester.pumpAndSettle();
      expect(find.text('Set up $title'), findsOneWidget);
      await tester.tap(find.byTooltip('Close widget setup'));
      await tester.pumpAndSettle();
    }
    expect(_beats.sends, 0);
  });

  _homeTest(
      'Events rotate every five seconds, swipe manually and open Events without a popup',
      (tester) async {
    final router = await _pump(tester, Routes.home, filled: true);
    await _reveal(tester, find.byKey(const ValueKey('home-upcoming')));
    await tester.pumpAndSettle();
    expect(find.text('Our monthsary'), findsOneWidget);
    expect(find.byTooltip('Next event'), findsNothing);
    expect(find.byTooltip('Previous event'), findsNothing);
    expect(find.text('1 of 2'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Our anniversary'), findsOneWidget);
    await tester.drag(
        find.byKey(const ValueKey('home-upcoming')), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Our monthsary'), findsOneWidget);
    await tester.tap(find.text('View events ›'));
    await tester.pumpAndSettle();
    expect(find.byType(EventsScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Our monthsary'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Our monthsary'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, Routes.home, hasStart: false);
    await _reveal(tester, find.text('Add a date ›'));
    await tester.tap(find.text('Add a date ›'));
    await tester.pumpAndSettle();
    expect(find.byType(EventsScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Add event'), findsOneWidget);
  });
}

void _homeTest(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
      debugNetworkImageHttpClientProvider = null;
    }
  });
}

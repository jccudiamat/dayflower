import 'dart:io';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dayflower/features/home/domain/home_moments.dart';
import 'package:dayflower/features/greetings/presentation/monthsary_envelope.dart';
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/widgets/app_bottom_nav.dart';
import 'package:dayflower/core/widgets/section_scroll_scope.dart';
import 'package:dayflower/features/tulip/presentation/widgets/flower_catalog_panel.dart';
import 'package:dayflower/features/memories/presentation/widgets/memory_tile.dart';
import 'package:dayflower/features/dayflower/presentation/dayflower_screen.dart';
import 'package:dayflower/features/travel/data/map_pin_repository.dart';
import 'package:dayflower/features/memories/presentation/screens/memories_screen.dart';
import 'package:dayflower/features/tulip/data/reaction_repository.dart';
import 'package:dayflower/features/booth/presentation/screens/booth_archive_screen.dart';
import 'package:dayflower/features/tulip/presentation/widgets/media_viewer.dart';
import 'package:dayflower/features/booth/presentation/screens/booth_studio_screen.dart';
import 'package:dayflower/features/booth/domain/booth_design.dart';
import 'package:dayflower/features/booth/domain/booth_renderer.dart';
import 'package:dayflower/features/finance/presentation/screens/finance_screen.dart';
import 'package:dayflower/features/reminders/presentation/screens/reminders_screen.dart';
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
import 'package:dayflower/core/theme/design_tokens.dart';
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

/// A photo from this same date, one year back — the only shape of thing the
/// throwback will show, so the only shape worth seeding.
final _lastYear = FlowerMessage(
  id: 'throwback',
  pairId: 'preview',
  senderId: 'preview-b',
  imagePath: 'preview/last-year.jpg',
  note: 'Still one of my favourites.',
  sentAt: DateTime(_now.year - 1, _now.month, _now.day, 9, 30),
);

Future<GoRouter> _pump(WidgetTester tester, String route,
    {double width = 390,
    bool throwback = false,
    bool hasStart = true,
    bool productionRoutes = false,
    bool filled = false,
    bool boothFilled = false,
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
  final router = GoRouter(initialLocation: route, routes: productionRoutes ? appFeatureRoutes() : [
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
      flowerRepositoryProvider.overrideWithValue(_PreviewFlowers()),
      reactionsProvider.overrideWith((ref) => Stream.value({})),
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
      // ⚠️ Memories waits on every one of its sources, so an un-stubbed
      // provider leaves the whole screen on a spinner rather than failing
      // loudly. Map pins were the one nothing else needed.
      mapPinsProvider.overrideWith((ref) => Stream.value(const [])),
      remindersProvider.overrideWith((ref) => Stream.value([])),
      financeRatesProvider.overrideWith((ref) => Stream.value(FxTable.empty)),
      financeMainCurrencyProvider.overrideWith((ref) => Stream.value('PHP')),
      financeAccountsProvider.overrideWith((ref) => Stream.value([])),
      financeEntriesProvider.overrideWith((ref) => Stream.value([])),
      financeBudgetsProvider.overrideWith((ref) => Stream.value([])),
      financeRecurringProvider.overrideWith((ref) => Stream.value([])),
      financeHoldingsProvider.overrideWith((ref) => Stream.value([])),
      financeGoalsProvider.overrideWith((ref) => Stream.value([])),
      reunionProvider.overrideWith((ref) => Stream.value(null)),
      flowerMessagesProvider.overrideWith((ref) => Stream.value(
        throwback ? [_lastYear] :
        productionRoutes && filled ? [_mine, _theirs, if (boothFilled) ..._boothPhotos, FlowerMessage(
          id: 'flower-preview', pairId: 'preview', senderId: 'preview-b',
          flowerType: 'classic_tulip', note: 'Thinking of you', sentAt: _now)] : [])),
      openStripsProvider.overrideWith((ref) => Stream.value(boothFilled ? _pendingBooth : [])),
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
final _boothImages = <String, Uint8List>{};
final _boothPhotos = [
  for (final (i, path, design) in [
    (0, 'booth-strip.jpg', const BoothDesign(look: BoothLook.vintage)),
    (1, 'booth-grid.jpg', const BoothDesign(look: BoothLook.rose, layout: BoothLayout.grid)),
    (2, 'booth-photo.jpg', const BoothDesign(look: BoothLook.classic, layout: BoothLayout.portrait)),
  ]) FlowerMessage(id: 'booth-$i', pairId: 'preview', senderId: 'preview-a',
      imagePath: path, note: design.title, sentAt: _now.subtract(Duration(days: i))),
];
final _pendingBooth = [
  PhotoStrip(id: 'mine-pending', pairId: 'preview', template: 'studio_rose_strip',
      aUser: 'preview-a', aPath: 'booth-strip.jpg', createdAt: _now),
  PhotoStrip(id: 'partner-pending', pairId: 'preview', template: 'studio_vintage_strip',
      aUser: 'preview-b', aPath: 'booth-strip.jpg', createdAt: _now.subtract(const Duration(days: 1))),
];
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
      _boothImages[url.pathSegments.last] ?? File('test/fixtures/home/${url.pathSegments.last}').readAsBytesSync());
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
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 280, scrollable: find.byType(Scrollable).first);
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: .35);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final mine = File('test/fixtures/home/me.png').readAsBytesSync();
    final theirs = File('test/fixtures/home/partner.png').readAsBytesSync();
    for (final (name, design) in [
      ('booth-strip.jpg', const BoothDesign(look: BoothLook.vintage)),
      ('booth-grid.jpg', const BoothDesign(look: BoothLook.rose, layout: BoothLayout.grid)),
      ('booth-photo.jpg', const BoothDesign(look: BoothLook.classic, layout: BoothLayout.portrait)),
    ]) {
      _boothImages[name] = await BoothRenderer.render(design,
          List.generate(design.layout.shots, (i) => i.isEven ? mine : theirs));
    }

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


  Finder tab(String label) => find.byWidgetPredicate((w) =>
      w is Semantics && w.properties.button == true && w.properties.label == label);

  _homeTest('Reorganized roots render at phone widths and large text', (tester) async {
    for (final (width, scale) in [(390.0, 1.0), (320.0, 1.0), (320.0, 2.0)]) {
      for (final (route, name) in [
        (Routes.chat, 'chat'), (Routes.dayflower, 'dayflower'),
        (Routes.memories, 'memories'), (Routes.together, 'together')]) {
        await _pump(tester, route, width: width, textScale: scale,
            productionRoutes: true, filled: true);
        await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 400)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$name $width $scale');
        if (route == Routes.chat) {
          expect(find.byType(AppBottomNav), findsNothing);
        } else {
          expect(find.byType(AppBottomNav), findsOneWidget);
          for (final label in ['Home', 'Chat', 'Dayflower', 'Memories', 'Together']) {
            expect(tab(label), findsOneWidget);
          }
        }
        if (width == 390 && scale == 1) await _screenshot(tester, 'sections-$name');
        await tester.pumpWidget(const SizedBox());
      }
    }
  });


  _homeTest('Reselect scrolls each section to the top without replacing it', (tester) async {
    for (final (route, label) in [
      (Routes.home, 'Home'), (Routes.dayflower, 'Dayflower'),
      (Routes.memories, 'Memories'), (Routes.together, 'Together')]) {
      await _pump(tester, route, height: 500, productionRoutes: true, filled: true);
      await tester.pumpAndSettle();
      final scope = find.byType(SectionScrollScope);
      final container = ProviderScope.containerOf(tester.element(scope));
      final controller = container.read(sectionScrollControllerProvider(route));
      expect(controller.hasClients, isTrue, reason: label);
      expect(controller.position.maxScrollExtent, greaterThan(0), reason: label);
      await tester.drag(find.descendant(of: scope, matching: find.byType(Scrollable)).first,
          const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0), reason: label);
      await tester.tap(tab(label));
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(0, 0.1), reason: label);
      expect(container.read(sectionScrollControllerProvider(route)), same(controller));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  // ⚠️ Runs against Dayflower, not Memories. Memories keeps its one
  // detail link ('Prints') in the scaffold header, so there is no way to
  // be scrolled down and still able to tap it, which is the whole shape
  // this test needs. Dayflower's 'All months' sits in the page body.
  _homeTest('Parent tab closes a detail and returns to the top', (tester) async {
    await _pump(tester, Routes.dayflower, height: 500, productionRoutes: true);
    await _reveal(tester, find.text('All months'));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(DayflowerScreen)));
    expect(
        container.read(sectionScrollControllerProvider(Routes.dayflower)).offset,
        greaterThan(0));
    await tester.tap(find.text('All months'));
    await tester.pumpAndSettle();
    expect(find.byType(ChaptersScreen), findsOneWidget);
    await tester.tap(tab('Dayflower'));
    await tester.pumpAndSettle();
    expect(find.byType(DayflowerScreen), findsOneWidget);
    expect(find.byType(ChaptersScreen), findsNothing);
    expect(
        container.read(sectionScrollControllerProvider(Routes.dayflower)).offset,
        closeTo(0, 0.1));
    expect(tester.takeException(), isNull);
  });

  _homeTest('Five tabs and legacy roots reach the correct sections', (tester) async {
    final router = await _pump(tester, Routes.home, productionRoutes: true);
    for (final (label, path) in [
      ('Chat', Routes.chat), ('Dayflower', Routes.dayflower),
      ('Memories', Routes.memories), ('Together', Routes.together), ('Home', Routes.home)]) {
      await tester.tap(tab(label));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      if (label == 'Chat') {
        expect(find.byType(AppBottomNav), findsNothing);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
      } else {
        expect((tester.widget(tab(label)) as Semantics).properties.selected, isTrue);
      }
      expect(tester.takeException(), isNull);
    }
    router.go('${Routes.activities}?from=old-link');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.together);
    expect(router.routeInformationProvider.value.uri.queryParameters['from'], 'old-link');
    // ⚠️ Blooms no longer bounces to the tab root: it is the garden
    // itself again. What still has to hold is that it counts as Dayflower,
    // so the tab under it stays lit.
    router.go(Routes.blooms);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.blooms);
    expect((tester.widget(tab('Dayflower')) as Semantics).properties.selected,
        isTrue);
  });

  _homeTest('Memories and Dayflower render at phone widths and large text',
      (tester) async {
    for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
      await _pump(tester, Routes.memories,
          width: width, textScale: scale, height: 844,
          productionRoutes: true, filled: true, boothFilled: true);
      await tester.pumpAndSettle();
      // The filter row and at least one dated entry: the two things the
      // timeline is made of.
      expect(find.text('All'), findsOneWidget);
      expect(find.byType(MemoryTile), findsWidgets);
      await _screenshot(tester, 'memories-new-${width.toInt()}');
      expect(tester.takeException(), isNull, reason: 'memories $width/$scale');
      await tester.pumpWidget(const SizedBox());

      await _pump(tester, Routes.dayflower,
          width: width, textScale: scale, height: 844,
          productionRoutes: true, filled: true, boothFilled: true);
      await tester.pumpAndSettle();
      await _screenshot(tester, 'dayflower-new-${width.toInt()}');
      expect(tester.takeException(), isNull, reason: 'dayflower $width/$scale');
      await tester.pumpWidget(const SizedBox());
    }
    await _pump(tester, Routes.booth, productionRoutes: true);
    await tester.pumpAndSettle();
    await _screenshot(tester, 'booth-entrance');
  });

  _homeTest('Memories archives separate pending and completed prints, including empty states', (tester) async {
    for (final filled in [false, true]) {
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, Routes.boothPending, productionRoutes: true,
          filled: filled, boothFilled: filled, width: 320, textScale: 2);
      await tester.pumpAndSettle();
      expect(find.text('Saved strips & photos'), findsNothing);
      if (!filled) expect(find.text('No strips waiting for a photo.'), findsOneWidget);
      await _screenshot(tester, filled ? 'pending-detail-filled' : 'pending-detail-empty');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await _pump(tester, Routes.boothCollection, productionRoutes: true,
          filled: filled, boothFilled: filled);
      await tester.pumpAndSettle();
      expect(find.text('Waiting strips'), findsNothing);
      if (!filled) {
        expect(find.text('Your first strip will appear here once it is shared.'), findsOneWidget);
        await _screenshot(tester, 'collection-detail-empty');
      } else {
        await _screenshot(tester, 'collection-detail-filled');
        final title = find.text(_boothPhotos.first.note!);
        await _reveal(tester, title);
        // The title, not the card's centre: with no photo in a test the
        // centre holds the strip's Retry button, which takes that tap.
        await tester.tap(title);
        await tester.pumpAndSettle();
        final viewer = tester.widget<MediaViewer>(find.byType(MediaViewer));
        expect(viewer.imagePath, _boothPhotos.first.imagePath);
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, Routes.memories, productionRoutes: true, height: 1780);
    await tester.pumpAndSettle();
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/booth_entrance.jpg'),
        tester.element(find.byType(MemoriesScreen))));
    await tester.pumpAndSettle();
    await _screenshot(tester, 'memories-booth-empty');
  });

  // 🔴 Dayflower used to lead with a 'saved you a spot' card. It was
  // removed: the booth's own front page already announces a waiting strip
  // and carries 'Saved & waiting strips', so the card was a second voice
  // saying the same thing above the four tools people come here for.
  // What still has to hold is that the waiting strip is reachable and
  // joins the right one.
  _homeTest('The booth surfaces a waiting strip and joins that exact one',
      (tester) async {
    await _pump(tester, Routes.boothPending,
        productionRoutes: true, filled: true, boothFilled: true);
    await tester.pumpAndSettle();
    expect(find.byType(BoothArchiveScreen), findsOneWidget);
    await _reveal(tester, find.text('Join this strip'));
    await tester.tap(find.text('Join this strip'));
    await tester.pumpAndSettle();
    // A studio template is finished in the studio, so joining opens it on
    // that exact strip rather than the archive's own camera.
    final studio =
        tester.widget<BoothStudioScreen>(find.byType(BoothStudioScreen));
    expect(studio.joining?.id, 'partner-pending');
    expect(tester.takeException(), isNull);
  });

  _homeTest('Each hub opens the tools it owns and returns to itself',
      (tester) async {
    // 🔴 The four links this used to walk all lived on Memories.
    // Making things moved to Dayflower and only the kept prints stayed
    // behind, so the walk is now per hub, which is the thing worth
    // asserting.
    for (final (hub, hubType, label, path, type) in [
      (Routes.memories, MemoriesScreen, 'Prints', Routes.boothCollection,
          BoothArchiveScreen),
      (Routes.dayflower, DayflowerScreen, 'All months', Routes.chapters,
          ChaptersScreen),
      (Routes.dayflower, DayflowerScreen, 'Photo Booth', Routes.booth,
          BoothScreen),
    ]) {
      final router = await _pump(tester, hub, productionRoutes: true);
      await _reveal(tester, find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(GoRouterState.of(tester.element(find.byType(type))).uri.path, path,
          reason: label);
      expect(find.byType(type), findsOneWidget, reason: label);
      if (type == BoothScreen) {
        expect(find.byType(AppBottomNav), findsNothing, reason: label);
      } else {
        final owner = hub == Routes.memories ? 'Memories' : 'Dayflower';
        expect((tester.widget(tab(owner)) as Semantics).properties.selected,
            isTrue,
            reason: label);
      }
      expect(tester.takeException(), isNull, reason: label);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(hubType), findsOneWidget, reason: label);
      await tester.pumpWidget(const SizedBox());
    }
  });

  _homeTest('Together opens persisted tools and Dayflower opens the flower picker',
      (tester) async {
    final router = await _pump(tester, Routes.together, productionRoutes: true);
    for (final (label, path, type) in [
      ('Events', Routes.events, EventsScreen),
      ('Reminders', Routes.reminders, RemindersScreen),
      // Finances has no row of its own since the bento redesign; the
      // savings card is the way in.
      ('Our Savings', Routes.finance, FinanceScreen),
      ('Gifts', Routes.gifts, GiftsScreen)]) {
      await _reveal(tester, find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(GoRouterState.of(tester.element(find.byType(type))).uri.path, path);
      expect(find.byType(type), findsOneWidget);
      expect((tester.widget(tab('Together')) as Semantics).properties.selected,
          isTrue);
      expect(tester.takeException(), isNull);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ActivitiesScreen), findsOneWidget);
    }
    await tester.tap(tab('Dayflower'));
    await tester.pumpAndSettle();
    // ⚠️ Two things say 'Send a flower' on an empty garden: the tile up
    // in Today and the empty state's own button. The tile is the one being
    // tested, and it is the first in the tree.
    await tester.tap(find.text('Send a flower').first);
    await tester.pumpAndSettle();
    // The picker is a sheet over Dayflower now, not a push to Flowers, so
    // the tab stays lit underneath it.
    expect(find.byType(FlowerCatalogPanel), findsOneWidget);
    expect(find.byType(DayflowerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(FlowerCatalogPanel))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(FlowerCatalogPanel), findsNothing);
    expect(find.byType(DayflowerScreen), findsOneWidget);
  });

  _homeTest(
      'Home fits phones, wider screens and large text with consistent type',
      (tester) async {
    final emptyDeckSizes = <String, Size>{};
    for (final (width, scale, filled) in [
      (390.0, 1.0, false),
      (390.0, 1.0, true),
      (320.0, 1.0, false),
      (320.0, 1.0, true),
      (320.0, 2.0, false),
      (320.0, 2.0, true),
      (390.0, 2.0, false),
      (390.0, 2.0, true),
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
      expect(find.text('Update yours'), findsNothing);
      expect(find.text('Share yours'), findsNothing);
      expect(find.textContaining('Swipe to see'), findsNothing);
      expect(find.textContaining('photo will appear here too'), findsNothing);
      expect(find.text('Add your photo to the stack'), findsNothing);
      expect(
          find.byWidgetPredicate((widget) =>
              widget is Semantics &&
              (widget.properties.label == 'Show your day' ||
                  widget.properties.label == 'Show partner’s day')),
          findsNothing);
      expect(find.text('HOW ARE YOU FEELING?'), findsOneWidget);
      final greetingRect =
          tester.getRect(find.byKey(const ValueKey('home-greeting')));
      final photoRect =
          tester.getRect(find.byKey(const ValueKey('home-photo-deck')));
      final sizeKey = '$width-$scale';
      if (!filled) {
        emptyDeckSizes[sizeKey] = photoRect.size;
      } else if (emptyDeckSizes.containsKey(sizeKey)) {
        expect(photoRect.size, emptyDeckSizes[sizeKey]);
      }
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

  _homeTest('Every section sits the same distance from the next',
      (tester) async {
    // 🔴 Measure the ink, not the boxes. The greeting used to carry 16pt of
    // its own bottom padding inside its box, so it read 40 from the card
    // below while every card read 24 — and the boxes all agreed with each
    // other the whole time. A first version of this test compared box edges,
    // passed on the broken layout, and would have locked the bug in.
    await _pump(tester, Routes.home, filled: true, height: 2200);
    await tester.pumpAndSettle();

    double bottomOf(List<String> keys) {
      var lowest = double.negativeInfinity;
      for (final key in keys) {
        final finder = find.byKey(ValueKey(key));
        expect(finder, findsWidgets, reason: '$key is missing from Home');
        final bottom = tester.getRect(finder.first).bottom;
        if (bottom > lowest) lowest = bottom;
      }
      return lowest;
    }

    double topOf(String key) {
      final finder = find.byKey(ValueKey(key));
      expect(finder, findsOneWidget, reason: '$key is missing from Home');
      return tester.getRect(finder.first).top;
    }

    // The header's visible edge is whichever of the greeting or the photo
    // deck hangs lowest, not the padded wrapper around them.
    final sections = <(String, double, double)>[
      ('greeting', topOf('home-greeting'), bottomOf(['home-greeting', 'home-photo-deck'])),
      ('map', topOf('home-map'), bottomOf(['home-map'])),
      ('heartbeat', topOf('home-heartbeat'), bottomOf(['home-heartbeat'])),
      ('upcoming', topOf('home-upcoming'), bottomOf(['home-upcoming'])),
      ('widgets', topOf('home-widget-gallery'), bottomOf(['home-widget-gallery'])),
    ];

    for (var i = 1; i < sections.length; i++) {
      final gap = sections[i].$2 - sections[i - 1].$3;
      expect(gap, closeTo(AppSpace.md, 1.0),
          reason: '${sections[i - 1].$1} -> ${sections[i].$1} is '
              '${gap.toStringAsFixed(1)}, not AppSpace.md');
    }
  });

  _homeTest('A photo from this date last year comes back', (tester) async {
    await _pump(tester, Routes.home, filled: true, throwback: true,
        height: 2200);
    await tester.pumpAndSettle();

    expect(find.text('A year ago today'), findsOneWidget);
    expect(find.text('This moment'), findsOneWidget);
    expect(find.text('Still one of my favourites.'), findsOneWidget);
    await _screenshot(tester, 'home-throwback');
  });

  _homeTest('A day with nothing to look back on says nothing', (tester) async {
    // 🔴 The section must vanish rather than caption an unrelated photo with
    // "a year ago today", and vanishing must not leave a hole: the gap either
    // side of it collapsed to 48pt the first time, because the page and the
    // section each contributed one.
    await _pump(tester, Routes.home, filled: true, height: 2200);
    await tester.pumpAndSettle();
    expect(find.textContaining('ago today'), findsNothing);
  });

  _homeTest('Choosing a mood names it, and not before', (tester) async {
    await _pump(tester, Routes.home, filled: true, height: 2200);
    await tester.pumpAndSettle();

    // Nothing is named until something is chosen. The row used to read
    // "Tap one" here, which is an instruction sitting where an answer goes.
    expect(find.text('Calm'), findsNothing);
    expect(find.text('Tap one'), findsNothing);

    final face = find.text('😌');
    expect(face, findsOneWidget);
    await tester.tap(face);
    await tester.pumpAndSettle();

    final label = find.text('Calm');
    expect(label, findsOneWidget);

    // It belongs in the header row, level with the question it answers,
    // rather than anywhere below the faces.
    final question = tester.getRect(find.text('HOW ARE YOU FEELING?'));
    final labelBox = tester.getRect(label);
    expect(labelBox.center.dy, closeTo(question.center.dy, 4),
        reason: 'the mood name should sit on the question row');
    expect(labelBox.left, greaterThanOrEqualTo(question.right),
        reason: 'it belongs at the end of that row, after the question');
    expect(labelBox.top, lessThan(tester.getRect(face).top),
        reason: 'and above the faces, not under them');

    await _screenshot(tester, 'home-mood-chosen');
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

class _PreviewFlowers extends FlowerRepository {
  _PreviewFlowers() : super(SupabaseClient('https://example.invalid', 'offline',
      authOptions: const AuthClientOptions(autoRefreshToken: false)));
  @override
  Future<String> signedPhotoUrl(String path, {Duration ttl = const Duration(hours: 1)}) async =>
      'https://preview.invalid/$path';
}

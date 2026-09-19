import 'package:dayflower/features/tulip/domain/flower_catalog.dart';
import 'package:dayflower/features/tulip/presentation/screens/blooms_screen.dart';
import 'package:dayflower/features/dayflower/presentation/dayflower_screen.dart';
import 'package:dayflower/features/travel/data/map_pin_repository.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/widgets/app_bottom_nav.dart';
import 'package:dayflower/features/activities/presentation/screens/activities_screen.dart';
import 'package:dayflower/features/memories/presentation/screens/memories_screen.dart';
import 'package:dayflower/features/tulip/presentation/screens/flowers_screen.dart';
import 'package:dayflower/features/tulip/presentation/screens/chat_settings_screen.dart';
import 'package:dayflower/features/booth/presentation/screens/booth_screen.dart';
import 'package:dayflower/features/booth/data/strip_repository.dart';
import 'package:dayflower/features/chapters/data/chapter_repository.dart';
import 'package:dayflower/features/chapters/presentation/screens/chapters_screen.dart';
import 'package:dayflower/features/chapters/presentation/screens/chapter_detail_screen.dart';
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
    double textScale = 1,
    List<FlowerMessage> messages = const [],
    Mood? partnerMood,
    Future<bool> Function(Uri)? openLink}) async {
  _boundary = GlobalKey();
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: route, routes: [
    for (final entry in legacyAppRoutes.entries)
      GoRoute(
          path: entry.key,
          redirect: (_, s) => s.uri.replace(path: entry.value).toString()),
    GoRoute(
        path: Routes.together, builder: (_, __) => const ActivitiesScreen()),
    GoRoute(
        path: Routes.dayflower, builder: (_, __) => const DayflowerScreen()),
    GoRoute(path: Routes.memories, builder: (_, __) => const MemoriesScreen()),
    GoRoute(path: Routes.chat, builder: (_, __) => const FlowersScreen()),
    GoRoute(
        path: Routes.photos, builder: (_, __) => const SharedPhotosScreen()),
    GoRoute(path: Routes.blooms, builder: (_, __) => const BloomsScreen()),
    GoRoute(path: Routes.booth, builder: (_, __) => const BoothScreen()),
    GoRoute(path: Routes.chapters, builder: (_, __) => const ChaptersScreen()),
    GoRoute(
        path: Routes.goals,
        builder: (_, __) => ChapterDetailScreen(
            year: DateTime.now().year,
            month: DateTime.now().month,
            goalsOnly: true)),
    GoRoute(
        path: Routes.widgetSettings,
        builder: (_, __) => const WidgetSettingsScreen()),
    GoRoute(
        path: Routes.notifications,
        builder: (_, __) => const ActivityFeedScreen(notificationsOnly: true)),
    GoRoute(
        path: Routes.activityFeed,
        builder: (_, __) => const ActivityFeedScreen()),
    GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
    GoRoute(path: Routes.us, builder: (_, __) => const UsScreen()),
    GoRoute(path: Routes.events, builder: (_, __) => const EventsScreen()),
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
      activityRepositoryProvider
          .overrideWithValue(_PreviewActivityRepository()),
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
      mapPinsProvider.overrideWith((ref) => Stream.value([])),
      monthlyGoalsProvider.overrideWith((ref) => Stream.value([])),
      monthlyChaptersProvider.overrideWith((ref) => Stream.value([])),
      chapterMomentsProvider.overrideWith((ref) => Stream.value([])),
      remindersProvider.overrideWith((ref) => Stream.value([])),
      financeAccountsProvider.overrideWith((ref) => Stream.value([])),
      reunionProvider.overrideWith((ref) => Stream.value(null)),
      flowerMessagesProvider.overrideWith((ref) => Stream.value(messages)),
      openStripsProvider.overrideWith((ref) => Stream.value([])),
      partnerLastActiveProvider.overrideWith((ref) async => null),
      partnerProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      giftFavoritesRepositoryProvider.overrideWithValue(MemoryFavorites()),
      eventRepositoryProvider.overrideWithValue(MemoryEvents()),
      currentUserIdProvider.overrideWithValue('preview-a'),
      currentPairProvider.overrideWith((ref) async => Pair(
            id: 'preview',
            userA: 'preview-a',
            userB: 'preview-b',
            inviteCode: 'PREVIEW',
            togetherSince: hasStart ? DateTime(2023, 9, 19) : null,
          )),
      userProfileProvider.overrideWith((ref) async => const UserProfile(
          id: 'preview-a', displayName: 'Alex', timezone: 'Asia/Dubai')),
      partnerProfileProvider.overrideWith((ref) async => const UserProfile(
          id: 'preview-b', displayName: 'Jamie', timezone: 'Asia/Manila')),
      unreadMessageCountProvider.overrideWithValue(0),
      coupleStatsProvider.overrideWith((ref) async =>
          const CoupleStats(hearts: 128, flowers: 42, photos: 36, streak: 7)),
      callUsageProvider.overrideWith((ref) async => const CallUsage()),
      partnerMoodProvider.overrideWithValue(partnerMood),
      todayHeartbeatCountsProvider.overrideWithValue((mine: 0, partner: 0)),
      myDayPhotoProvider.overrideWithValue(null),
      partnerDayPhotoProvider.overrideWithValue(null),
      recentActivitiesProvider.overrideWithValue(const AsyncData([])),
      unseenActivityCountProvider.overrideWithValue(0),
      activityLastSeenProvider.overrideWith((ref) async => null),
    ],
    child: RepaintBoundary(
        key: _boundary,
        child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
            theme: AppTheme.current,
            routerConfig: router)),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return router;
}

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  if (find.byType(DayflowerScreen).evaluate().isNotEmpty) {
    await tester.runAsync(() => precacheImage(
        AssetImage(FlowerCatalog.byId('stem_tulip').asset),
        tester.element(find.byType(DayflowerScreen))));
    await tester.pumpAndSettle();
  }
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    tz.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
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

  testWidgets(
      'Together gift card opens contextual Gifts and back returns Together',
      (tester) async {
    final router = await _pump(tester, Routes.together);
    await tester.ensureVisible(find.text('Gifts'));
    await tester.pumpAndSettle();
    await _screenshot(tester, 'navigation-together');
    await tester.tap(find.text('Gifts'));
    await tester.pumpAndSettle();
    final giftState =
        GoRouterState.of(tester.element(find.byType(GiftsScreen)));
    expect(giftState.uri.path, Routes.gifts);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ActivitiesScreen), findsOneWidget);
  });

  testWidgets('Together opens intact Events; back returns Together',
      (tester) async {
    final router = await _pump(tester, Routes.together);
    await _screenshot(tester, 'navigation-together-top');
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.byType(EventsScreen), findsOneWidget);
    await _screenshot(tester, 'events');
    expect(find.text('Add event'), findsOneWidget);
    await tester.ensureVisible(find.text('Add event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add event'));
    await tester.pumpAndSettle();
    expect(find.text('Add event'), findsNWidgets(2));
    router.pop();
    await tester.pump(const Duration(milliseconds: 400));
    router.pop();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ActivitiesScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Gifts belongs to Together and fits narrow phones',
      (tester) async {
    for (final width in [390.0, 320.0]) {
      await _pump(tester, Routes.gifts, width: width);
      expect(find.text('Gifts'), findsOneWidget);
      expect(find.text('Together'), findsOneWidget);
      expect(find.text('Events'), findsNothing);
      expect(find.text('Gift us'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _screenshot(tester, width == 390 ? 'gifts' : 'gifts-narrow');
      await tester.scrollUntilVisible(find.text('Crochet flower bouquet'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      await _screenshot(
          tester, width == 390 ? 'gifts-products' : 'gifts-products-narrow');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
      'Shopee search, saved ideas, seller link and Premium preview work',
      (tester) async {
    Uri? opened;
    await _pump(tester, Routes.gifts, openLink: (uri) async {
      opened = uri;
      return true;
    });
    await tester.tap(find.text('View subscription'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Subscriptions are not available yet. Nothing will be charged.'),
        findsOneWidget);
    await _screenshot(tester, 'gift-us-subscription');
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'mugs');
    await tester.pumpAndSettle();
    expect(find.text('1 idea'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byTooltip('Save Personalized couple mugs'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Save Personalized couple mugs'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unsave Personalized couple mugs'), findsOneWidget);
    await tester.ensureVisible(find.text('Open Shopee'));
    await tester.tap(find.text('Open Shopee'));
    await tester.pumpAndSettle();
    expect(opened?.host, 'shopee.ph');
    expect(opened?.path, endsWith('i.380284623.28921400102'));
  });

  testWidgets('Failed seller link gives feedback', (tester) async {
    await _pump(tester, Routes.gifts, openLink: (_) async => false);
    await tester.enterText(find.byType(TextField), 'mugs');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Open Shopee'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open Shopee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Shopee'));
    await tester.pumpAndSettle();
    expect(
        find.text('Could not open Shopee. Please try again.'), findsOneWidget);
  });

  testWidgets('Together without start date still offers Gifts and Events',
      (tester) async {
    await _pump(tester, Routes.together, hasStart: false);
    await tester.ensureVisible(find.text('Gifts'));
    expect(find.text('Gifts'), findsOneWidget);
    await tester.ensureVisible(find.text('Events'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.byType(EventsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'Five tabs open their assigned sections on narrow and regular phones',
      (tester) async {
    for (final width in [390.0, 320.0]) {
      await _pump(tester, Routes.home, width: width);
      for (final (label, route) in [
        ('Home', Routes.home),
        ('Chat', Routes.chat),
        ('Memories', Routes.memories),
        ('Together', Routes.together),
        ('Dayflower', Routes.dayflower),
      ]) {
        final button = find.descendant(
            of: find.byType(AppBottomNav),
            matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.label == label));
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
            GoRouterState.of(tester.element(find.byType(AppBottomNav).last))
                .uri
                .path,
            route);
        expect(
            find.descendant(
                of: find.byType(AppBottomNav),
                matching: find.byWidgetPredicate(
                    (w) => w is Semantics && w.properties.selected == true)),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        if (width == 390) {
          await _screenshot(tester, 'navigation-${label.toLowerCase()}');
        }
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Memories preserves content and Dayflower owns creation',
      (tester) async {
    final router = await _pump(tester, Routes.memories);
    await tester.pumpAndSettle();
    expect(find.text('Your story will grow here.'), findsOneWidget);
    expect(find.text('Booth & Strip'), findsNothing);
    router.go(Routes.dayflower);
    await tester.pumpAndSettle();
    expect(find.text('Send a flower'), findsWidgets);
    expect(find.text('Photo Booth'), findsOneWidget);
    await _screenshot(tester, 'story-dayflower');
    await tester.ensureVisible(find.text('Photo Booth'));
    await tester.tap(find.text('Photo Booth'));
    await tester.pumpAndSettle();
    expect(find.byType(BoothScreen), findsOneWidget);
  });

  testWidgets(
      'Home bell opens only partner updates; Us keeps full activity history',
      (tester) async {
    final router = await _pump(tester, Routes.home);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityFeedScreen), findsOneWidget);
    expect(find.text('Your reminder'), findsNothing);
    expect(find.text('A photo strip is waiting on you'), findsOneWidget);
    await _screenshot(tester, 'navigation-notifications');
    await tester.tap(find.text('A photo strip is waiting on you'));
    await tester.pumpAndSettle();
    expect(find.byType(BoothScreen), findsOneWidget);
    router.go(Routes.us);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity history'));
    await tester.pumpAndSettle();
    expect(find.text('Your reminder'), findsOneWidget);
    expect(find.text('A photo strip is waiting on you'), findsOneWidget);
  });

  testWidgets('Together opens the existing goal editor without memory sections',
      (tester) async {
    await _pump(tester, Routes.together);
    await tester.scrollUntilVisible(find.text('Shared Goals'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Shared Goals'));
    await tester.pumpAndSettle();
    expect(find.byType(ChapterDetailScreen), findsOneWidget);
    expect(find.text('GOALS FOR THE MONTH'), findsOneWidget);
    expect(find.text('THE REVIEW'), findsNothing);
    expect(find.text('What happened'), findsNothing);
  });

  testWidgets('Us widget shortcut opens existing preferences and returns Us',
      (tester) async {
    final router = await _pump(tester, Routes.us);
    await tester.scrollUntilVisible(find.text('Widgets & Connections'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Widgets & Connections'));
    await tester.pumpAndSettle();
    expect(find.byType(WidgetSettingsScreen), findsOneWidget);
    expect(find.text('HOME SCREEN WIDGET'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(UsScreen), findsOneWidget);
  });

  testWidgets(
      'Old gift and chat notification links redirect without losing context',
      (tester) async {
    final router = await _pump(tester, '/app/gifts?occasion=birthday');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.gifts);
    expect(
        router.routeInformationProvider.value.uri.queryParameters['occasion'],
        'birthday');
    router.go('/app/flowers/chat');
    await tester.pumpAndSettle();
    expect(find.byType(FlowersScreen), findsOneWidget);
  });

  testWidgets('Chat keeps the composer usable when the keyboard opens',
      (tester) async {
    await _pump(tester, Routes.chat);
    expect(find.byType(AppBottomNav), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNav), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  test('An old goal notification still opens the month it belongs to', () {
    final activity = Activity(
        id: 'goal',
        pairId: 'pair',
        actorId: 'partner',
        kind: ActivityKind.goalSet,
        title: 'A goal',
        emoji: '🎯',
        subjectId: 'goal',
        meta: const {'year': 2025, 'month': 11},
        createdAt: DateTime(2025, 11));
    expect(activity.route, Routes.goalsFor(2025, 11));
  });
  testWidgets(
      'Saved flowers filter and open a detail without recreating content',
      (tester) async {
    await _pump(tester, Routes.memories, messages: [
      FlowerMessage(
          id: 'bloom',
          pairId: 'preview',
          senderId: 'preview-b',
          flowerType: 'classic_tulip',
          note: 'Thinking of you',
          sentAt: DateTime(2026, 9, 19))
    ]);
    await tester.pumpAndSettle();
    await tester.runAsync(() => precacheImage(
        AssetImage(FlowerCatalog.byId('classic_tulip').asset),
        tester.element(find.byType(MemoriesScreen))));
    await tester.pumpAndSettle();
    await _screenshot(tester, 'story-memory-timeline');
    await tester.tap(find.text('Flowers'));
    await tester.pumpAndSettle();
    expect(find.text('Thinking of you'), findsOneWidget);
    await tester.tap(find.text('Thinking of you'));
    await tester.pumpAndSettle();
    expect(find.text('From Jamie'), findsOneWidget);
    expect(find.text('Declaration of love'), findsOneWidget);
    await _screenshot(tester, 'story-flower-detail');
  });

  testWidgets('Primary pages remain usable with large accessibility text',
      (tester) async {
    for (final route in [
      Routes.home,
      Routes.dayflower,
      Routes.memories,
      Routes.together,
      Routes.us
    ]) {
      await _pump(tester, route, width: 320, textScale: 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Partner mood is available on Home without opening Flowers',
      (tester) async {
    await _pump(tester, Routes.home, partnerMood: Mood.loved);
    expect(find.text('Jamie is feeling loved 🥰'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PreviewActivityRepository extends ActivityRepository {
  _PreviewActivityRepository() : super(offlineClient());
  @override
  Future<void> markSeen(
      {required String pairId, required String userId}) async {}
}

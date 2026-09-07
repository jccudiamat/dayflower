import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/models/pair.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/features/activity/data/activity_repository.dart';
import 'package:dayflower/features/calls/data/call_usage.dart';
import 'package:dayflower/features/dates/presentation/screens/events_screen.dart';
import 'package:dayflower/features/gifts/presentation/screens/gifts_screen.dart';
import 'package:dayflower/features/gifts/presentation/widgets/gift_occasion_card.dart';
import 'package:dayflower/features/heartbeat/data/heartbeat_repository.dart';
import 'package:dayflower/features/home/presentation/screens/home_screen.dart';
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
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

// Offline data only: the real screens are rendered without signing in or
// writing to the shared backend. Screenshots are opt-in review artifacts.
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');
var _boundary = GlobalKey();

Future<GoRouter> _pump(WidgetTester tester, String route,
    {double width = 390, bool hasStart = true}) async {
  _boundary = GlobalKey();
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: route, routes: [
    GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
    GoRoute(path: Routes.us, builder: (_, __) => const UsScreen()),
    GoRoute(path: Routes.events, builder: (_, __) => const EventsScreen()),
    GoRoute(path: Routes.gifts, builder: (_, s) => GiftsScreen(occasion: s.uri.queryParameters['occasion'])),
    for (final route in [Routes.chat, Routes.flowers, Routes.activities])
      GoRoute(path: route, builder: (_, __) => const Scaffold(body: Text('Existing destination'))),
  ]);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('preview-a'),
      currentPairProvider.overrideWith((ref) async => Pair(
        id: 'preview', userA: 'preview-a', userB: 'preview-b', inviteCode: 'PREVIEW',
        togetherSince: hasStart ? DateTime(2023, 9, 19) : null,
      )),
      userProfileProvider.overrideWith((ref) async => const UserProfile(id: 'preview-a', displayName: 'Alex', timezone: 'Asia/Dubai')),
      partnerProfileProvider.overrideWith((ref) async => const UserProfile(id: 'preview-b', displayName: 'Jamie', timezone: 'Asia/Manila')),
      unreadMessageCountProvider.overrideWithValue(0),
      coupleStatsProvider.overrideWith((ref) async => const CoupleStats(hearts: 128, flowers: 42, photos: 36, streak: 7)),
      callUsageProvider.overrideWith((ref) async => const CallUsage()),
      todayHeartbeatCountsProvider.overrideWithValue((mine: 0, partner: 0)),
      myDayPhotoProvider.overrideWithValue(null),
      partnerDayPhotoProvider.overrideWithValue(null),
      recentActivitiesProvider.overrideWithValue(const AsyncData([])),
      unseenActivityCountProvider.overrideWithValue(0),
      activityLastSeenProvider.overrideWith((ref) async => null),
    ],
    child: RepaintBoundary(key: _boundary,
      child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: AppTheme.light, routerConfig: router)),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return router;
}

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
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
    final fontCache = await Directory('build/review/fonts').create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => fontCache.absolute.path);
    HttpOverrides.global = null;
    GoogleFonts.config.allowRuntimeFetching = true;
    AppTheme.light;
    GoogleFonts.lora(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500);
    await GoogleFonts.pendingFonts();
    for (final (family, asset) in [
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ('packages/cupertino_icons/CupertinoIcons', 'packages/cupertino_icons/assets/CupertinoIcons.ttf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
    final emoji = File('C:/Windows/Fonts/seguiemj.ttf');
    if (_capture && await emoji.exists()) {
      await (FontLoader('Quicksand')..addFont(emoji.readAsBytes().then((b) => ByteData.sublistView(b)))).load();
    }
  });

  testWidgets('Home gift card opens contextual Gifts and back returns Home', (tester) async {
    final router = await _pump(tester, Routes.home);
    await tester.scrollUntilVisible(find.byType(GiftOccasionCard), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await _screenshot(tester, 'home');
    await tester.tap(find.text('Gift ideas'));
    await tester.pumpAndSettle();
    final giftState = GoRouterState.of(tester.element(find.byType(GiftsScreen)));
    expect(giftState.uri.path, Routes.gifts);
    expect(giftState.uri.queryParameters['occasion'], isNotNull);
    expect(find.textContaining('A gift for your'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Us opens intact Events with editor, clocks and reunion; back returns Us', (tester) async {
    final router = await _pump(tester, Routes.us);
    await _screenshot(tester, 'shared-profile');
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
    expect(find.byType(UsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Gifts replaces Events in nav and fits narrow phones', (tester) async {
    for (final width in [390.0, 320.0]) {
      await _pump(tester, Routes.gifts, width: width);
      expect(find.text('Gifts'), findsNWidgets(2));
      expect(find.text('Events'), findsNothing);
      expect(find.text('Gift us'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _screenshot(tester, width == 390 ? 'gifts' : 'gifts-narrow');
      await tester.scrollUntilVisible(find.text('Initial necklace'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      await _screenshot(tester, width == 390 ? 'gifts-products' : 'gifts-products-narrow');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Mock catalog search, saved ideas and Premium preview work', (tester) async {
    await _pump(tester, Routes.gifts);
    await tester.tap(find.text('View subscription'));
    await tester.pumpAndSettle();
    expect(find.text('Subscriptions are not available yet. Nothing will be charged.'), findsOneWidget);
    await _screenshot(tester, 'gift-us-subscription');
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'mugs');
    await tester.pumpAndSettle();
    expect(find.text('1 idea'), findsOneWidget);
    await tester.scrollUntilVisible(find.byTooltip('Save A pair of mugs'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Save A pair of mugs'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unsave A pair of mugs'), findsOneWidget);
    await tester.ensureVisible(find.text('View at retailer ↗'));
    await tester.tap(find.text('View at retailer ↗'));
    await tester.pumpAndSettle();
    expect(find.text('A little preview'), findsOneWidget);
  });

  testWidgets('Home without start date still offers Gifts and Events', (tester) async {
    await _pump(tester, Routes.home, hasStart: false);
    await tester.scrollUntilVisible(find.byType(GiftOccasionCard), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('For someone you love'), findsOneWidget);
    await tester.ensureVisible(find.text('View events'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View events'));
    await tester.pumpAndSettle();
    expect(find.byType(EventsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

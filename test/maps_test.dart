import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/models/pair.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/core/widgets/app_bottom_nav.dart';
import 'package:dayflower/features/home/domain/home_moments.dart';
import 'package:dayflower/features/home/presentation/widgets/home_map_card.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/pairing/data/pair_repository.dart';
import 'package:dayflower/features/travel/data/map_pin_repository.dart';
import 'package:dayflower/features/travel/presentation/screens/travel_map_screen.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

// Screenshots, opt in:
//   flutter test test/maps_test.dart --dart-define=CAPTURE_REVIEW=true
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');

// Wifey's phone: she is in the Philippines, he is in Dubai.
const _wifey = UserProfile(
    id: 'me',
    displayName: 'Wifey',
    timezone: 'Asia/Manila',
    city: 'Bulacan, Philippines',
    cityLat: 14.79,
    cityLon: 120.88);
const _hubby = UserProfile(
    id: 'them',
    displayName: 'Hubby',
    timezone: 'Asia/Dubai',
    city: 'Dubai, United Arab Emirates',
    cityLat: 25.2048,
    cityLon: 55.2708);

List<Override> get _overrides => [
      currentUserIdProvider.overrideWithValue('me'),
      userProfileProvider.overrideWith((ref) async => _wifey),
      partnerProfileProvider.overrideWith((ref) async => _hubby),
      partnerProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentPairProvider.overrideWith((ref) async =>
          const Pair(id: 'pair', userA: 'me', userB: 'them', inviteCode: 'X')),
      homeClockProvider
          .overrideWith((ref) => Stream.value(DateTime.utc(2026, 9, 24, 20))),
      mapPinsProvider.overrideWith((ref) => Stream.value(const [])),
      unreadMessageCountProvider.overrideWithValue(0),
    ];

Future<void> _shoot(WidgetTester tester, GlobalKey key, String name) =>
    tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/review/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    });

void main() {
  setUpAll(() async {
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
    // Screenshots let real time run, and the tile cache then asks for a
    // cache folder, which no test has. Tiles still do not load (no network
    // in tests); the shots are of the layout and the arc.
    if (_capture) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => Directory.systemTemp.path);
    }
  });

  testWidgets('each city sits over its own face, from either phone',
      (tester) async {
    // 🔴 The card put "me" top left always. From Wifey's phone that put
    // Bulacan over Hubby's face in Dubai, which is west, on the left.
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(390, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides,
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          theme: AppTheme.current,
          debugShowCheckedModeBanner: false,
          home: const Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: HomeMapCard()),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final dubai = tester.getCenter(find.text('Dubai'));
    final bulacan = tester.getCenter(find.text('Bulacan'));
    expect(dubai.dx, lessThan(bulacan.dx), reason: 'Dubai is the west one');
    expect(tester.takeException(), isNull);
    if (_capture) await _shoot(tester, boundary, 'home-map-wifey');
  });

  test('the furthest out the map goes is where the world fills it', () {
    // One tile, 256 px, is the whole world at zoom 0; each step doubles it.
    expect(TravelMapScreen.worldFillZoom(512), closeTo(1.01, 1e-9));
    expect(TravelMapScreen.worldFillZoom(768), greaterThan(1.58));
    expect(TravelMapScreen.worldFillZoom(200), 0);
  });

  test('the opening centre is moved just enough to stay inside the world',
      () {
    const height = 780.0;
    final min = TravelMapScreen.worldFillZoom(height);
    // All the way out, only the equator fits.
    expect(TravelMapScreen.fitCentre(const LatLng(20, 88), min, height)
        .latitude, closeTo(0, 1));
    // Further in, the two of you at 20 degrees north fit as you are.
    final framed =
        TravelMapScreen.fitCentre(const LatLng(20, 88), 3.2, height);
    expect(framed.latitude, closeTo(20, 1e-6));
    expect(framed.longitude, 88);
    // Near a pole, pulled back to where the view still ends at the edge.
    expect(TravelMapScreen.fitCentre(const LatLng(84, 0), 3.2, height)
        .latitude, lessThan(84));
  });

  test('it opens with both of you, and the arc, on screen', () {
    // 🔴 A fixed opening zoom put Dubai and the Philippines both off the
    // edges of a phone.
    const size = Size(390, 780);
    const padding = EdgeInsets.fromLTRB(56, 170, 56, 160);
    const dubai = LatLng(25.2048, 55.2708), bulacan = LatLng(14.79, 120.88);
    final min = TravelMapScreen.worldFillZoom(size.height);
    final (centre, zoom) = TravelMapScreen.openingCamera(
        [dubai, bulacan], size, padding,
        minZoom: min);
    expect(zoom, greaterThanOrEqualTo(min));

    // Where each lands on screen, Web Mercator at that zoom.
    Offset screen(LatLng p) {
      final scale = 256 * math.pow(2, zoom);
      double x(LatLng q) => (q.longitude + 180) / 360 * scale;
      double y(LatLng q) {
        final r = q.latitude * math.pi / 180;
        return (1 - math.log(math.tan(math.pi / 4 + r / 2)) / math.pi) /
            2 *
            scale;
      }

      return Offset(x(p) - x(centre) + size.width / 2,
          y(p) - y(centre) + size.height / 2);
    }

    final room = Rect.fromLTRB(padding.left, padding.top,
        size.width - padding.right, size.height - padding.bottom);
    for (final p in [dubai, bulacan]) {
      final at = screen(p);
      expect(room.inflate(1).contains(at), isTrue, reason: '$p at $at');
    }
  });

  testWidgets('the travel map is the whole screen, and stops at the edges',
      (tester) async {
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(initialLocation: Routes.travel, routes: [
      GoRoute(
          path: Routes.travel, builder: (_, __) => const TravelMapScreen()),
      GoRoute(
          path: Routes.together,
          builder: (_, __) => const Scaffold(body: Text('Together'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides,
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp.router(
          theme: AppTheme.current,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // No app bar: the map starts at the very top of the screen.
    expect(find.byType(AppBar), findsNothing);
    expect(tester.getRect(find.byType(FlutterMap)).top, 0);
    final options = tester.widget<FlutterMap>(find.byType(FlutterMap)).options;
    // Everything above the bottom bar is map.
    final height = 844 - tester.getSize(find.byType(AppBottomNav)).height;
    expect(tester.getSize(find.byType(FlutterMap)).height, height,
        reason: 'the map runs all the way down to the bar');
    // The credit sits at the foot of the map, not on the controls.
    expect(tester.getRect(find.textContaining('OpenStreetMap')).bottom,
        greaterThan(height - 40));
    expect(options.minZoom, closeTo(TravelMapScreen.worldFillZoom(height), 1e-9));
    expect(options.cameraConstraint, isA<ContainCameraLatitude>());
    // The way out floats on the map.
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Travel map'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (_capture) await _shoot(tester, boundary, 'travel-map');
  });
}

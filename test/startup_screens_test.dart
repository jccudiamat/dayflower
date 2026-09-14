import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/services/legal_links.dart';
import 'package:dayflower/core/theme/app_colors.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/features/auth/presentation/screens/welcome_screen.dart';
import 'package:dayflower/features/auth/presentation/widgets/startup_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const capture = bool.fromEnvironment('CAPTURE_REVIEW');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('TikTokSans')
          ..addFont(rootBundle.load('assets/fonts/tiktok/TikTokSans.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  tearDown(() => AppColors.use(AppMode.light));

  for (final mode in AppMode.values) {
    for (final config in [
      (390.0, 844.0, 1.0),
      (320.0, 640.0, 1.0),
      (320.0, 640.0, 2.0)
    ]) {
      testWidgets('startup ${mode.name} ${config.$1} text scale ${config.$3}',
          (tester) async {
        AppColors.use(mode);
        tester.view.physicalSize = Size(config.$1, config.$2);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        final opened = <Uri>[];
        final router = GoRouter(initialLocation: Routes.welcome, routes: [
          GoRoute(
              path: Routes.welcome, builder: (_, __) => const WelcomeScreen()),
          GoRoute(
              path: Routes.login,
              builder: (_, __) => const Scaffold(body: Text('Email sign in'))),
          GoRoute(
              path: Routes.splash, builder: (_, __) => const SplashScreen()),
        ]);
        addTearDown(router.dispose);
        await tester.pumpWidget(ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => const Stream.empty()),
              legalLinkLauncherProvider.overrideWithValue((uri) async {
                opened.add(uri);
                return true;
              }),
            ],
            child: RepaintBoundary(
                key: boundary,
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.current,
                  routerConfig: router,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(config.$3),
                        disableAnimations: true),
                    child: child!,
                  ),
                ))));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final context = tester.element(find.byType(WelcomeScreen));
          await Future.wait([
            precacheImage(const AssetImage('assets/images/mark.png'), context),
            precacheImage(
                const AssetImage('assets/images/flowers/sunset_shore.webp'),
                context),
          ]);
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (capture && config.$1 == 390) {
          await _image(tester, boundary, 'welcome-${mode.name}');
        }
        await tester.ensureVisible(find.text('Privacy Policy'));
        await tester.tap(find.text('Privacy Policy'));
        await tester.pumpAndSettle();
        expect(opened.single, LegalPage.privacy.uri);
        await tester.ensureVisible(find.text('Continue with email'));
        await tester.tap(find.text('Continue with email'));
        await tester.pumpAndSettle();
        expect(find.text('Email sign in'), findsOneWidget);
        router.go(Routes.splash);
        await tester.pumpAndSettle();
        expect(find.byType(StartupLoadingView), findsOneWidget);
        expect(find.text('Opening your space'), findsOneWidget);
        expect(find.text('two lips, one garden'), findsNothing);
        expect(tester.takeException(), isNull);
        if (capture && config.$1 == 390) {
          await _image(tester, boundary, 'loading-${mode.name}');
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

Future<void> _image(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

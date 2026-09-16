import 'dart:io';
import 'dart:ui' as ui;
import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/core/theme/app_colors.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/presence/data/presence_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/tulip/data/reaction_repository.dart';
import 'package:dayflower/features/tulip/presentation/screens/flowers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'review/chat_review_nav.dart';

// Visual proposal only. Real Chat widgets and offline sample messages, with
// the proposed navigation outside the screen. No backend writes or calls.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    final emoji = File('C:/Windows/Fonts/seguiemj.ttf');
    if (await emoji.exists()) {
      await (FontLoader('TikTokSans')
            ..addFont(emoji.readAsBytes().then((b) => ByteData.sublistView(b))))
          .load();
    }
  });
  for (final filled in [true, false]) {
    testWidgets('Chat review ${filled ? 'populated' : 'empty'}',
        (tester) async {
      AppColors.use(AppMode.light);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final router = GoRouter(initialLocation: Routes.chat, routes: [
        GoRoute(
            path: Routes.chat,
            builder: (_, __) => const Material(
                  color: Color(0xFFF8F5FC),
                  child: Column(children: [
                    Expanded(child: FlowersScreen()),
                    ChatReviewNav(),
                  ]),
                )),
      ]);
      final now = DateTime.now();
      final messages = <FlowerMessage>[
        if (filled)
          for (final (index, sender, text) in [
            (0, 'preview-a', 'Of course. I will call you after dinner.'),
            (1, 'preview-b', 'Can we have a little video date tonight?'),
            (2, 'preview-a', 'Same here. How was your day?'),
            (
              3,
              'preview-b',
              'Just got home. Missing you a little extra today.'
            ),
          ])
            FlowerMessage(
                id: 'preview-$index',
                pairId: 'preview',
                senderId: sender,
                note: text,
                sentAt: now.subtract(Duration(minutes: index + 1)),
                seenAt: now),
      ];
      await tester.pumpWidget(ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('preview-a'),
            flowerMessagesProvider
                .overrideWith((ref) => Stream.value(messages)),
            reactionsProvider.overrideWith((ref) => Stream.value({})),
            unreadMessageCountProvider.overrideWithValue(0),
            partnerProfileProvider.overrideWith((ref) async =>
                const UserProfile(
                    id: 'preview-b',
                    displayName: 'Wifey',
                    timezone: 'Asia/Manila')),
            partnerProfileStreamProvider
                .overrideWith((ref) => Stream.value(null)),
            partnerLastActiveProvider.overrideWith((ref) async => now),
          ],
          child: RepaintBoundary(
              key: boundary,
              child: MaterialApp.router(
                theme: AppTheme.current,
                debugShowCheckedModeBanner: false,
                routerConfig: router,
              ))));
      await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.byTooltip('Voice call'), findsOneWidget);
      expect(find.byTooltip('Video call'), findsOneWidget);
      expect(find.byTooltip('Send a photo'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      if (const bool.fromEnvironment('CAPTURE_REVIEW')) {
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file =
              File('build/review/chat-${filled ? 'filled' : 'empty'}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }
}

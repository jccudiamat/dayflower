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

/// The composer is one line while empty, and stacks once there are words:
/// the words on the full width, the icons in their own row underneath.
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
  });

  const icons = ['Send a flower', 'Attach a photo', 'Take a photo'];

  for (final mode in [AppMode.light, AppMode.dark]) {
    testWidgets('one line empty, stacked with words (${mode.name})',
        (tester) async {
      AppColors.use(mode);
      addTearDown(() => AppColors.use(AppMode.light));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final router = GoRouter(initialLocation: Routes.chat, routes: [
        GoRoute(path: Routes.chat, builder: (_, __) => const FlowersScreen()),
      ]);
      final now = DateTime.now();
      final messages = [
        FlowerMessage(
            id: 'm1',
            pairId: 'p',
            senderId: 'b',
            note: 'Can we have a little video date tonight?',
            sentAt: now.subtract(const Duration(minutes: 2)),
            seenAt: now),
      ];
      await tester.pumpWidget(ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('a'),
            flowerMessagesProvider
                .overrideWith((ref) => Stream.value(messages)),
            reactionsProvider.overrideWith((ref) => Stream.value({})),
            unreadMessageCountProvider.overrideWithValue(0),
            partnerProfileProvider.overrideWith((ref) async =>
                const UserProfile(
                    id: 'b', displayName: 'Wifey', timezone: 'Asia/Manila')),
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

      Future<void> shot(String name) async {
        if (!const bool.fromEnvironment('CAPTURE_REVIEW')) return;
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/review/composer-${mode.name}-$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      final field = find.byType(TextField);
      double middle(Finder f) => tester.getCenter(f).dy;

      // Empty: one line, the icons either side of "Message".
      await shot('empty');
      for (final tip in icons) {
        expect(middle(find.byTooltip(tip)), closeTo(middle(field), 1),
            reason: '$tip on the line of the field');
      }

      await tester.tap(field);
      await tester.pump();
      final editing = tester.state<EditableTextState>(find.byType(EditableText));

      tester.testTextInput.enterText('H');
      await tester.pumpAndSettle();
      await shot('typed');

      // 🔴 The field moved into the stacked layout without being rebuilt:
      // same state, still focused, still taking the keyboard's letters.
      expect(tester.state<EditableTextState>(find.byType(EditableText)),
          same(editing));
      expect(editing.widget.focusNode.hasFocus, isTrue);
      tester.testTextInput.enterText('Hi, see you tonight');
      await tester.pumpAndSettle();
      expect(find.text('Hi, see you tonight'), findsOneWidget);

      // Stacked: every icon still there, all of them below the words.
      final fieldBottom = tester.getRect(field).bottom;
      for (final tip in icons) {
        expect(find.byTooltip(tip), findsOneWidget, reason: '$tip stays');
        expect(tester.getRect(find.byTooltip(tip)).top,
            greaterThanOrEqualTo(fieldBottom - 1),
            reason: '$tip below the words');
      }
      // The words have the pill's width, not what the icons leave them.
      expect(tester.getRect(field).left,
          lessThan(tester.getRect(find.byTooltip('Send a flower')).right));

      tester.testTextInput.enterText(
          'A longer message that runs over a few lines, to see the icons '
          'stay in their row while the words grow upwards');
      await tester.pumpAndSettle();
      await shot('long');

      // Emptied: back to one line.
      tester.testTextInput.enterText('');
      await tester.pumpAndSettle();
      for (final tip in icons) {
        expect(middle(find.byTooltip(tip)), closeTo(middle(field), 1));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }
}

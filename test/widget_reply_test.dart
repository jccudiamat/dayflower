import 'dart:io';

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/presence/data/presence_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/tulip/data/reaction_repository.dart';
import 'package:dayflower/features/tulip/presentation/screens/flowers_screen.dart';
import 'package:dayflower/features/tulip/presentation/widgets/message_quote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The reply bubble beside the widget's heart, and what a widget tap is
/// allowed to do in the background.
void main() {
  String read(String path) => File(path).readAsStringSync();
  const kotlin = 'android/app/src/main/kotlin/com/dayflower/app/';

  group('the reply bubble', () {
    Future<void> pumpChat(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final messages = [
        FlowerMessage(
            id: 'day-1',
            pairId: 'p',
            senderId: 'b',
            note: 'sunset walk after work',
            imagePath: 'b/day.jpg',
            toWidget: true,
            sentAt: now.subtract(const Duration(hours: 1)),
            seenAt: now),
        FlowerMessage(
            id: 'm1',
            pairId: 'p',
            senderId: 'b',
            note: 'Miss you',
            sentAt: now.subtract(const Duration(minutes: 2)),
            seenAt: now),
      ];
      final router = GoRouter(initialLocation: Routes.chat, routes: [
        GoRoute(path: Routes.chat, builder: (_, __) => const FlowersScreen()),
      ]);
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
          child: MaterialApp.router(
            theme: AppTheme.current,
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          )));
      await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pumpAndSettle();
    }

    Finder quoting(String id) =>
        find.byWidgetPredicate((w) => w is MessageQuote && w.replyTo == id);

    testWidgets('opens the chat with a reply to that day started',
        (tester) async {
      // Asked before the chat is even up, as on a cold start.
      replyFromWidgetRequest.value = (id: 'day-1', at: DateTime.now());
      addTearDown(() => replyFromWidgetRequest.value = null);
      await pumpChat(tester);

      expect(quoting('day-1'), findsOneWidget,
          reason: 'the day, on the composer, being replied to');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode?.hasFocus, isTrue, reason: 'ready to type');
      expect(replyFromWidgetRequest.value, isNull, reason: 'answered once');
    });

    testWidgets('a stale request does not start a reply later',
        (tester) async {
      replyFromWidgetRequest.value = (
        id: 'day-1',
        at: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      addTearDown(() => replyFromWidgetRequest.value = null);
      await pumpChat(tester);

      expect(quoting('day-1'), findsNothing);
      expect(replyFromWidgetRequest.value, isNull);
    });

    test('every heart on the widget has its reply beside it', () {
      const layouts = 'android/app/src/main/res/layout/';
      for (final (file, pairs) in [
        (
          'todays_tulip_widget.xml',
          [('widget_heart', 'widget_reply'), ('widget_body_heart', 'widget_body_reply')]
        ),
        ('widget_photo_item.xml', [('widget_item_heart', 'widget_item_reply')]),
        ('widget_day_item.xml', [('widget_day_heart', 'widget_day_reply')]),
      ]) {
        final xml = read('$layouts$file');
        for (final (heart, reply) in pairs) {
          final h = xml.indexOf('@+id/$heart"');
          final r = xml.indexOf('@+id/$reply"');
          expect(h, isNot(-1), reason: '$file: $heart');
          expect(r, greaterThan(h), reason: '$file: $reply after $heart');
        }
      }
      // And each one opens the reply the app understands.
      expect(read('${kotlin}TodaysTulipWidget.kt'),
          contains('dayflower://reply?id='));
      expect(read('${kotlin}DayListService.kt'),
          contains('dayflower://open?reply='));
      expect(read('${kotlin}DayLikeReceiver.kt'),
          contains('dayflower://reply?id='));
      expect(read('lib/app.dart'), contains("case 'reply':"));
    });
  });

  // 🔴 A widget tap and a notification's button run in background isolates
  // that outlive an account switch. Supabase set up there once went on
  // sending as the account signed in at the first tap: Hubby's heartbeats
  // arrived as Wifey's.
  group('background taps', () {
    test('only the app and withBackgroundSupabase set Supabase up', () {
      final initializing = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('Supabase.initialize('))
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toSet();
      expect(initializing, {
        'lib/main.dart',
        'lib/core/services/background_supabase.dart',
      });
    });

    test('each run reads the session fresh and closes its client', () {
      final helper = read('lib/core/services/background_supabase.dart');
      expect(helper, contains('prefs.reload()'));
      expect(helper, contains('Supabase.instance.dispose()'));
      // The widget's and the notifications' background entry points use it.
      expect(read('lib/features/widget/widget_sync.dart'),
          contains('withBackgroundSupabase'));
      expect(read('lib/features/reminders/data/reminder_scheduler.dart'),
          contains('withBackgroundSupabase'));
    });

    test('signing out empties the widgets', () {
      expect(read('lib/features/auth/data/auth_repository.dart'),
          contains('DayflowerWidgets.clearAccount()'));
    });
  });
}

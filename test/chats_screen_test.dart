import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/app.dart';
import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_colors.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/core/widgets/app_bottom_nav.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/presence/data/presence_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/tulip/data/reaction_repository.dart';
import 'package:dayflower/features/tulip/presentation/screens/chats_screen.dart';
import 'package:dayflower/features/tulip/presentation/screens/flowers_screen.dart';
import 'package:dayflower/features/tulip/presentation/widgets/chat_bubble.dart';
import 'package:dayflower/features/tulip/presentation/widgets/conversation_row.dart';
import 'package:dayflower/features/tulip/presentation/widgets/message_quote.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Screenshot of the list, opt in:
//   flutter test test/chats_screen_test.dart --dart-define=CAPTURE_REVIEW=true
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');

const _wifey = UserProfile(id: 'them', displayName: 'Jamie', petName: 'Wifey');

FlowerMessage _text(String id, String sender, String note, DateTime at,
        {String? replyTo, bool seen = true}) =>
    FlowerMessage(
        id: id,
        pairId: 'pair',
        senderId: sender,
        note: note,
        sentAt: at,
        seenAt: seen ? at : null,
        replyTo: replyTo);

Future<GoRouter> _pump(
  WidgetTester tester, {
  required String at,
  required List<FlowerMessage> messages,
  double width = 390,
  double height = 844,
  double textScale = 1,
  GlobalKey? boundary,
  AppMode mode = AppMode.light,
}) async {
  AppColors.use(mode);
  addTearDown(() => AppColors.use(AppMode.light));
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: at, routes: [
    GoRoute(path: Routes.chats, builder: (_, __) => const ChatsScreen()),
    GoRoute(path: Routes.chat, builder: (_, __) => const FlowersScreen()),
    GoRoute(
        path: Routes.flowers,
        builder: (_, __) => const Scaffold(body: Text('Camera'))),
    GoRoute(
        path: Routes.home,
        builder: (_, __) => const Scaffold(body: Text('Home'))),
  ]);
  addTearDown(router.dispose);
  final now = DateTime.now();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      flowerMessagesProvider.overrideWith((ref) => Stream.value(messages)),
      reactionsProvider.overrideWith((ref) => Stream.value({})),
      partnerProfileProvider.overrideWith((ref) async => _wifey),
      partnerProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      partnerLastActiveProvider.overrideWith((ref) async => now),
    ],
    child: RepaintBoundary(
      key: boundary,
      child: MediaQuery(
        data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScale)),
        child: MaterialApp.router(
          theme: AppTheme.current,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
        ),
      ),
    ),
  ));
  await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _shoot(WidgetTester tester, GlobalKey boundary, String name) =>
    tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject()!
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
    final emoji = File('C:/Windows/Fonts/seguiemj.ttf');
    if (await emoji.exists()) {
      await (FontLoader('TikTokSans')
            ..addFont(emoji.readAsBytes().then((b) => ByteData.sublistView(b))))
          .load();
    }
  });

  group('the Chats list', () {
    final now = DateTime.now();
    final thread = [
      _text('2', 'them', 'Call me when you land 💕', now, seen: false),
      _text('1', 'them', 'Boarding now', now.subtract(const Duration(minutes: 3)),
          seen: false),
      _text('0', 'me', 'Safe flight!', now.subtract(const Duration(hours: 1))),
    ];

    testWidgets('leads with them: face, name, last message, unread',
        (tester) async {
      final boundary = GlobalKey();
      await _pump(tester,
          at: Routes.chats, messages: thread, boundary: boundary);
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Wifey'), findsOneWidget);
      expect(find.text('Call me when you land 💕'), findsOneWidget);
      // Two unread, on the row; the Chat tab carries the same count.
      expect(
          find.descendant(
              of: find.byType(ConversationRow), matching: find.text('2')),
          findsOneWidget);
      // The green dot is read out with the row: "Active now, Wifey, ...".
      expect(find.bySemanticsLabel(RegExp('Active now')), findsOneWidget);
      expect(find.byTooltip('Camera'), findsOneWidget);
      // The tab is still a tab: the bar is here, unlike in the conversation.
      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(tester.takeException(), isNull);

      if (_capture) {
        await _shoot(tester, boundary, 'chats-list');
        await tester.pumpWidget(const SizedBox());
        await _pump(tester,
            at: Routes.chats,
            messages: thread,
            boundary: boundary,
            mode: AppMode.dark);
        await _shoot(tester, boundary, 'chats-list-dark');
      }
    });

    testWidgets('Channels and Reads are held, greyed and inert',
        (tester) async {
      final router =
          await _pump(tester, at: Routes.chats, messages: thread);
      for (final name in ['Channels', 'Reads']) {
        expect(find.text(name), findsOneWidget);
        // Nothing to press: no ink, no gesture, anywhere in the row.
        final row = find.ancestor(
            of: find.text(name), matching: find.byType(ComingSoonRow));
        expect(
            find.descendant(of: row, matching: find.byType(InkWell)),
            findsNothing);
        expect(
            find.descendant(of: row, matching: find.byType(GestureDetector)),
            findsNothing);
        await tester.tap(find.text(name), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, Routes.chats);
      }
      expect(find.bySemanticsLabel(RegExp('Channels, coming soon')),
          findsOneWidget);
      expect(find.text('Soon'), findsNWidgets(2));
    });

    testWidgets('the row opens the conversation, and back returns to it',
        (tester) async {
      await _pump(tester, at: Routes.chats, messages: thread);
      await tester.tap(find.text('Call me when you land 💕'));
      await tester.pumpAndSettle();
      // Pushed over the list, not swapped for it: the list is still under.
      expect(find.byType(FlowersScreen), findsOneWidget);
      expect(find.byType(ChatsScreen, skipOffstage: false), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatsScreen), findsOneWidget);
      expect(find.byType(FlowersScreen), findsNothing);
    });

    testWidgets('back from the conversation, what you saw is not unread',
        (tester) async {
      // 🔴 The list stayed bold with a badge after you had read and even
      // answered: it waited for the database to echo the read receipts
      // back, and here, as on a dropped connection, the echo never comes.
      await _pump(tester, at: Routes.chats, messages: thread);
      Finder badge() => find.descendant(
          of: find.byType(ConversationRow), matching: find.text('2'));
      expect(badge(), findsOneWidget);

      await tester.tap(find.text('Call me when you land 💕'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatsScreen), findsOneWidget);
      expect(badge(), findsNothing);
      // Not bold either: the preview is drawn as read.
      final preview =
          tester.widget<Text>(find.text('Call me when you land 💕'));
      expect(preview.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('a chat you spoke last in is never unread', (tester) async {
      // 🔴 Your own last message showed the chat as unread. Here their two
      // messages even still say unseen, as a lagging copy on the phone
      // would: replying is reading, so the row is read anyway.
      await _pump(tester, at: Routes.chats, messages: [
        _text('mine', 'me', 'On my way!', now),
        ...thread.take(2).map((m) => _text(m.id, 'them', m.note!,
            m.sentAt.subtract(const Duration(minutes: 5)),
            seen: false)),
      ]);
      expect(find.text('You: On my way!'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(ConversationRow), matching: find.text('2')),
          findsNothing);
      final preview = tester.widget<Text>(find.text('You: On my way!'));
      expect(preview.style?.fontWeight, FontWeight.w500, reason: 'not bold');
    });

    group('what counts as unread', () {
      Future<int> unread(List<FlowerMessage> messages,
          {String? me = 'me'}) async {
        final container = ProviderContainer(overrides: [
          currentUserIdProvider.overrideWithValue(me),
          flowerMessagesProvider.overrideWith((ref) => Stream.value(messages)),
        ]);
        addTearDown(container.dispose);
        container.listen(unreadMessageCountProvider, (_, __) {});
        await container.read(flowerMessagesProvider.future);
        return container.read(unreadMessageCountProvider);
      }

      final t = DateTime(2026, 9, 24, 12);
      test('only theirs after your latest message', () async {
        expect(
            await unread([
              _text('a', 'them', 'one', t, seen: false),
              _text('b', 'me', 'reply', t.add(const Duration(minutes: 1))),
              _text('c', 'them', 'two', t.add(const Duration(minutes: 2)),
                  seen: false),
            ]),
            1);
      });

      test('nothing while the phone does not know who you are', () async {
        // With no user id your own unseen messages looked like theirs.
        expect(
            await unread([_text('a', 'me', 'hi', t, seen: false)], me: null),
            0);
      });

      test('a My Day photo for the home screen is not unread chat',
          () async {
        final day = FlowerMessage(
            id: 'd',
            pairId: 'pair',
            senderId: 'them',
            imagePath: 'pair/d.jpg',
            sentAt: t,
            toWidget: true,
            toChat: false);
        expect(await unread([day]), 0);
      });
    });

    testWidgets('their face opens their photo, not the conversation',
        (tester) async {
      await _pump(tester, at: Routes.chats, messages: thread);
      await tester.tap(find.bySemanticsLabel('View Wifey’s photo'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byType(FlowersScreen), findsNothing);
    });

    testWidgets('a conversation opened from a notification backs out to it',
        (tester) async {
      // Straight to the conversation, nothing under it: the header's back
      // goes to the list rather than Home.
      await _pump(tester, at: Routes.chat, messages: thread);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatsScreen), findsOneWidget);
      // And the phone's back button agrees.
      expect(backFallbackRoute(Routes.chat), Routes.chats);
      expect(backFallbackRoute(Routes.chatSettings), Routes.chats);
      expect(backFallbackRoute(Routes.chats), Routes.home);
    });

    testWidgets('fits a small phone at large text', (tester) async {
      for (final (width, scale) in [(360.0, 1.0), (320.0, 2.0)]) {
        await _pump(tester,
            at: Routes.chats, messages: thread, width: width, textScale: scale);
        expect(tester.takeException(), isNull, reason: '$width @ $scale');
        await tester.pumpWidget(const SizedBox());
      }
    });

    test('previews and stamps read the way a chat list does', () {
      final at = DateTime(2026, 9, 24, 9, 41);
      expect(conversationStamp(at, now: DateTime(2026, 9, 24, 12)), '9:41 AM');
      expect(conversationStamp(at, now: DateTime(2026, 9, 25, 12)),
          'Yesterday');
      expect(conversationStamp(at, now: DateTime(2026, 9, 28, 12)), 'Thu');
      expect(conversationStamp(at, now: DateTime(2026, 10, 9, 12)), '24 Sep');
      expect(conversationPreview(null, isMine: false), 'Say hello 👋');
      expect(
          conversationPreview(_text('x', 'me', 'hi', at), isMine: true),
          'You: hi');
    });
  });

  group('a reply takes you to what it answers', () {
    final now = DateTime.now();
    // Eighty messages, newest first. The newest answers the very first,
    // which a lazy list has not even built when the thread opens.
    List<FlowerMessage> thread({required String replyTo}) => [
          _text('m0', 'them', 'Remember this?', now, replyTo: replyTo),
          for (var i = 1; i < 80; i++)
            _text('m$i', i.isEven ? 'me' : 'them', 'Message number $i',
                now.subtract(Duration(minutes: i))),
        ];
    Finder bubble(String id) => find.byWidgetPredicate(
        (w) => w is ChatBubble && w.message.id == id,
        description: 'bubble $id');

    testWidgets('scrolls to it, centres it and tints it for a moment',
        (tester) async {
      final boundary = GlobalKey();
      await _pump(tester,
          at: Routes.chat, messages: thread(replyTo: 'm79'), boundary: boundary);
      if (_capture) await _shoot(tester, boundary, 'reply-before');
      expect(bubble('m79'), findsNothing, reason: 'far up, not built yet');

      await tester.tap(find.byType(MessageQuote));
      await tester.pumpAndSettle();

      expect(bubble('m79'), findsOneWidget);
      final rect = tester.getRect(bubble('m79'));
      final screen = tester.getRect(find.byType(FlowersScreen));
      expect(rect.center.dy, inInclusiveRange(screen.top, screen.bottom),
          reason: 'on screen, not merely built');
      // The tint sits behind the bubble, the first thing in its stack.
      Color tint() => ((tester.widget<AnimatedContainer>(find
                      .descendant(
                          of: find
                              .ancestor(
                                  of: bubble('m79'),
                                  matching: find.byType(Stack))
                              .first,
                          matching: find.byType(AnimatedContainer))
                      .first))
                  .decoration! as BoxDecoration)
          .color!;
      expect(tint().a, greaterThan(0), reason: 'tinted on arrival');
      if (_capture) await _shoot(tester, boundary, 'reply-after');

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(tint().a, 0, reason: 'and only for a moment');
      expect(tester.takeException(), isNull);
    });

    testWidgets('says so when what it answered is gone', (tester) async {
      await _pump(tester, at: Routes.chat, messages: thread(replyTo: 'gone'));
      await tester.tap(find.byType(MessageQuote));
      await tester.pump();
      expect(find.text('That message is no longer here'), findsOneWidget);
    });
  });
}

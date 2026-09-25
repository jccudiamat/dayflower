import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/features/calls/data/call_usage.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/presence/data/presence_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/tulip/data/reaction_repository.dart';
import 'package:dayflower/features/tulip/presentation/screens/chat_search_screen.dart';
import 'package:dayflower/features/tulip/presentation/screens/chat_settings_screen.dart';
import 'package:dayflower/features/tulip/presentation/screens/flowers_screen.dart';
import 'package:dayflower/features/tulip/presentation/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Screenshots, opt in:
//   flutter test test/chat_search_test.dart --dart-define=CAPTURE_REVIEW=true
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');

const _wifey = UserProfile(id: 'them', displayName: 'Jamie', petName: 'Wifey');

FlowerMessage _text(String id, String sender, String note, DateTime at) =>
    FlowerMessage(
        id: id,
        pairId: 'pair',
        senderId: sender,
        note: note,
        sentAt: at,
        seenAt: at);

/// Eighty messages, newest first: far more than one screen holds.
List<FlowerMessage> _thread(DateTime now) => [
      for (var i = 0; i < 80; i++)
        _text('m$i', i.isEven ? 'me' : 'them', 'Message number $i',
            now.subtract(Duration(minutes: i))),
    ];

Future<void> _pump(
  WidgetTester tester, {
  required Stream<List<FlowerMessage>> messages,
  GlobalKey? boundary,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: Routes.chat, routes: [
    GoRoute(path: Routes.chat, builder: (_, __) => const FlowersScreen()),
    GoRoute(
        path: Routes.chatSettings,
        builder: (_, __) => const ChatSettingsScreen()),
    GoRoute(
        path: Routes.chatSearch, builder: (_, __) => const ChatSearchScreen()),
    GoRoute(
        path: Routes.chats,
        builder: (_, __) => const Scaffold(body: Text('Chats'))),
  ]);
  addTearDown(router.dispose);
  final now = DateTime.now();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      flowerMessagesProvider.overrideWith((ref) => messages),
      reactionsProvider.overrideWith((ref) => Stream.value({})),
      partnerProfileProvider.overrideWith((ref) async => _wifey),
      partnerProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      partnerLastActiveProvider.overrideWith((ref) async => now),
      callUsageProvider.overrideWith((ref) async => const CallUsage()),
    ],
    child: RepaintBoundary(
      key: boundary,
      child: MaterialApp.router(
        theme: AppTheme.current,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  ));
  await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pumpAndSettle();
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

Finder _bubble(String id) => find.byWidgetPredicate(
    (w) => w is ChatBubble && w.message.id == id,
    description: 'bubble $id');

Finder _arrowSaying(Pattern label) => find.byWidgetPredicate(
    (w) => w is Semantics && (w.properties.label ?? '').contains(label),
    description: 'the arrow down, saying "$label"');

final _arrow = _arrowSaying('newest message');

/// Faded in and taking taps. Always in the tree, so found is not shown.
bool _showing(WidgetTester tester) =>
    tester
        .widget<AnimatedOpacity>(find
            .ancestor(of: _arrow, matching: find.byType(AnimatedOpacity))
            .first)
        .opacity ==
    1;

/// Up through the history, the way a thumb reads back.
Future<void> _readBack(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, 700));
  await tester.pumpAndSettle();
}

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

  group('the way back down', () {
    testWidgets('shows once you read back, and takes you to the newest',
        (tester) async {
      final boundary = GlobalKey();
      await _pump(tester,
          messages: Stream.value(_thread(DateTime.now())), boundary: boundary);
      expect(_showing(tester), isFalse, reason: 'at the newest already');

      await _readBack(tester);
      expect(_bubble('m0'), findsNothing, reason: 'scrolled away from it');
      expect(_showing(tester), isTrue);
      if (_capture) await _shoot(tester, boundary, 'chat-arrow');

      await tester.tap(_arrow);
      await tester.pumpAndSettle();
      expect(_bubble('m0'), findsOneWidget);
      expect(_showing(tester), isFalse, reason: 'gone once you are back');
    });

    testWidgets('counts what of theirs arrived while you were up there',
        (tester) async {
      final boundary = GlobalKey();
      final now = DateTime.now();
      final stream = StreamController<List<FlowerMessage>>();
      addTearDown(stream.close);
      final thread = _thread(now.subtract(const Duration(minutes: 5)));
      stream.add(thread);
      await _pump(tester, messages: stream.stream, boundary: boundary);
      await _readBack(tester);

      stream.add([
        _text('new2', 'them', 'Are you there?', now),
        _text('mine', 'me', 'Sent from my other phone',
            now.subtract(const Duration(seconds: 30))),
        _text('new1', 'them', 'Hello', now.subtract(const Duration(minutes: 1))),
        ...thread,
      ]);
      await tester.pumpAndSettle();
      expect(_arrowSaying('2 new, go to the newest message'), findsOneWidget,
          reason: 'theirs only: your own words are not news to you');
      expect(find.text('2'), findsOneWidget);
      if (_capture) await _shoot(tester, boundary, 'chat-arrow-count');

      await tester.tap(_arrow);
      await tester.pumpAndSettle();
      expect(_bubble('new2'), findsOneWidget);
    });
  });

  group('chat settings', () {
    testWidgets('call, video, message and search sit under their name',
        (tester) async {
      final boundary = GlobalKey();
      await _pump(tester,
          messages: Stream.value(_thread(DateTime.now())), boundary: boundary);
      await tester.tap(find.text('Wifey'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatSettingsScreen), findsOneWidget);
      expect(find.text('Just the two of you'), findsNothing);
      final name = tester.getRect(find.text('Wifey'));
      final labels = ['Call', 'Video', 'Message', 'Search'];
      final tiles = [for (final l in labels) tester.getRect(find.text(l))];
      for (final (i, tile) in tiles.indexed) {
        expect(tile.top, greaterThan(name.bottom), reason: labels[i]);
        expect(tile.center.dy, closeTo(tiles.first.center.dy, 1),
            reason: 'one row');
        if (i > 0) expect(tile.left, greaterThan(tiles[i - 1].right));
      }
      expect(tester.takeException(), isNull);
      if (_capture) await _shoot(tester, boundary, 'chat-settings-actions');
    });

    testWidgets('Message goes back to the chat, ready to write',
        (tester) async {
      await _pump(tester, messages: Stream.value(_thread(DateTime.now())));
      await tester.tap(find.text('Wifey'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatSettingsScreen), findsNothing);
      expect(find.byType(FlowersScreen), findsOneWidget);
      final field = tester.widget<TextField>(find.descendant(
          of: find.byType(FlowersScreen), matching: find.byType(TextField)));
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('Search finds a message, and the chat shows it',
        (tester) async {
      final boundary = GlobalKey();
      await _pump(tester,
          messages: Stream.value(_thread(DateTime.now())), boundary: boundary);
      await tester.tap(find.text('Wifey'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatSearchScreen), findsOneWidget);
      expect(find.text('Find a message by any word in it.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'NUMBER 7');
      await tester.pump();
      // 7, and 70 to 79.
      expect(find.text('11 MESSAGES'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'number 71');
      await tester.pump();
      expect(find.text('1 MESSAGE'), findsOneWidget);
      if (_capture) await _shoot(tester, boundary, 'chat-search');

      await tester.tap(find.text('Wifey'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatSearchScreen), findsNothing);
      expect(find.byType(ChatSettingsScreen), findsNothing);
      expect(_bubble('m71'), findsOneWidget);
      final rect = tester.getRect(_bubble('m71'));
      expect(rect.center.dy, inInclusiveRange(0, 844), reason: 'on screen');
      if (_capture) await _shoot(tester, boundary, 'chat-search-found');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('says so when nothing matches', (tester) async {
      await _pump(tester, messages: Stream.value(_thread(DateTime.now())));
      await tester.tap(find.text('Wifey'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'pineapple');
      await tester.pump();
      expect(find.text('No messages with “pineapple”.'), findsOneWidget);
    });
  });

  group('what search reads', () {
    final at = DateTime(2026, 9, 24, 9, 41);
    test('words on texts, captions and flowers; nothing on a bare photo', () {
      final photo = FlowerMessage(
          id: 'p', pairId: 'pair', senderId: 'me', imagePath: 'x.jpg',
          sentAt: at);
      final captioned = FlowerMessage(
          id: 'c', pairId: 'pair', senderId: 'me', imagePath: 'x.jpg',
          note: 'Beach day', sentAt: at);
      expect(searchableText(photo), isNull);
      expect(searchableText(captioned), 'Beach day');
      expect(searchMessages([photo, captioned], 'beach'), [captioned]);
      expect(searchMessages([photo, captioned], '   '), isEmpty);
    });

    test('a long message is shown from just before the match', () {
      const long = 'We walked for hours along the old harbour wall and then '
          'found the little bakery you told me about';
      final snippet = snippetAround(long, 'bakery');
      expect(snippet, startsWith('…'));
      expect(snippet, contains('bakery'));
      expect(snippetAround('Short and sweet', 'sweet'), 'Short and sweet');
    });

    test('dates carry the year once it is not this one', () {
      expect(searchStamp(at, now: DateTime(2026, 9, 24, 12)), '9:41 AM');
      expect(searchStamp(at, now: DateTime(2026, 10, 9)), '24 Sep');
      expect(searchStamp(at, now: DateTime(2027, 2, 1)), '24 Sep 2026');
    });
  });
}

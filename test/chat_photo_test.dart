import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/core/widgets/storage_image.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/tulip/data/reaction_repository.dart';
import 'package:dayflower/features/tulip/domain/photo_shape.dart';
import 'package:dayflower/features/tulip/presentation/widgets/chat_bubble.dart';
import 'package:dayflower/features/tulip/presentation/widgets/media_viewer.dart';
import 'package:dayflower/features/tulip/presentation/widgets/message_quote.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Screenshot of a loading photo, opt in:
//   flutter test test/chat_photo_test.dart --dart-define=CAPTURE_REVIEW=true
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');

/// A cache that never answers: every photo stays loading, which is the
/// state these tests are about.
class _Loading implements BaseCacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => Completer<Never>().future;
}

const _wifey = UserProfile(id: 'them', displayName: 'Jamie', petName: 'Wifey');

FlowerMessage _photo(String path,
        {String sender = 'them', String? note, bool toWidget = false}) =>
    FlowerMessage(
      id: 'p1',
      pairId: 'pair',
      senderId: sender,
      imagePath: path,
      note: note,
      sentAt: DateTime.now(),
      toWidget: toWidget,
      toChat: true,
    );

Future<void> _pumpBubble(WidgetTester tester, FlowerMessage message,
    {GlobalKey? boundary}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      partnerProfileProvider.overrideWith((ref) async => _wifey),
      reactionsProvider.overrideWith((ref) => Stream.value({})),
      flowerMessagesProvider.overrideWith((ref) => Stream.value([message])),
    ],
    child: RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        theme: AppTheme.current,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              ChatBubble(message: message, isMine: message.senderId == 'me'),
            ]),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
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

  group('a photo\'s shape rides in its path', () {
    test('written before the extension, read back as width over height', () {
      final path = withPhotoShape('pair/abc.jpg', 240, 320);
      expect(path, 'pair/abc_240x320.jpg');
      expect(photoAspectOf(path), closeTo(.75, 1e-9));
      expect(photoAspectOf('pair/strip-abc_320x240.png'), closeTo(4 / 3, 1e-9));
    });

    test('a path from before shapes says nothing', () {
      expect(photoAspectOf('pair/1727000000-123.jpg'), isNull);
      expect(photoAspectOf('pair/abc_0x0.jpg'), isNull);
    });

    testWidgets('measured from the picture itself', (tester) async {
      // A real 300x100 PNG, decoded the way the app decodes a photo.
      final size = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 300, 100),
            Paint()..color = const Color(0xFFEE6FA8));
        final image = await recorder.endRecording().toImage(300, 100);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        return measurePhoto(png!.buffer.asUint8List());
      });
      expect(size, isNotNull);
      expect(size!.$1 / size.$2, closeTo(3, .02));
      // Not an image at all: no shape, and no exception.
      final junk = await tester
          .runAsync(() => measurePhoto(Uint8List.fromList([1, 2, 3])));
      expect(junk, isNull);
    });
  });

  group('the loading box is the photo\'s own box', () {
    late BaseCacheManager previous;
    setUp(() {
      previous = StorageImageCache.manager;
      StorageImageCache.debugManager = _Loading();
    });
    tearDown(() => StorageImageCache.debugManager = previous);

    test('full width for a wide photo, narrower for a tall one', () {
      expect(chatPhotoBox(296, 4 / 3), const Size(296, 222));
      // 3:4 at full width would stand 395 tall, past the 320 ceiling.
      final tall = chatPhotoBox(296, .75);
      expect(tall.height, 320);
      expect(tall.width, 240);
      // Nothing recorded: full width, 4:3.
      expect(chatPhotoBox(296, null), const Size(296, 222));
    });

    for (final (name, path) in [
      ('portrait', 'pair/a_240x320.jpg'),
      ('landscape', 'pair/b_320x240.jpg'),
      ('from before shapes', 'pair/c.jpg'),
    ]) {
      testWidgets('while it loads, a $name photo is not a sliver',
          (tester) async {
        final boundary = GlobalKey();
        await _pumpBubble(tester, _photo(path), boundary: boundary);
        final photo = tester.getSize(find.byType(StorageImage));
        const bubbleWidth = 390 * .76 - 2;
        final expected = chatPhotoBox(bubbleWidth, photoAspectOf(path));
        // 🔴 It had a height and no width: the bubble shrank to the time.
        expect(photo.width, closeTo(expected.width, .5));
        expect(photo.height, closeTo(expected.height, .5));
        expect(tester.takeException(), isNull);
        if (_capture && name == 'portrait') {
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
            final data =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('build/review/photo-loading.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
          });
        }
      });
    }
  });

  group('a photo with nothing written under it is all photo', () {
    late BaseCacheManager previous;
    setUp(() {
      previous = StorageImageCache.manager;
      StorageImageCache.debugManager = _Loading();
    });
    tearDown(() => StorageImageCache.debugManager = previous);

    Finder bubbleBox() => find
        .ancestor(of: find.byType(StorageImage), matching: find.byType(ClipRRect))
        .first;

    testWidgets('no caption: the photo fills the bubble, time on top',
        (tester) async {
      final boundary = GlobalKey();
      await _pumpBubble(tester, _photo('pair/a_320x240.jpg', sender: 'me'),
          boundary: boundary);
      final bubble = tester.getRect(bubbleBox());
      final photo = tester.getRect(find.byType(StorageImage));
      // 🔴 There was a white strip under every photo holding only the time.
      expect(bubble.height, closeTo(photo.height, .5));
      // The time is still there, on the photo, bottom left.
      final time = tester.getRect(find.byWidgetPredicate((w) =>
          w is Text && (w.data ?? '').contains(RegExp(r'\d:\d\d'))));
      expect(photo.contains(time.center), isTrue);
      expect(time.left - photo.left, lessThan(24));
      expect(photo.bottom - time.bottom, lessThan(16));
      if (_capture) {
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/review/photo-no-caption.png')
              .writeAsBytes(data!.buffer.asUint8List());
        });
      }
    });

    testWidgets('a caption keeps its footer, with the time under it',
        (tester) async {
      await _pumpBubble(
          tester, _photo('pair/a_320x240.jpg', note: 'at the beach'));
      final bubble = tester.getRect(bubbleBox());
      final photo = tester.getRect(find.byType(StorageImage));
      expect(find.text('at the beach'), findsOneWidget);
      expect(bubble.height, greaterThan(photo.height + 20));
      final time = tester.getRect(find.byWidgetPredicate((w) =>
          w is Text && (w.data ?? '').contains(RegExp(r'\d:\d\d'))));
      expect(time.top, greaterThan(photo.bottom));
    });
  });

  group('a chat photo is a photo, not a day', () {
    late BaseCacheManager previous;
    setUp(() {
      previous = StorageImageCache.manager;
      StorageImageCache.debugManager = _Loading();
    });
    tearDown(() => StorageImageCache.debugManager = previous);

    Future<(String, String?)> openViewer(
        WidgetTester tester, FlowerMessage message) async {
      await _pumpBubble(tester, message);
      await tester.tap(find.byType(StorageImage));
      // The viewer's photo is loading forever here, so no settling.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final viewer = tester.widget<MediaViewer>(find.byType(MediaViewer));
      return (viewer.title, viewer.subtitle);
    }

    testWidgets('theirs opens under their name and the time', (tester) async {
      final (title, subtitle) = await openViewer(
          tester, _photo('pair/a_240x320.jpg', note: 'at the beach'));
      expect(title, 'Wifey');
      expect(subtitle, startsWith('Today, '));
      expect(find.text('at the beach'), findsWidgets, reason: 'the caption');
      expect(find.text('Their day'), findsNothing);
    });

    testWidgets('yours opens as You', (tester) async {
      final (title, _) =
          await openViewer(tester, _photo('pair/a.jpg', sender: 'me'));
      expect(title, 'You');
    });

    testWidgets('a My Day post is still a day, and says whose',
        (tester) async {
      final (title, _) =
          await openViewer(tester, _photo('pair/a.jpg', toWidget: true));
      expect(title, 'Wifey’s day');
    });

    test('the alert says what was sent', () {
      expect(_photo('p/x.jpg').alertLine, 'Sent a photo 📷');
      expect(_photo('p/x.jpg', toWidget: true).alertLine,
          'Shared their day 📷');
      expect(_photo('p/x.jpg', note: 'at the beach').alertLine,
          '📷  at the beach');
    });

    testWidgets('a quoted photo reads "Photo", once', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          flowerMessagesProvider
              .overrideWith((ref) => Stream.value([_photo('p/x.jpg')])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MessageQuote(replyTo: 'p1', onDark: false)),
        ),
      ));
      await tester.pump();
      expect(find.text('Photo'), findsOneWidget);
      expect(find.textContaining('their day'), findsNothing);
    });

    test('the header time reads like a chat app\'s', () {
      final now = DateTime(2026, 9, 24, 12);
      expect(sentAtLabel(DateTime(2026, 9, 24, 9, 41), now: now),
          'Today, 9:41 AM');
      expect(sentAtLabel(DateTime(2026, 9, 23, 21, 5), now: now),
          'Yesterday, 9:05 PM');
      expect(sentAtLabel(DateTime(2026, 9, 21, 8), now: now),
          'Monday, 8:00 AM');
      expect(sentAtLabel(DateTime(2026, 8, 30, 8), now: now),
          '30 Aug, 8:00 AM');
      expect(sentAtLabel(DateTime(2025, 12, 31, 8), now: now),
          '31 Dec 2025, 8:00 AM');
    });
  });
}

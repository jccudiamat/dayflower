import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_colors.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/core/widgets/profile_photo.dart';
import 'package:dayflower/core/widgets/user_avatar.dart';
import 'package:dayflower/features/chapters/data/chapter_repository.dart';
import 'package:dayflower/features/dates/data/event_repository.dart';
import 'package:dayflower/features/memories/data/memories_assets.dart';
import 'package:dayflower/features/memories/data/memory_views.dart';
import 'package:dayflower/features/memories/data/relationship_memory.dart';
import 'package:dayflower/features/memories/presentation/screens/memories_screen.dart';
import 'package:dayflower/features/memories/presentation/views/all_memories_view.dart';
import 'package:dayflower/features/memories/presentation/views/card_memories_view.dart';
import 'package:dayflower/features/memories/presentation/views/flower_memories_view.dart';
import 'package:dayflower/features/memories/presentation/views/journal_memories_view.dart';
import 'package:dayflower/features/memories/presentation/views/photo_memories_view.dart';
import 'package:dayflower/features/memories/presentation/views/place_memories_view.dart';
import 'package:dayflower/features/memories/presentation/widgets/memory_category_tabs.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/travel/data/map_pin_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Screenshots of every category, opt in:
//   flutter test test/memories_screen_test.dart --dart-define=CAPTURE_REVIEW=true
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');

const _wifey = UserProfile(id: 'them', displayName: 'Jamie', petName: 'Wifey');

FlowerMessage _msg(String id,
        {String sender = 'them',
        String? flower,
        String? path,
        String? note,
        required DateTime at,
        bool toWidget = false}) =>
    FlowerMessage(
      id: id,
      pairId: 'pair',
      senderId: sender,
      flowerType: flower,
      imagePath: path,
      note: note,
      sentAt: at,
      toWidget: toWidget,
      toChat: !toWidget,
    );

final _sep = DateTime(2026, 9, 19, 10);
final _aug = DateTime(2026, 8, 14, 18);

final _messages = [
  _msg('f1', sender: 'me', flower: 'stem_tulip', note: 'Good luck today! ♡',
      at: _sep),
  _msg('f2', flower: 'stem_sunflower', note: 'You make me happy always.',
      at: _sep.subtract(const Duration(days: 1))),
  _msg('f3', flower: 'stem_tulip', at: _aug),
  _msg('f4', flower: 'stem_lily', note: 'Thinking of you.', at: _aug),
  _msg('f5', sender: 'me', flower: 'stem_rose', at: _aug),
  for (var i = 0; i < 6; i++)
    _msg('p$i',
        path: 'pair/p$i${i.isEven ? '_320x240' : ''}.jpg',
        note: i == 0 ? 'Sunset at the beach' : null,
        at: _sep.subtract(Duration(days: 4 + i))),
  _msg('s1', path: 'pair/strip-1.jpg', at: _sep.subtract(const Duration(days: 3))),
  _msg('c1',
      path: 'pair/card-1_240x300.png',
      note: 'Dayflower card · Happy Monthsary\nSo grateful for you ♡',
      at: DateTime(2026, 9, 10)),
  _msg('c2',
      sender: 'me',
      path: 'pair/card-2_300x240.png',
      note: 'Dayflower card · Just Because\nYou make my days brighter',
      at: DateTime(2026, 9, 3)),
  _msg('chat', note: 'just words', at: _sep),
];

final _chapters = [
  MonthlyChapter(
      id: 'aug',
      pairId: 'pair',
      year: 2026,
      month: 8,
      title: 'A slow and happy month',
      closedAt: DateTime(2026, 9, 3)),
  // Still being written: Dayflower's, not a book on the shelf yet.
  const MonthlyChapter(id: 'sep', pairId: 'pair', year: 2026, month: 9),
];

final _goals = [
  for (var i = 0; i < 2; i++)
    MonthlyGoal(
        id: 'g$i',
        pairId: 'pair',
        year: 2026,
        month: 8,
        title: 'Goal $i',
        emoji: '⭐',
        createdBy: 'me'),
];

final _moments = [
  for (var i = 0; i < 3; i++)
    ChapterMoment(
        id: 'm$i',
        pairId: 'pair',
        year: 2026,
        month: 8,
        title: 'Moment $i',
        emoji: '✨',
        createdBy: 'me'),
];

MapPin _pin(String id, String place, double lat, double lon,
        {bool visited = true, String? photo, DateTime? at}) =>
    MapPin(
      id: id,
      pairId: 'pair',
      createdBy: 'me',
      label: 'A day in $place',
      place: place,
      lat: lat,
      lon: lon,
      visited: visited,
      createdAt: at ?? _aug,
      messageId: photo,
    );

final _pins = [
  _pin('a', 'Palawan, Philippines', 9.8, 118.7, photo: 'p0', at: _aug),
  _pin('b', 'Palawan, Philippines', 9.9, 118.8, at: DateTime(2026, 8, 20)),
  _pin('c', 'Dubai, United Arab Emirates', 25.2, 55.27,
      at: DateTime(2026, 9, 1)),
  // A plan, not a memory.
  _pin('d', 'Tokyo, Japan', 35.7, 139.7, visited: false),
];

Future<void> _pump(WidgetTester tester,
    {bool empty = false,
    double width = 390,
    double textScale = 1,
    GlobalKey? boundary}) async {
  AppColors.use(AppMode.light);
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Widget stub(String name) => Scaffold(body: Text(name));
  final router = GoRouter(initialLocation: Routes.memories, routes: [
    GoRoute(
        path: Routes.memories, builder: (_, __) => const MemoriesScreen()),
    GoRoute(path: Routes.photos, builder: (_, __) => stub('All photos')),
    GoRoute(path: Routes.blooms, builder: (_, __) => stub('Garden')),
    GoRoute(path: Routes.chapters, builder: (_, __) => stub('Chapters')),
    GoRoute(path: Routes.chapter, builder: (_, __) => stub('Chapter')),
    GoRoute(
        path: Routes.boothCollection, builder: (_, __) => stub('Prints')),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      partnerProfileProvider.overrideWith((ref) async => _wifey),
      flowerMessagesProvider
          .overrideWith((ref) => Stream.value(empty ? [] : _messages)),
      monthlyChaptersProvider
          .overrideWith((ref) => Stream.value(empty ? [] : _chapters)),
      monthlyGoalsProvider
          .overrideWith((ref) => Stream.value(empty ? [] : _goals)),
      chapterMomentsProvider
          .overrideWith((ref) => Stream.value(empty ? [] : _moments)),
      mapPinsProvider.overrideWith((ref) => Stream.value(empty ? [] : _pins)),
      customEventsProvider.overrideWith((ref) => Stream.value(const [])),
      unreadMessageCountProvider.overrideWithValue(0),
    ],
    child: RepaintBoundary(
      key: boundary,
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
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _choose(WidgetTester tester, String category) async {
  // The row scrolls: at 390 the last chip or two start off the edge. Only
  // the row is scrolled, as a thumb would; ensureVisible would also scroll
  // the page to put the chip at the top.
  final chip = find.descendant(
      of: find.byType(MemoryCategoryTabs),
      matching: find.text(category),
      skipOffstage: false);
  final row = find.descendant(
      of: find.byType(MemoryCategoryTabs), matching: find.byType(Scrollable));
  final screen = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  for (var i = 0; i < 12; i++) {
    final at = tester.getRect(chip);
    if (at.right > screen - 8) {
      await tester.drag(row, const Offset(-80, 0));
    } else if (at.left < 8) {
      await tester.drag(row, const Offset(80, 0));
    } else {
      break;
    }
    await tester.pump();
  }
  await tester.tap(chip);
  await tester.pump();
  // Past the row's own scroll to the chosen chip: a tap on a row still
  // moving only stops it.
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _shoot(WidgetTester tester, GlobalKey key, String name) =>
    tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 1.5);
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
    if (_capture) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => Directory.systemTemp.path);
    }
  });

  testWidgets('a clean header: title, the category\'s line, no avatar',
      (tester) async {
    await _pump(tester);
    expect(find.text('Memories'), findsWidgets);
    for (final category in MemoryCategory.values) {
      await _choose(tester, category.label);
      expect(find.text(category.subtitle), findsOneWidget,
          reason: category.label);
    }
    // 🔴 The reference had a face top right. Nobody's is here.
    expect(find.byType(UserAvatar), findsNothing);
    expect(find.byType(ProfilePhotoButton), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('only All has a search field', (tester) async {
    await _pump(tester);
    expect(find.byType(TextField), findsOneWidget);
    for (final category in MemoryCategory.values.skip(1)) {
      await _choose(tester, category.label);
      expect(find.byType(TextField), findsNothing, reason: category.label);
    }
    await _choose(tester, 'All');
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('All is a timeline of every kind, newest first, searchable',
      (tester) async {
    final boundary = GlobalKey();
    await _pump(tester, boundary: boundary);
    final items =
        tester.widgetList<MemoryTimelineItem>(find.byType(MemoryTimelineItem));
    // Flowers, photos, a strip, cards, a finished chapter, visited places.
    // Not the chat line, and not the planned trip.
    final kinds = items.map((i) => i.memory.kind).toSet();
    expect(kinds, containsAll([
      MemoryKind.flowers,
      MemoryKind.photos,
      MemoryKind.booth,
      MemoryKind.cards,
      MemoryKind.journal,
      MemoryKind.places,
    ]));
    expect(items.any((i) => i.memory.title.contains('Tokyo')), isFalse);
    expect(find.text('You sent a flower'), findsWidgets);
    expect(find.text('“Good luck today! ♡”'), findsOneWidget);
    expect(find.text('You received a card'), findsOneWidget);
    // The chapter shows what was in it.
    expect(find.text('3 highlights · 2 goals'), findsOneWidget);
    if (_capture) await _shoot(tester, boundary, 'memories-all');

    await tester.enterText(find.byType(TextField), 'sunflower');
    await tester.pump();
    expect(find.byType(MemoryTimelineItem), findsOneWidget);
    expect(find.text('Sunflower'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'monthsary');
    await tester.pump();
    expect(find.text('Happy Monthsary'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.textContaining('Nothing matches'), findsOneWidget);
  });

  testWidgets('Photos is a photo wall by month, strips standing tall',
      (tester) async {
    final boundary = GlobalKey();
    await _pump(tester, boundary: boundary);
    await _choose(tester, 'Photos');
    expect(find.byType(MemoryTimelineItem), findsNothing);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('7 moments'), findsOneWidget);
    expect(find.byType(PhotoTile), findsNWidgets(7));
    // Cards are not photos here; they have their own box.
    final tiles = tester.widgetList<PhotoTile>(find.byType(PhotoTile));
    expect(tiles.any((t) => t.message.id.startsWith('c')), isFalse);
    // The strip is taller than it is wide; nothing else is.
    final strip = tiles.firstWhere((t) => t.message.id == 's1');
    expect(strip.height, greaterThan(strip.width * 1.5));
    // Sizes vary: a hero, smaller tiles.
    expect(tiles.map((t) => t.width.round()).toSet().length,
        greaterThan(1));
    // The prints still have a way in.
    expect(find.text('Prints'), findsOneWidget);
    if (_capture) await _shoot(tester, boundary, 'memories-photos');
  });

  testWidgets('Flowers is a garden, with type filters that count',
      (tester) async {
    final boundary = GlobalKey();
    await _pump(tester, boundary: boundary);
    await _choose(tester, 'Flowers');
    expect(find.text('Our Garden'), findsOneWidget);
    expect(find.text('5 flowers grown together'), findsOneWidget);
    expect(find.byType(GardenHero), findsOneWidget);
    expect(find.text('All (5)'), findsOneWidget);
    expect(find.text('Tulips (2)'), findsOneWidget);
    expect(find.byType(FlowerMemoryTile), findsNWidgets(5));
    expect(find.text('From You'), findsWidgets);
    expect(find.text('From Wifey'), findsWidgets);
    if (_capture) await _shoot(tester, boundary, 'memories-flowers');

    await tester.tap(find.text('Tulips (2)'));
    await tester.pump();
    expect(find.byType(FlowerMemoryTile), findsNWidgets(2));
  });

  testWidgets('Cards is a box of cards, each dated underneath',
      (tester) async {
    final boundary = GlobalKey();
    await _pump(tester, boundary: boundary);
    await _choose(tester, 'Cards');
    expect(find.byType(CardMemoryTile), findsNWidgets(2));
    expect(find.text('10 Sep 2026'), findsOneWidget);
    expect(find.text('3 Sep 2026'), findsOneWidget);
    // Each at its own shape: the portrait card is taller than the other.
    final cards =
        tester.widgetList<CardMemoryTile>(find.byType(CardMemoryTile)).toList();
    final portrait = cards.firstWhere((c) => c.card.id == 'c1');
    final landscape = cards.firstWhere((c) => c.card.id == 'c2');
    expect(portrait.height, greaterThan(landscape.height));
    if (_capture) await _shoot(tester, boundary, 'memories-cards');
  });

  testWidgets('Journal is a shelf of finished months', (tester) async {
    final boundary = GlobalKey();
    await _pump(tester, boundary: boundary);
    await _choose(tester, 'Journal');
    expect(find.text('Our Journal'), findsOneWidget);
    // August is done; September is still being written.
    expect(find.byType(JournalBookCover), findsOneWidget);
    // August's own painted cover, with the real counts written on it, on
    // the 2026 shelf.
    expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/images/memories/journal_august.webp'),
        findsOneWidget);
    expect(find.text('2 goals · 3 highlights'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    if (_capture) await _shoot(tester, boundary, 'memories-journal');
    await tester.tap(find.byType(JournalBookCover));
    await tester.pumpAndSettle();
    expect(find.text('Chapter'), findsOneWidget);
  });

  testWidgets('Places is where you have been: a map and a row each',
      (tester) async {
    final boundary = GlobalKey();
    await _pump(tester, boundary: boundary);
    await _choose(tester, 'Places');
    expect(find.byType(PlacesMemoryMap), findsOneWidget);
    // The chosen chip stays in view once the row has scrolled to it.
    await tester.pump(const Duration(milliseconds: 500));
    final chip = tester.getRect(find.descendant(
        of: find.byType(MemoryCategoryTabs), matching: find.text('Places')));
    expect(chip.right, lessThanOrEqualTo(390));
    expect(find.text('2 places together'), findsOneWidget);
    expect(find.byType(PlaceMemoryRow), findsNWidgets(2));
    expect(find.text('Palawan'), findsOneWidget);
    expect(find.text('Philippines'), findsOneWidget);
    expect(find.text('2 stories · 1 photo'), findsOneWidget);
    // History only: nowhere planned, no distance, no live anything.
    expect(find.text('Tokyo'), findsNothing);
    expect(find.textContaining('miles'), findsNothing);
    expect(find.textContaining('km'), findsNothing);
    if (_capture) await _shoot(tester, boundary, 'memories-places');
  });

  testWidgets('each category has its own quiet empty state', (tester) async {
    await _pump(tester, empty: true);
    expect(find.text('Your story will grow here.'), findsOneWidget);
    for (final category in MemoryCategory.values.skip(1)) {
      await _choose(tester, category.label);
      expect(find.text(category.emptyTitle), findsOneWidget,
          reason: category.label);
    }
  });

  testWidgets('every category fits a small phone at large text',
      (tester) async {
    for (final (width, scale) in [(360.0, 1.0), (320.0, 2.0)]) {
      await _pump(tester, width: width, textScale: scale);
      for (final category in MemoryCategory.values) {
        await _choose(tester, category.label);
        expect(tester.takeException(), isNull,
            reason: '${category.label} $width @ $scale');
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  test('every piece of Memories artwork is in the bundle', () {
    // The garden, the three thumbnails and a cover for every month. A
    // missing file would fall back quietly; this says so out loud.
    for (final path in [
      MemoriesAssets.gardenHero,
      MemoriesAssets.timelineJournal,
      MemoriesAssets.timelineCard,
      MemoriesAssets.timelineBouquet,
      for (var m = 1; m <= 12; m++) MemoriesAssets.cover(m),
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    // Each cover's line sits inside the cover.
    for (final (at, _) in MemoriesAssets.coverLabels) {
      expect(at, inInclusiveRange(.1, .95));
    }
  });

  group('the helpers', () {
    test('flower families are counted and named', () {
      final flowers = [for (final m in _messages) if (m.flower != null) m];
      final families = flowerFamilies(flowers);
      expect(families.first, ('Tulips', 2));
      expect(families.map((f) => f.$1),
          containsAll(['Sunflowers', 'Lilies', 'Roses']));
    });

    test('the photo wall leads with a hero and stands strips tall', () {
      final photos = [
        for (final m in _messages)
          if (m.isPhoto && !m.isCard) m,
      ];
      final blocks = mosaicBlocks(photos, (m) => m.id == 's1');
      expect(blocks.first, isA<HeroBlock>());
      expect(blocks.whereType<StripBlock>(), hasLength(1));
      final placed = [
        for (final b in blocks)
          ...switch (b) {
            HeroBlock(:final big, :final small) => [big, ...small],
            StripBlock(:final strip, :final others) => [strip, ...others],
            RowBlock(:final photos) => photos,
          },
      ];
      expect(placed.length, photos.length, reason: 'every photo, once');
    });

    test('masonry keeps columns level', () {
      final columns = masonryColumns([300, 100, 100, 100], 2);
      expect(columns[0], [0]);
      expect(columns[1], [1, 2, 3]);
    });

    test('places are visited pins, one row per place', () {
      final places = placeMemories(_pins);
      expect(places.map((p) => p.name), ['Dubai', 'Palawan']);
      expect(placeMemories(_pins, sort: PlaceSort.most).first.name, 'Palawan');
      expect(placeMemories(_pins, sort: PlaceSort.name).first.name, 'Dubai');
    });

    test('only finished months are books', () {
      final books = journalBooks(_chapters, _goals, _moments);
      expect(books, hasLength(1));
      expect(books.single.goals, 2);
      expect(books.single.highlights, 3);
    });

    test('search reads titles, notes, flowers and dates', () {
      final memories = buildRelationshipMemories(
          messages: _messages, chapters: _chapters, moments: [], places: []);
      List<String> ids(String q) =>
          [for (final m in memories) if (memoryMatches(m, q)) m.id];
      expect(ids('good luck'), ['message:f1']);
      expect(ids('lily'), ['message:f4']);
      expect(ids('19 september'), contains('message:f1'));
      expect(ids(''), hasLength(memories.length));
    });
  });
}

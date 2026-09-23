import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/models/pair.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_colors.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/features/activities/data/together_assets.dart';
import 'package:dayflower/features/activities/data/together_mock_data.dart';
import 'package:dayflower/features/activities/data/together_next_up.dart';
import 'package:dayflower/features/activities/presentation/screens/activities_screen.dart';
import 'package:dayflower/features/activities/presentation/widgets/together_art.dart';
import 'package:dayflower/features/activities/presentation/widgets/together_events_card.dart';
import 'package:dayflower/features/activities/presentation/widgets/together_gifts_card.dart';
import 'package:dayflower/features/activities/presentation/widgets/together_hero_card.dart';
import 'package:dayflower/features/activities/presentation/widgets/together_map_card.dart';
import 'package:dayflower/features/activities/presentation/widgets/together_reminders_card.dart'
    as reminder_card;
import 'package:dayflower/features/activities/presentation/widgets/together_reminders_card.dart'
    show TogetherRemindersCard;
import 'package:dayflower/features/activities/presentation/widgets/together_savings_card.dart';
import 'package:dayflower/features/activity/data/activity_repository.dart';
import 'package:dayflower/features/dates/data/event_repository.dart';
import 'package:dayflower/features/finance/data/finance_repository.dart';
import 'package:dayflower/features/gifts/data/gift_favorites_repository.dart';
import 'package:dayflower/features/home/domain/home_moments.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/pairing/data/pair_repository.dart';
import 'package:dayflower/features/reminders/data/reminder_repository.dart';
import 'package:dayflower/features/reunion/data/reunion_repository.dart';
import 'package:dayflower/features/travel/data/map_pin_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/trust_fakes.dart';

// Offline only. Screenshots are opt-in review artifacts:
//   flutter test test/together_screen_test.dart --dart-define=CAPTURE_REVIEW=true
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');
var _boundary = GlobalKey();

/// The day the mockup was drawn on: 29 days to a monthsary on the 19th,
/// 48 to a reunion on 7 November.
final _today = DateTime(2026, 9, 20, 10);

/// Tall enough to hold the whole tab, so one screenshot shows the bento.
const _fullHeight = 1900.0;

Reminder _reminder(String id, String title, String emoji, DateTime at,
        {String forUser = 'preview-a'}) =>
    Reminder(
      id: id,
      pairId: 'preview',
      createdBy: 'preview-b',
      forUser: forUser,
      title: title,
      emoji: emoji,
      remindAt: at,
      repeat: ReminderRepeat.none,
    );

Future<GoRouter> _pump(
  WidgetTester tester, {
  double width = 390,
  double height = _fullHeight,
  double textScale = 1,
  bool empty = false,
}) async {
  _boundary = GlobalKey();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  Widget stub(String name) => Scaffold(body: Text('$name destination'));
  final router = GoRouter(initialLocation: Routes.together, routes: [
    GoRoute(
        path: Routes.together, builder: (_, __) => const ActivitiesScreen()),
    for (final (path, name) in [
      (Routes.events, 'Events'),
      (Routes.us, 'Us'),
      (Routes.travel, 'Map'),
      (Routes.notifications, 'Notifications'),
      (Routes.gifts, 'Gifts'),
      (Routes.reminders, 'Reminders'),
      (Routes.finance, 'Finance'),
    ])
      GoRoute(path: path, builder: (_, __) => stub(name)),
  ]);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  final favorites = MemoryFavorites();
  if (!empty) favorites.rows['preview-a'] = {'bouquet', 'necklace'};

  await tester.pumpWidget(ProviderScope(
    overrides: [
      homeClockProvider.overrideWith((ref) => Stream.value(_today)),
      currentUserIdProvider.overrideWithValue('preview-a'),
      currentPairProvider.overrideWith((ref) async => Pair(
            id: 'preview',
            userA: 'preview-a',
            userB: 'preview-b',
            inviteCode: 'PREVIEW',
            togetherSince: empty ? null : DateTime(2024, 3, 19),
          )),
      userProfileProvider.overrideWith((ref) async => UserProfile(
            id: 'preview-a',
            displayName: 'Alex',
            timezone: 'Asia/Dubai',
            city: empty ? null : 'Dubai, UAE',
            cityLat: empty ? null : 25.2048,
            cityLon: empty ? null : 55.2708,
          )),
      partnerProfileProvider.overrideWith((ref) async => UserProfile(
            id: 'preview-b',
            displayName: 'Jamie',
            timezone: 'Asia/Manila',
            city: empty ? null : 'Manila, Philippines',
            cityLat: empty ? null : 14.5995,
            cityLon: empty ? null : 120.9842,
          )),
      reunionProvider.overrideWith((ref) => Stream.value(empty
          ? null
          : Reunion(
              id: 'r1',
              pairId: 'preview',
              title: 'Reunion',
              destination: 'Manila, Philippines',
              happensAt: DateTime(2026, 11, 7, 12),
            ))),
      customEventsProvider.overrideWith((ref) => Stream.value(empty
          ? const []
          : const [
              {
                'id': 1,
                'kind': 'custom',
                'title': 'Date night',
                'date': '2026-12-12'
              },
              {
                'id': 2,
                'kind': 'custom',
                'title': 'Concert',
                'date': '2027-01-20'
              },
            ])),
      mapPinsProvider.overrideWith((ref) => Stream.value(empty
          ? const []
          : [
              MapPin(
                id: 'p1',
                pairId: 'preview',
                createdBy: 'preview-a',
                label: 'Beach day',
                place: 'El Nido, Philippines',
                lat: 11.2,
                lon: 119.4,
                visited: false,
                createdAt: DateTime(2026, 8, 1),
              ),
              MapPin(
                id: 'p2',
                pairId: 'preview',
                createdBy: 'preview-b',
                label: 'Palawan',
                place: 'Palawan, Philippines',
                lat: 9.8,
                lon: 118.7,
                visited: false,
                createdAt: DateTime(2026, 9, 1),
              ),
            ])),
      giftFavoritesRepositoryProvider.overrideWithValue(favorites),
      remindersProvider.overrideWith((ref) => Stream.value(empty
          ? const []
          : [
              _reminder(
                  'm1', 'Water the plants', '🌿', DateTime(2026, 9, 20, 8)),
              _reminder(
                  'm2', 'Call before bed', '📞', DateTime(2026, 9, 20, 21),
                  forUser: 'preview-b'),
              _reminder(
                  'm3', 'Book the flights', '✈️', DateTime(2026, 9, 22, 9)),
              _reminder(
                  'm4', 'Send the parcel', '📦', DateTime(2026, 10, 3, 9)),
            ])),
      financeGoalsProvider.overrideWith((ref) => Stream.value(empty
          ? const []
          : const [
              FinanceGoal(
                id: 'g1',
                pairId: 'preview',
                name: 'Palawan trip',
                emoji: '🏝️',
                targetAmount: 30000,
                savedAmount: 18500,
                currency: 'PHP',
                archived: false,
                createdBy: 'preview-a',
              ),
            ])),
      financeAccountsProvider.overrideWith((ref) => Stream.value(const [])),
      financeEntriesProvider.overrideWith((ref) => Stream.value(const [])),
      financeRatesProvider.overrideWith((ref) => Stream.value(FxTable.empty)),
      unseenActivityCountProvider.overrideWithValue(0),
    ],
    child: RepaintBoundary(
        key: _boundary,
        child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.current,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
            routerConfig: router)),
  ));
  await tester.pumpAndSettle();
  // Real decoding happens off the fake clock; without this every picture
  // is still blank when the screenshot is taken.
  final context = tester.element(find.byType(ActivitiesScreen));
  await tester.runAsync(() async {
    for (final path in TogetherAssets.all) {
      if (TogetherAssets.awaitingArt.contains(path)) continue;
      await precacheImage(AssetImage(path), context);
    }
  });
  await tester.pumpAndSettle();
  return router;
}

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  // flutter_test paints every BoxShadow as a hard-edged block unless told
  // otherwise, which makes soft cards look like they have a second card
  // stuck under them. The phone blurs; the review image should too.
  // ⚠️ Put back inside this function, not in a tearDown: the binding
  // checks the painting flags before any tearDown runs.
  debugDisableShadows = false;
  try {
    tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = _boundary.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/review/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = true;
  }
}

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
    // The phone falls back to its system fonts for what TikTok Sans lacks —
    // emoji, ₱, ♡. The test renderer has no system fonts, so the review
    // images borrow Windows' ones rather than show empty boxes.
    // ⚠️ Segoe UI Emoji and Segoe UI are left out: registered into the
    // family they claimed ₱ as well, and drew it as an empty box, though
    // TikTok Sans has its own. Segoe UI Symbol carries ♡ and the emoji in
    // monochrome, which is enough to check a layout.
    for (final path in [
      'C:/Windows/Fonts/seguisym.ttf',
    ]) {
      final file = File(path);
      if (!_capture || !await file.exists()) continue;
      await (FontLoader('TikTokSans')
            ..addFont(file.readAsBytes().then((b) => ByteData.sublistView(b))))
          .load();
    }
  });
  tearDown(() => AppColors.use(AppMode.light));

  testWidgets('every card reads real data, on any phone width', (tester) async {
    for (final width in [412.0, 390.0, 360.0, 320.0]) {
      await _pump(tester, width: width);
      final narrow = width - 2 * 16 < 340;

      // Hero.
      expect(find.text('29 days until our monthsary'), findsOneWidget);
      expect(find.textContaining(narrow ? '7 Nov 2026' : '7 November 2026'),
          findsOneWidget);
      expect(find.text('Next trip: Palawan'), findsOneWidget);

      // Events: the same five days the hero and Home count, three shown.
      expect(find.text('5 coming up'), findsOneWidget);
      expect(find.text('Our monthsary'), findsOneWidget);
      expect(find.text('19 Oct'), findsOneWidget);
      expect(find.text('+2 more'), findsOneWidget);

      // Gifts: my saved ideas.
      expect(find.text('2 ideas saved'), findsOneWidget);

      // Map: the real distance, both cities, west on the left.
      expect(find.textContaining('miles apart'), findsOneWidget);
      expect(tester.getCenter(find.text('Dubai')).dx,
          lessThan(tester.getCenter(find.text('Manila')).dx));

      // Reminders, in the slot the mockup gave goals.
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('Water the plants'), findsOneWidget);
      expect(find.text('Shared Goals'), findsNothing);

      // Savings: the shared goal, in its own currency.
      expect(find.text('₱18,500'), findsOneWidget);
      expect(find.text('of ₱30,000'), findsOneWidget);
      expect(find.text('Palawan trip'), findsOneWidget);

      // Play: the mock tiles.
      for (final tile in playTogetherTiles) {
        expect(find.text(tile.title), findsOneWidget);
      }

      // An overflow is a thrown exception in a test; none at any width.
      expect(tester.takeException(), isNull, reason: '$width');
      await _screenshot(tester, 'together-${width.round()}');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('two columns at 360, stacked at 320', (tester) async {
    Future<bool> sideBySide(double width) async {
      await _pump(tester, width: width);
      final events = tester.getRect(find.byType(TogetherEventsCard));
      final gifts = tester.getRect(find.byType(TogetherGiftsCard));
      await tester.pumpWidget(const SizedBox());
      return gifts.left > events.right && gifts.top == events.top;
    }

    expect(await sideBySide(390), isTrue);
    expect(await sideBySide(360), isTrue);
    expect(await sideBySide(320), isFalse);
  });

  testWidgets('a bento row keeps both cards the same height', (tester) async {
    await _pump(tester);
    expect(tester.getSize(find.byType(TogetherGiftsCard)).height,
        tester.getSize(find.byType(TogetherEventsCard)).height);
  });

  testWidgets('and no taller than the taller card needs', (tester) async {
    // 🔴 Held because it broke: a shrink-to-fit title reported the height
    // it would have had wrapped, and the whole row grew a blank strip.
    // The card with the most to say must end just below its last line.
    for (final width in [390.0, 360.0]) {
      await _pump(tester, width: width);
      final card = tester.getRect(find.byType(TogetherRemindersCard));
      final last = tester.getRect(find.text('+1 more'));
      final savings = tester.getRect(find.byType(TogetherSavingsCard));
      final chip = tester.getRect(find.textContaining('Small steps'));
      // Whichever card is taller by content sets the row; its last line
      // sits within the padding of the bottom edge.
      final slack = [card.bottom - last.bottom, savings.bottom - chip.bottom]
          .reduce((a, b) => a < b ? a : b);
      expect(slack, lessThan(30), reason: '$width');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('it survives 200% text on the narrowest phone', (tester) async {
    await _pump(tester, width: 320, height: 4000, textScale: 2);
    expect(find.text('View our plans'), findsOneWidget);
    final title = tester.renderObject<RenderParagraph>(
        find.text('29 days until our monthsary'));
    expect(title.didExceedMaxLines, isFalse);
    // The hero's picture gives its room to the words.
    expect(
        find.descendant(
            of: find.byType(TogetherHeroCard),
            matching: find.byType(TogetherArt)),
        findsNothing);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'together-320-large-text');
  });

  testWidgets('it follows dark mode', (tester) async {
    AppColors.use(AppMode.dark);
    await _pump(tester);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'together-dark');
  });

  testWidgets('nothing set yet says so, and says where to set it',
      (tester) async {
    await _pump(tester, width: 360, empty: true);
    expect(find.text('When did it all begin?'), findsOneWidget);
    expect(find.text('No reunion planned yet'), findsOneWidget);
    expect(find.text('Where to next?'), findsOneWidget);
    expect(find.text('No ideas saved yet'), findsOneWidget);
    expect(find.text('Add your cities'), findsOneWidget);
    expect(find.text('Nothing pending'), findsOneWidget);
    expect(find.text('Start a goal'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'together-empty');

    await tester.tap(find.text('When did it all begin?'));
    await tester.pumpAndSettle();
    expect(find.text('Us destination'), findsOneWidget);
  });

  testWidgets('every card goes where what it shows is kept', (tester) async {
    final semantics = tester.ensureSemantics();
    final router = await _pump(tester);
    for (final (text, destination) in [
      ('View our plans', 'Events destination'),
      ('48 days until reunion', 'Events destination'),
      ('Next trip: Palawan', 'Map destination'),
      ('5 coming up', 'Events destination'),
      ('View ideas', 'Gifts destination'),
      ('Open map', 'Map destination'),
      ('Water the plants', 'Reminders destination'),
      ('₱18,500', 'Finance destination'),
    ]) {
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
      expect(find.text(destination), findsOneWidget, reason: text);
      router.pop();
      await tester.pumpAndSettle();
    }

    // Play Together has nowhere to go yet, and says so.
    await tester.tap(find.text('Music'));
    await tester.pump();
    expect(find.text('Music is coming soon.'), findsOneWidget);

    // No bell and no avatar on this tab: both live on Home's top bar.
    expect(find.byTooltip('Notifications'), findsNothing);
    expect(find.bySemanticsLabel('Us, your couple page'), findsNothing);
    semantics.dispose();
  });

  group('the calendar', () {
    test('prints the month it is, not the one it was drawn in', () {
      expect(TogetherCalendarArt.labelFor(DateTime(2026, 10, 3)), 'OCT');
      expect(TogetherCalendarArt.labelFor(DateTime(2026, 11, 30)), 'NOV');
      expect(TogetherCalendarArt.labelFor(DateTime(2027, 5, 1)), 'MAY');
    });

    testWidgets('on the card, it follows the clock', (tester) async {
      await _pump(tester);
      expect(find.text('SEP'), findsOneWidget);
      expect(find.text('OCT'), findsNothing);
    });
  });

  test('reminders say when in calendar days', () {
    final now = DateTime(2026, 9, 20, 22);
    // intl puts a narrow no-break space before AM/PM, so a time never
    // breaks across lines; compared here as a plain space.
    String whenLabel(DateTime at, DateTime now) =>
        reminder_card.whenLabel(at, now).replaceAll(' ', ' ');
    expect(whenLabel(DateTime(2026, 9, 20, 8), now), 'Overdue');
    expect(whenLabel(DateTime(2026, 9, 20, 23, 30), now), 'Today, 11:30 PM');
    // Three hours away, but tomorrow — the day is what people plan by.
    expect(whenLabel(DateTime(2026, 9, 21, 1), now), 'Tomorrow, 1 AM');
    expect(whenLabel(DateTime(2026, 9, 24, 9), now), 'Thu, 9 AM');
    expect(whenLabel(DateTime(2026, 10, 3, 9), now), '3 Oct');
  });

  test('the plane sits on the line, halfway along it', () {
    const painter = TogetherRoutePainter(
        from: Offset(20, 80), to: Offset(200, 90), color: Colors.black);
    final metric = painter.path.computeMetrics().first;
    final middle = metric.getTangentForOffset(metric.length / 2)!;
    // Bowed upward: the middle of the flight is above both ends.
    expect(middle.position.dy, lessThan(80));
    expect(middle.position.dx, closeTo(110, 12));
  });

  test('a place name keeps the place and drops the country', () {
    expect(placeName('Palawan, Philippines'), 'Palawan');
    expect(placeName('Dubai'), 'Dubai');
    expect(placeName('  , Somewhere'), ', Somewhere');
  });

  group('illustrations', () {
    test('every path lives in the folder pubspec registers', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/images/together/'));
      for (final path in TogetherAssets.all) {
        expect(path, startsWith('assets/images/together/'));
        expect(path, matches(RegExp(r'\.(png|webp)$')));
      }
      expect(TogetherAssets.all.toSet(), hasLength(TogetherAssets.all.length));
    });

    test('every file not awaiting art is really there', () {
      // 🔴 A typo in a path would otherwise show a placeholder forever and
      // look exactly like art that has not arrived yet.
      for (final path in TogetherAssets.all) {
        final awaiting = TogetherAssets.awaitingArt.contains(path);
        expect(File(path).existsSync(), !awaiting, reason: path);
      }
    });

    test('what ships stays small', () {
      // The APK is under 1 MB from the 50 MB the updater can publish.
      var total = 0;
      for (final path in TogetherAssets.all) {
        final file = File(path);
        if (file.existsSync()) total += file.lengthSync();
      }
      expect(total, lessThan(400 * 1024));
    });

    testWidgets('a missing file draws a placeholder, not an error',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Center(
          child: TogetherArt(
            'assets/images/together/definitely_missing.png',
            fallbackIcon: Icons.card_giftcard_rounded,
            width: 120,
            height: 120,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

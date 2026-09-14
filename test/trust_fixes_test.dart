import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/models/pair.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/services/legal_links.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/features/auth/data/auth_repository.dart';
import 'package:dayflower/features/auth/presentation/screens/login_screen.dart';
import 'package:dayflower/features/booth/data/strip_repository.dart';
import 'package:dayflower/features/booth/domain/strip_templates.dart';
import 'package:dayflower/features/booth/presentation/screens/booth_screen.dart';
import 'package:dayflower/features/dates/data/event_repository.dart';
import 'package:dayflower/features/dates/presentation/screens/events_screen.dart';
import 'package:dayflower/features/gifts/data/gift_favorites_repository.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/pairing/data/pair_repository.dart';
import 'package:dayflower/features/reunion/data/reunion_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'support/trust_fakes.dart';

class RecordingStrips extends StripRepository {
  RecordingStrips()
      : super(offlineClient(),
            FlowerRepository(offlineClient()));
  int solos = 0, starts = 0, joins = 0;
  bool fail = false;
  Uint8List? received;
  @override
  Future<void> postSolo(
      {required String pairId,
      required String senderId,
      required StripTemplate template,
      required Uint8List bytes}) async {
    if (fail) throw StateError('Offline');
    solos++;
    received = bytes;
  }

  @override
  Future<PhotoStrip> startDuo(
      {required String pairId,
      required String senderId,
      required StripTemplate template,
      required Uint8List bytes}) async {
    if (fail) throw StateError('Offline');
    starts++;
    received = bytes;
    return PhotoStrip(
        id: 'new',
        pairId: pairId,
        template: template.id,
        aUser: senderId,
        aPath: 'pair/half.jpg',
        createdAt: DateTime(2026));
  }

  @override
  Future<void> joinDuo(
      {required PhotoStrip strip,
      required String senderId,
      required Uint8List bytes}) async {
    if (fail) throw StateError('Offline');
    joins++;
    received = bytes;
  }
}

Future<void> pumpScreen(
    WidgetTester tester, Widget screen, List<Override> overrides) async {
  tester.view.physicalSize = const Size(390, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: Routes.booth, routes: [
    GoRoute(path: Routes.booth, builder: (_, __) => screen),
    GoRoute(
        path: Routes.activities,
        builder: (_, __) => const Scaffold(body: Text('Activities'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    currentUserIdProvider.overrideWithValue('a'),
    currentPairProvider.overrideWith((ref) async =>
        const Pair(id: 'pair', userA: 'a', userB: 'b', inviteCode: 'ABCDEF')),
    userProfileProvider.overrideWith(
        (ref) async => const UserProfile(id: 'a', displayName: 'Alex')),
    partnerProfileProvider.overrideWith(
        (ref) async => const UserProfile(id: 'b', displayName: 'Jamie')),
    unreadMessageCountProvider.overrideWithValue(0),
    reunionProvider.overrideWith((ref) => Stream.value(null)),
    openStripsProvider.overrideWith((ref) => Stream.value([])),
    flowerMessagesProvider.overrideWith((ref) => Stream.value([])),
    ...overrides,
  ], child: MaterialApp.router(theme: AppTheme.current, routerConfig: router)));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('TikTokSans')..addFont(rootBundle.load('assets/fonts/tiktok/TikTokSans.ttf'))).load();
  });
  test(
      'favorites survive provider recreation, are account scoped, and retain state on failure',
      () async {
    final repo = MemoryFavorites();
    ProviderContainer container(String user) => ProviderContainer(overrides: [
          currentUserIdProvider.overrideWithValue(user),
          giftFavoritesRepositoryProvider.overrideWithValue(repo),
        ]);
    var c = container('a');
    var sub = c.listen(giftFavoritesProvider, (_, __) {});
    await c.read(giftFavoritesProvider.future);
    await c.read(giftFavoritesProvider.notifier).toggle('couple-mugs');
    sub.close();
    c.dispose();
    c = container('a');
    sub = c.listen(giftFavoritesProvider, (_, __) {});
    expect(await c.read(giftFavoritesProvider.future), {'couple-mugs'});
    repo.failWrites = true;
    await expectLater(
        c.read(giftFavoritesProvider.notifier).toggle('couple-mugs'),
        throwsStateError);
    expect(c.read(giftFavoritesProvider).requireValue, {'couple-mugs'});
    repo.failWrites = false;
    await c.read(giftFavoritesProvider.notifier).toggle('couple-mugs');
    expect(await repo.load('a'), isEmpty);
    sub.close();
    c.dispose();
    c = container('b');
    expect(await c.read(giftFavoritesProvider.future), isEmpty);
    c.dispose();
  });

  testWidgets('events save, reopen, edit, delete, and preserve a failed draft',
      (tester) async {
    final repo = MemoryEvents();
    Future<void> open() => pumpScreen(tester, const EventsScreen(),
        [eventRepositoryProvider.overrideWithValue(repo)]);
    await open();
    await tapVisible(tester, find.text('Add event'));
    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Tokyo Reunion'), 'Our picnic');
    await tapVisible(tester, find.text('Select date'));
    await tapVisible(tester, find.text('OK'));
    repo.failWrites = true;
    await tapVisible(tester, find.text('Save'));
    expect(find.textContaining('Your draft is still here'), findsOneWidget);
    expect(find.text('Our picnic'), findsOneWidget);
    expect(repo.rows, isEmpty);
    repo.failWrites = false;
    await tapVisible(tester, find.text('Save'));
    expect(repo.rows['pair']!.values.single['title'], 'Our picnic');
    await tester.pumpWidget(const SizedBox());
    await open();
    expect(find.text('Our picnic'), findsOneWidget);
    await tapVisible(tester, find.text('Edit'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Our picnic'), 'Our weekend picnic');
    await tapVisible(tester, find.text('Save'));
    await tester.pumpWidget(const SizedBox());
    await open();
    expect(find.text('Our weekend picnic'), findsOneWidget);
    await tapVisible(tester, find.text('Edit'));
    await tapVisible(tester, find.text('Delete'));
    await tester.pumpWidget(const SizedBox());
    await open();
    expect(find.text('Our weekend picnic'), findsNothing);
    expect(repo.rows['pair'], isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'login exposes email and working policy links, without placeholder providers',
      (tester) async {
    final urls = <Uri>[];
    await pumpScreen(tester, const LoginScreen(), [
      authRepositoryProvider.overrideWithValue(
          AuthRepository(offlineClient())),
      legalLinkLauncherProvider.overrideWithValue((uri) async {
        urls.add(uri);
        return true;
      }),
    ]);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.textContaining('Continue with'), findsNothing);
    await tapVisible(tester, find.text('Terms of Service'));
    await tapVisible(tester, find.text('Privacy Policy'));
    expect(urls.map((u) => u.toString()),
        ['https://mydayflower.com/terms', 'https://mydayflower.com/privacy']);
    await tapVisible(tester, find.text('Create an account'));
    expect(find.textContaining('Continue with'), findsNothing);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('legal launcher failures report an error and permit retry',
      (tester) async {
    var calls = 0;
    await pumpScreen(
        tester,
        Consumer(
            builder: (context, ref, _) => Scaffold(
                body: TextButton(
                    onPressed: () =>
                        openLegalPage(context, ref, LegalPage.privacy),
                    child: const Text('Open policy')))),
        [
          legalLinkLauncherProvider.overrideWithValue((_) async {
            calls++;
            return calls > 1;
          }),
        ]);
    await tapVisible(tester, find.text('Open policy'));
    expect(find.text('Could not open Privacy Policy. Please try again.'),
        findsOneWidget);
    await tapVisible(tester, find.text('Retry'));
    expect(calls, 2);
  });

  test('photo normalization rejects invalid images and writes JPEG bytes', () {
    final png =
        Uint8List.fromList(img.encodePng(img.Image(width: 12, height: 15)));
    final jpeg = normalizeBoothPhoto(png);
    expect(jpeg.take(2), [255, 216]);
    expect(img.decodeJpg(jpeg)!.height, 15);
    expect(() => normalizeBoothPhoto(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
  });

  testWidgets('booth joins the selected partner strip and does not start another one', (tester) async {
    final repo = RecordingStrips();
    final photo = Uint8List.fromList(img.encodePng(img.Image(width: 30, height: 40)));
    final invite = PhotoStrip(id: 'invite', pairId: 'pair', template: 'classic', aUser: 'b', aPath: 'pair/partner.jpg', createdAt: DateTime(2026));
    await pumpScreen(tester, const BoothScreen(), [
      stripRepositoryProvider.overrideWithValue(repo),
      boothPhotoPickerProvider.overrideWithValue((_) async => photo),
      openStripsProvider.overrideWith((ref) => Stream.value([invite])),
      dayPhotoUrlProvider.overrideWith((ref, path) async => null),
    ]);
    await tapVisible(tester, find.text('Join this strip'));
    await tapVisible(tester, find.text('Upload photo'));
    await tapVisible(tester, find.text('Add my half & share'));
    expect(repo.joins, 1);
    expect(repo.starts, 0);
    expect(repo.solos, 0);
    expect(repo.received, photo);
  });

  testWidgets('canceling the image picker does not invent a selected photo', (tester) async {
    await pumpScreen(tester, const BoothScreen(), [
      boothPhotoPickerProvider.overrideWithValue((_) async => null),
    ]);
    await tapVisible(tester, find.text('Upload photo'));
    expect(find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage), findsNothing);
    final submit = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save my half for Jamie'));
    expect(submit.onPressed, isNull);
  });

  for (final duo in [false, true]) {
    testWidgets(
        'booth picks real bytes and submits ${duo ? 'couple' : 'solo'} through the strip repository',
        (tester) async {
      final repo = RecordingStrips();
      final photo =
          Uint8List.fromList(img.encodePng(img.Image(width: 30, height: 40)));
      await pumpScreen(tester, const BoothScreen(), [
        stripRepositoryProvider.overrideWithValue(repo),
        boothPhotoPickerProvider.overrideWithValue((_) async => photo),
      ]);
      expect(find.text('Alex & Jamie'), findsOneWidget);
      expect(find.textContaining('Bunny'), findsNothing);
      expect(find.textContaining('Sunshine'), findsNothing);
      if (!duo) await tapVisible(tester, find.text('Solo'));
      await tapVisible(tester, find.text('Upload photo'));
      expect(
          find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
          findsOneWidget);
      final action =
          find.text(duo ? 'Save my half for Jamie' : 'Create & share strip');
      repo.fail = true;
      await tapVisible(tester, action);
      expect(find.textContaining('Your photo is still here'), findsOneWidget);
      expect(
          find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
          findsOneWidget);
      repo.fail = false;
      await tapVisible(tester, action);
      expect(duo ? repo.starts : repo.solos, 1);
      expect(repo.received, photo);
      expect(
          find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
          findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

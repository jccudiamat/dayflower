import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/models/avatar_character.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/core/widgets/character_avatar.dart';
import 'package:dayflower/core/widgets/flower_avatar.dart';
import 'package:dayflower/core/widgets/user_avatar.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/trust_fakes.dart';

/// A drawn boy or girl stands in for anyone without a photo: chosen at
/// sign-up, since the app knows nothing about who is which.

class _Created extends UserRepository {
  _Created() : super(offlineClient());
  AvatarCharacter? character;
  String? name;
  String? gender;

  @override
  Future<UserProfile> createProfile({
    required String userId,
    required String displayName,
    String? petName,
    String timezone = 'UTC',
    String? gender,
    DateTime? birthday,
    AvatarCharacter? character,
  }) async {
    this.character = character;
    this.gender = gender;
    name = displayName;
    return UserProfile(
        id: userId, displayName: displayName, avatar: character?.id);
  }

  @override
  Future<UserProfile?> getProfile(String userId) async => null;
}

// Screenshots, opt in:
//   flutter test test/avatar_character_test.dart --dart-define=CAPTURE_REVIEW=true
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');
final _boundary = GlobalKey();

Future<void> _shoot(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    for (final (family, asset) in [
      ('TikTokSans', 'assets/fonts/tiktok/TikTokSans.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image = await (_boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary)
        .toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('build/review/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
  });
}

Finder _labelled(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
    description: 'labelled "$label"');

void main() {
  testWidgets('sign-up asks which one is you, and keeps the answer',
      (tester) async {
    final users = _Created();
    final router = GoRouter(initialLocation: Routes.onboarding, routes: [
      GoRoute(
          path: Routes.onboarding,
          builder: (_, __) => const OnboardingScreen()),
      GoRoute(
          path: Routes.pair,
          builder: (_, __) => const Scaffold(body: Text('Pair now'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('me'),
        userRepositoryProvider.overrideWithValue(users),
      ],
      child: RepaintBoundary(
        key: _boundary,
        child: MaterialApp.router(
            theme: AppTheme.current,
            debugShowCheckedModeBanner: false,
            routerConfig: router),
      ),
    ));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sam');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    // The birthday is optional, and no longer the last step.
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text('is you?'), findsOneWidget);
    expect(find.byType(CharacterAvatar), findsNWidgets(2));
    // Nothing sent until one is picked.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(users.name, isNull);

    // Their gender, on the same page, picks the matching picture...
    await tester.tap(_labelled('Woman'));
    await tester.pumpAndSettle();
    bool picked(String label) => tester
        .widget<Semantics>(_labelled(label).first)
        .properties
        .selected!;
    expect(picked('Girl'), isTrue);
    await _shoot(tester, 'onboarding-avatar');
    // ...until they pick one themselves, which it never overrides.
    await tester.tap(_labelled('Boy').first);
    await tester.pumpAndSettle();
    await tester.tap(_labelled('Man'));
    await tester.tap(_labelled('Woman'));
    await tester.pumpAndSettle();
    expect(picked('Boy'), isTrue);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(users.name, 'Sam');
    expect(users.character, AvatarCharacter.boy);
    expect(users.gender, 'female');
    expect(find.text('Pair now'), findsOneWidget);
  });

  testWidgets('no photo: their character, else their flower', (tester) async {
    Future<Widget> avatarFor(UserProfile profile) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Scaffold(body: Center(child: UserAvatar(profile)))),
      ));
      await tester.pump();
      return tester.widget(find.descendant(
          of: find.byType(UserAvatar),
          matching: find.byWidgetPredicate(
              (w) => w is CharacterAvatar || w is FlowerAvatar)));
    }

    final boy = await avatarFor(
        const UserProfile(id: 'a', displayName: 'A', avatar: 'boy'));
    expect((boy as CharacterAvatar).character, AvatarCharacter.boy);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as ResizeImage).imageProvider,
        isA<AssetImage>().having((a) => a.assetName, 'asset',
            'assets/images/avatars/boy.webp'));

    // A flower chosen in Settings replaces the character, and is kept.
    final daisy = await avatarFor(
        const UserProfile(id: 'b', displayName: 'B', avatar: 'daisy'));
    expect((daisy as FlowerAvatar).flower.id, 'daisy');

    // An account from before characters, which chose nothing: its flower.
    final none =
        await avatarFor(const UserProfile(id: 'c', displayName: 'C'));
    expect(none, isA<FlowerAvatar>());
  });

  test('a character id is never a flower id', () {
    // They share users.avatar; an older build must read a character as no
    // flower at all, never as a different flower.
    for (final c in AvatarCharacter.values) {
      expect(UserProfile(id: 'x', displayName: 'X', avatar: c.id).flower.id,
          isNot(c.id));
    }
  });
}

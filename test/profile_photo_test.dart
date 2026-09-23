import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/core/widgets/flower_avatar.dart';
import 'package:dayflower/core/widgets/profile_photo.dart';
import 'package:dayflower/features/calls/data/call_usage.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/tulip/presentation/screens/chat_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screenshot of the new chat settings header, opt in:
//   flutter test test/profile_photo_test.dart --dart-define=CAPTURE_REVIEW=true
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');

const _wifey = UserProfile(id: 'p', displayName: 'Jamie', petName: 'Wifey');

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('pressing their face opens their picture, and back closes it',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: ProfilePhotoButton(profile: _wifey, name: 'Wifey', size: 40),
        ),
      ),
    ));
    // A button a screen reader can find and name.
    expect(find.bySemanticsLabel('View Wifey’s photo'), findsOneWidget);

    await tester.tap(find.byType(ProfilePhotoButton));
    await tester.pumpAndSettle();
    // Full screen, named, and large - no photo here, so their flower.
    expect(find.text('Wifey'), findsOneWidget);
    final big = tester.widget<FlowerAvatar>(find.byType(FlowerAvatar).last);
    expect(big.size, greaterThan(200));

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Wifey'), findsNothing);
    semantics.dispose();
  });

  testWidgets('chat settings leads with their face, name below, no card',
      (tester) async {
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        partnerProfileProvider.overrideWith((ref) async => _wifey),
        callUsageProvider.overrideWith((ref) async =>
            const CallUsage(voice: Duration(hours: 10, minutes: 5))),
        flowerMessagesProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.current,
          home: const ChatSettingsScreen(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final face = tester.getRect(find.byType(ProfilePhotoButton));
    final name = tester.getRect(find.text('Wifey'));
    // Centred, and the name under the face rather than beside it.
    expect(face.center.dx, closeTo(195, 1));
    expect(name.center.dx, closeTo(195, 1));
    expect(name.top, greaterThan(face.bottom));
    expect(face.width, greaterThanOrEqualTo(100));
    expect(tester.takeException(), isNull);

    if (_capture) {
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/review/chat-settings.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
      });
    }
  });
}

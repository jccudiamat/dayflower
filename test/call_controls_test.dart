import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/theme/app_colors.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/features/calls/data/call_transport.dart';
import 'package:dayflower/features/calls/data/ring_light_prefs.dart';
import 'package:dayflower/features/calls/domain/call.dart';
import 'package:dayflower/features/calls/domain/call_notifier.dart';
import 'package:dayflower/features/calls/presentation/game_mode.dart';
import 'package:dayflower/features/calls/presentation/screens/call_screen.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The call's controls, Meet's way: the everyday ones in a bar, the ring
/// light and game mode behind ⋮. And game mode asking for "Display over
/// other apps" once, then floating the call.
class _Call extends CallNotifier {
  _Call(super.ref, CallSession session) {
    state = session;
  }

  void set(CallSession? session) => state = session;
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
    final emoji = File('C:/Windows/Fonts/seguiemj.ttf');
    if (await emoji.exists()) {
      await (FontLoader('TikTokSans')
            ..addFont(emoji.readAsBytes().then((b) => ByteData.sublistView(b))))
          .load();
    }
  });

  final live = CallSession(
    messageId: 'm',
    room: 'r',
    mode: CallMode.video,
    status: CallStatus.live,
    isCaller: true,
    startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
  );
  const partner = UserProfile(id: 'b', displayName: 'Wifey', timezone: '');

  const channel = MethodChannel('dayflower/game_mode');
  final asked = <MethodCall>[];
  var canDraw = false;

  final boundary = GlobalKey();

  Future<_Call> pump(WidgetTester tester, CallSession session,
      {bool floats = true}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    asked.clear();
    canDraw = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      asked.add(call);
      return switch (call.method) {
        'supported' => true,
        'canDraw' => canDraw,
        'requestPermission' => true,
        'start' => true,
        _ => null,
      };
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    late _Call call;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        callNotifierProvider.overrideWith((ref) => call = _Call(ref, session)),
        callTransportProvider.overrideWithValue(UnconfiguredCallTransport()),
        partnerProfileProvider.overrideWith((ref) async => partner),
        partnerProfileStreamProvider
            .overrideWith((ref) => Stream.value(partner)),
        gameModeSupportedProvider.overrideWith((ref) async => floats),
      ],
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          theme: AppTheme.current,
          debugShowCheckedModeBanner: false,
          home: const CallScreen(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return call;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_REVIEW')) return;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/review/call-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(CallScreen)));

  testWidgets('the bar is Meet\'s, and the ring light is behind ⋮',
      (tester) async {
    AppColors.use(AppMode.dark);
    addTearDown(() => AppColors.use(AppMode.light));
    final call = await pump(tester, live);
    await shot(tester, 'bar');

    for (final tip in [
      'Turn camera off',
      'Mute',
      'Send a tulip',
      'More options',
      'End',
    ]) {
      expect(find.byTooltip(tip), findsOneWidget, reason: tip);
    }
    expect(find.byTooltip('Ring light'), findsNothing,
        reason: 'not in the bar any more');
    // In Meet's order, End last and set apart.
    final xs = [
      for (final tip in ['Turn camera off', 'Mute', 'Send a tulip',
        'More options', 'End'])
        tester.getCenter(find.byTooltip(tip)).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await shot(tester, 'more');
    expect(find.bySemanticsLabel('Ring light'), findsOneWidget);
    expect(find.bySemanticsLabel('Game mode'), findsOneWidget);
    expect(find.byType(Slider), findsNothing, reason: 'no width while off');

    await tester.tap(find.bySemanticsLabel('Ring light'));
    await tester.pumpAndSettle();
    expect(container(tester).read(ringLightProvider), isTrue);
    expect(find.byType(Slider), findsOneWidget,
        reason: 'its width, under the switch, while it is on');
    await shot(tester, 'more-ring');
    // The lit tile's words are dark on the light, in the dark theme too.
    final lit = tester.widget<Text>(find.descendant(
        of: find.bySemanticsLabel('Ring light'), matching: find.byType(Text)));
    expect(lit.style?.color, AppColors.darkCanvas);

    Navigator.of(tester.element(find.byType(Slider))).pop();
    await tester.pumpAndSettle();
    call.set(live.copyWith(micEnabled: false));
    await tester.pumpAndSettle();
    await shot(tester, 'bar-muted');
    await finish(tester);
  });

  testWidgets('game mode asks once for the overlay, then floats the call',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await pump(tester, live);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Game mode'));
      await tester.pumpAndSettle();

      // Not granted: it says why before sending anyone to Settings.
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.textContaining('see and hear Wifey'), findsOneWidget);
      expect(asked.map((c) => c.method), isNot(contains('start')));
      await shot(tester, 'game-ask');

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(asked.last.method, 'requestPermission');

      // Back from Settings with it switched on: floats without a second tap.
      canDraw = true;
      final binding = tester.binding;
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      final start = asked.lastWhere((c) => c.method == 'start');
      // No media server here, so no track: the circle shows their face.
      expect(start.arguments, {'trackId': null, 'speaking': false});
      expect(container(tester).read(gameModeProvider), isTrue);

      // Back in the app by the circle: the Activity says game mode is over.
      await binding.defaultBinaryMessenger.handlePlatformMessage(
        'dayflower/game_mode',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('ended')),
        (_) {},
      );
      expect(container(tester).read(gameModeProvider), isFalse);
      await finish(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the circle follows who is talking, and goes with the call',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final call = await pump(tester, live);
      canDraw = true;
      final game = container(tester).read(gameModeProvider.notifier);
      expect(await game.start(), GameModeStart.floating);

      call.set(live.copyWith(partnerSpeaking: true));
      await tester.pump();
      expect(asked.last.method, 'update');
      expect(asked.last.arguments, {'trackId': null, 'speaking': true});

      // The once-a-second clock is not news to the circle.
      final count = asked.length;
      call.set(live.copyWith(partnerSpeaking: true));
      await tester.pump();
      expect(asked.length, count);

      call.set(live.copyWith(status: CallStatus.ended));
      await tester.pump();
      expect(asked.last.method, 'stop');
      expect(container(tester).read(gameModeProvider), isFalse);
      await finish(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a voice call on a phone that cannot float has no ⋮',
      (tester) async {
    await pump(
      tester,
      CallSession(
        messageId: 'm',
        room: 'r',
        mode: CallMode.voice,
        status: CallStatus.live,
        isCaller: true,
        startedAt: DateTime.now(),
      ),
      floats: false,
    );
    expect(find.byTooltip('More options'), findsNothing);
    expect(find.byTooltip('Turn camera off'), findsNothing);
    expect(find.byTooltip('Mute'), findsOneWidget);
    await finish(tester);
  });
}

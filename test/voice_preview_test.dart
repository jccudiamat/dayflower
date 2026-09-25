import 'dart:io';
import 'dart:typed_data';

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/models/pair.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/pairing/data/pair_repository.dart';
import 'package:dayflower/features/presence/data/presence_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/tulip/data/reaction_repository.dart';
import 'package:dayflower/features/tulip/data/typing_repository.dart';
import 'package:dayflower/features/tulip/presentation/screens/flowers_screen.dart';
import 'package:dayflower/features/tulip/presentation/widgets/voice_preview.dart';
import 'package:dayflower/features/tulip/presentation/widgets/voice_recorder_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _wifey = UserProfile(id: 'them', displayName: 'Jamie', petName: 'Wifey');

/// A microphone that always captures four seconds.
///
/// ⚠️ It writes a real file. The send path reads the recording off disk, so
/// a path pointing at nothing would exercise the failure branch and look
/// like a bug in the composer.
class _Recorder {
  final calls = <String>[];
  int stops = 0;
  bool paused = false;
  late final Directory _dir = Directory.systemTemp.createTempSync('dayflower');

  void install(WidgetTester tester) {
    addTearDown(() {
      if (_dir.existsSync()) _dir.deleteSync(recursive: true);
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dayflower/voice'),
      (call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'stop':
            stops++;
            final file = File('${_dir.path}/voice-take-$stops.m4a')
              ..writeAsBytesSync(List<int>.filled(512, 7));
            return {'path': file.path, 'ms': 4000};
          case 'amplitude':
            return 0.4;
          case 'pauseRecording':
            paused = true;
            return 4000;
          case 'resumeRecording':
            paused = false;
            return 4000;
          case 'play':
            return 4000;
          case 'position':
            return {'ms': 1200, 'playing': true};
          default:
            return null;
        }
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dayflower/voice'), null));
  }
}

/// What the repository was asked to send.
typedef Sent = ({Duration length, String? note});

class _Repo implements FlowerRepository {
  final sent = <Sent>[];

  @override
  Future<FlowerMessage> sendVoiceNote({
    required String pairId,
    required String senderId,
    required Uint8List bytes,
    required Duration length,
    String? note,
    String? replyTo,
  }) async {
    sent.add((length: length, note: note));
    return FlowerMessage(
      id: 'v${sent.length}',
      pairId: pairId,
      senderId: senderId,
      audioPath: '$pairId/v.m4a',
      audioMs: length.inMilliseconds,
      note: note,
      sentAt: DateTime.now(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _pump(WidgetTester tester, _Repo repo) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(initialLocation: Routes.chat, routes: [
    GoRoute(path: Routes.chat, builder: (_, __) => const FlowersScreen()),
  ]);
  addTearDown(router.dispose);
  final now = DateTime.now();
  await tester.pumpWidget(ProviderScope(overrides: [
    currentUserIdProvider.overrideWithValue('me'),
    currentPairProvider.overrideWith((ref) async =>
        const Pair(id: 'pair', userA: 'me', userB: 'them', inviteCode: 'T')),
    flowerMessagesProvider.overrideWith((ref) => Stream.value(const [])),
    reactionsProvider.overrideWith((ref) => Stream.value({})),
    partnerProfileProvider.overrideWith((ref) async => _wifey),
    partnerProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
    partnerLastActiveProvider.overrideWith((ref) async => now),
    partnerTypingProvider.overrideWith((ref) => Stream.value(false)),
    flowerRepositoryProvider.overrideWithValue(repo),
  ], child: MaterialApp.router(
      theme: AppTheme.current,
      debugShowCheckedModeBanner: false,
      routerConfig: router)));
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pumpAndSettle();
}

/// Records for a moment and stops, which is what the tick button does.
Future<void> _record(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Record a voice message'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.bySemanticsLabel('Send voice message'));
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

  testWidgets('a recording waits to be heard, and carries what you type',
      (tester) async {
    _Recorder().install(tester);
    final repo = _Repo();
    await _pump(tester, repo);

    await tester.tap(find.byTooltip('Record a voice message'));
    await tester.pumpAndSettle();
    expect(find.byType(VoiceRecorderBar), findsOneWidget);
    expect(find.byType(VoicePreview), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.bySemanticsLabel('Send voice message'));
    await tester.pumpAndSettle();

    // 🔴 Stopping must not send it. It waits on the composer to be heard.
    expect(repo.sent, isEmpty, reason: 'nothing sent on stop');
    expect(find.byType(VoiceRecorderBar), findsNothing);
    expect(find.byType(VoicePreview), findsOneWidget);
    expect(find.text('0:04'), findsOneWidget, reason: 'its length, to review');

    // The ordinary field is the caption field while one is waiting.
    expect(find.text('Add a caption'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'listen to this');
    await tester.pumpAndSettle();

    // ⚠️ Inside runAsync: sending reads the recording off disk, and real
    // file I/O never completes on a widget test's fake clock.
    await tester.runAsync(() async {
      await tester.tap(find.bySemanticsLabel('Send'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(repo.sent, hasLength(1));
    expect(repo.sent.single.note, 'listen to this');
    expect(repo.sent.single.length, const Duration(seconds: 4));
    expect(find.byType(VoicePreview), findsNothing);
  });

  testWidgets('it can be played back, and thrown away instead',
      (tester) async {
    final mic = _Recorder()..install(tester);
    final repo = _Repo();
    await _pump(tester, repo);
    await _record(tester);
    expect(find.byType(VoicePreview), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Play it back'));
    await tester.pumpAndSettle();
    expect(mic.calls, contains('play'));

    await tester.tap(find.bySemanticsLabel('Delete this recording'));
    await tester.pumpAndSettle();
    expect(find.byType(VoicePreview), findsNothing);
    expect(repo.sent, isEmpty);
    expect(find.text('Message'), findsOneWidget, reason: 'back to a message');
  });

  testWidgets('recording can be paused and carried on', (tester) async {
    final mic = _Recorder()..install(tester);
    await _pump(tester, _Repo());

    await tester.tap(find.byTooltip('Record a voice message'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.bySemanticsLabel('Pause recording'));
    await tester.pumpAndSettle();
    expect(mic.paused, isTrue);
    // The button now offers the opposite, and the bar is still up.
    expect(find.bySemanticsLabel('Carry on recording'), findsOneWidget);
    expect(find.byType(VoiceRecorderBar), findsOneWidget);

    // 🔴 The clock must stop with it. A timer that kept counting would
    // promise seconds of audio the file does not contain.
    final atPause = tester.widget<Text>(find.text('0:04')).data;
    expect(atPause, '0:04');
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('0:04'), findsOneWidget, reason: 'frozen while paused');

    await tester.tap(find.bySemanticsLabel('Carry on recording'));
    await tester.pumpAndSettle();
    expect(mic.paused, isFalse);
    expect(find.bySemanticsLabel('Pause recording'), findsOneWidget);
  });

  testWidgets('while one waits, the other ways to attach stand down',
      (tester) async {
    _Recorder().install(tester);
    await _pump(tester, _Repo());
    await _record(tester);

    // A picture and a voice in one bubble is a thing the thread cannot draw,
    // so the camera and gallery wait until this one is sent or discarded.
    for (final tip in ['Attach a photo', 'Take a photo']) {
      await tester.tap(find.byTooltip(tip));
      await tester.pumpAndSettle();
      expect(find.byType(VoicePreview), findsOneWidget, reason: tip);
    }
  });
}

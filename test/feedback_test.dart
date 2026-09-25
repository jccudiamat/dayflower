import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/core/widgets/gradient_button.dart';
import 'package:dayflower/features/feedback/data/feedback_repository.dart';
import 'package:dayflower/features/feedback/presentation/feedback_screen.dart';
import 'package:dayflower/features/updates/data/update_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Screenshot, opt in:
//   flutter test test/feedback_test.dart --dart-define=CAPTURE_REVIEW=true
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');

class _Sent {
  _Sent(this.userId, this.kind, this.message, this.images, this.appVersion);
  final String userId;
  final FeedbackKind kind;
  final String message;
  final List<FeedbackImage> images;
  final String? appVersion;
}

class _FakeFeedback implements FeedbackRepository {
  final sent = <_Sent>[];
  bool fail = false;

  @override
  Future<void> send({
    required String userId,
    required FeedbackKind kind,
    required String message,
    List<FeedbackImage> images = const [],
    String? appVersion,
  }) async {
    if (fail) throw Exception('offline');
    sent.add(_Sent(userId, kind, message, images, appVersion));
  }
}

/// A real 4x4 PNG, so the thumbnail decodes as a picked screenshot would.
Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = const Color(0xFF8B72E0));
  final image = await recorder.endRecording().toImage(4, 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<void> _pump(WidgetTester tester, _FakeFeedback repo, Uint8List png,
    {GlobalKey? boundary}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: Routes.settings, routes: [
    GoRoute(
        path: Routes.settings,
        builder: (_, __) => const Scaffold(body: Center(child: Text('Settings')))),
    GoRoute(path: Routes.feedback, builder: (_, __) => const FeedbackScreen()),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      feedbackRepositoryProvider.overrideWithValue(repo),
      feedbackImagePickerProvider
          .overrideWithValue(() async => (bytes: png, extension: 'png')),
      installedVersionProvider.overrideWith((ref) async => '1.0.0 (110)'),
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
  router.push(Routes.feedback);
  await tester.pumpAndSettle();
}

/// The widget carrying [label], not the merged node a screen reader hears:
/// that one spans the whole row, and a tap at its middle hits something else.
Finder _labelled(Pattern label) => find.byWidgetPredicate((w) {
      final said = w is Semantics ? w.properties.label : null;
      if (said == null) return false;
      return label is RegExp ? label.hasMatch(said) : said == label;
    }, description: 'labelled "$label"');

bool _canSend(WidgetTester tester) =>
    tester.widget<GradientButton>(find.byType(GradientButton)).onPressed !=
    null;

void main() {
  late Uint8List png;
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
    png = await _png();
  });

  testWidgets('words, a kind and screenshots go, and Settings says thanks',
      (tester) async {
    final boundary = GlobalKey();
    final repo = _FakeFeedback();
    await _pump(tester, repo, png, boundary: boundary);

    expect(find.text('Bugs and suggestions'), findsOneWidget);
    expect(_canSend(tester), isFalse, reason: 'nothing written yet');

    await tester.tap(find.text('Suggestion'));
    await tester.pump();
    expect(find.text(FeedbackKind.suggestion.prompt), findsOneWidget,
        reason: 'the question follows the kind');

    await tester.enterText(
        find.byType(TextField), 'A way to pin a message would be lovely.');
    await tester.pump();
    expect(_canSend(tester), isTrue);

    for (var i = 0; i < 3; i++) {
      await tester.tap(_labelled('Add a screenshot'));
      await tester.pumpAndSettle();
    }
    expect(_labelled(RegExp('Remove screenshot')),
        findsNWidgets(3));
    expect(_labelled('Add a screenshot'), findsNothing,
        reason: 'three is the most');
    await tester.tap(_labelled('Remove screenshot 3'));
    await tester.pumpAndSettle();
    expect(_labelled(RegExp('Remove screenshot')),
        findsNWidgets(2));
    if (_capture) {
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/review/feedback.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
      });
    }

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(repo.sent, hasLength(1));
    final sent = repo.sent.single;
    expect(sent.userId, 'me');
    expect(sent.kind, FeedbackKind.suggestion);
    expect(sent.message, 'A way to pin a message would be lovely.');
    expect(sent.images, hasLength(2));
    expect(sent.appVersion, '1.0.0 (110)');
    expect(find.byType(FeedbackScreen), findsNothing, reason: 'back out');
    expect(find.text('Sent. Thank you for the idea.'), findsOneWidget);
  });

  testWidgets('a send that fails keeps everything to try again',
      (tester) async {
    final repo = _FakeFeedback()..fail = true;
    await _pump(tester, repo, png);
    await tester.enterText(find.byType(TextField), 'The map went blank.');
    await tester.tap(_labelled('Add a screenshot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(find.text("Couldn't send that. Check your connection and try again."),
        findsOneWidget);
    expect(find.text('The map went blank.'), findsOneWidget);
    expect(_labelled('Remove screenshot 1'), findsOneWidget);

    repo.fail = false;
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(repo.sent.single.kind, FeedbackKind.bug, reason: 'bug by default');
    expect(find.text('Sent. Thank you for telling us.'), findsOneWidget);
  });
}

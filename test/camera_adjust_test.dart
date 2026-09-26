import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayflower/app_router.dart';
import 'package:dayflower/core/models/pair.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/features/booth/data/strip_repository.dart';
import 'package:dayflower/features/pairing/data/pair_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/tulip/presentation/screens/messages_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'support/trust_fakes.dart';

// Screenshots, opt in:
//   flutter test test/camera_adjust_test.dart --dart-define=CAPTURE_REVIEW=true
const _capture = bool.fromEnvironment('CAPTURE_REVIEW');
final _boundary = GlobalKey();

Future<void> _shoot(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final image = await (_boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary)
        .toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

/// A photo taken or picked is held for review, and can be pinched, twisted
/// and dragged before it goes. What is sent is what was left on screen.

/// Red on the left half, green on the right, [w] by [h].
Future<Uint8List> _halves({int w = 600, int h = 800}) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawRect(ui.Rect.fromLTWH(0, 0, w / 2, h.toDouble()),
        ui.Paint()..color = const ui.Color(0xFFFF0000))
    ..drawRect(ui.Rect.fromLTWH(w / 2, 0, w / 2, h.toDouble()),
        ui.Paint()..color = const ui.Color(0xFF00FF00));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// The gallery, with one photo in it.
class _Gallery extends ImagePickerPlatform {
  _Gallery(this.bytes);
  final Uint8List bytes;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      XFile.fromData(bytes, path: 'picked.png', name: 'picked.png');
}

/// Keeps what was sent instead of sending it.
class _Sent extends FlowerRepository {
  _Sent() : super(offlineClient());
  Uint8List? bytes;
  String? extension;

  @override
  Future<FlowerMessage> sendDayPhotoTo({
    required String pairId,
    required String senderId,
    required Uint8List bytes,
    required String fileExtension,
    required DayPhotoTarget target,
    String? note,
    String? replyTo,
    PhotoOrigin origin = PhotoOrigin.daily,
    String? frameId,
  }) async {
    this.bytes = bytes;
    extension = fileExtension;
    return FlowerMessage(
        id: 'sent',
        pairId: pairId,
        senderId: senderId,
        imagePath: 'pair/sent.$fileExtension',
        sentAt: DateTime.now());
  }
}

Finder _labelled(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
    description: 'labelled "$label"');

/// Real time, for decoding and file reads the fake clock never finishes.
Future<void> _settle(WidgetTester tester, [int ms = 300]) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: ms ~/ 4)));
    await tester.pump();
  }
}

/// Two fingers down either side of [centre], turned a quarter clockwise.
Future<void> _twistQuarter(WidgetTester tester, Offset centre) async {
  const r = 90.0;
  final a = await tester.startGesture(centre - const Offset(r, 0), pointer: 1);
  final b = await tester.startGesture(centre + const Offset(r, 0), pointer: 2);
  await tester.pump();
  const steps = 12;
  for (var i = 1; i <= steps; i++) {
    final t = i / steps * 3.14159265 / 2;
    final at = Offset(r * _cos(t), r * _sin(t));
    await a.moveTo(centre - at);
    await b.moveTo(centre + at);
    await tester.pump();
  }
  await a.up();
  await b.up();
  await tester.pump();
}

double _cos(double t) => ui.Offset.fromDirection(t).dx;
double _sin(double t) => ui.Offset.fromDirection(t).dy;

void main() {
  late Uint8List photo;
  late _Sent sent;

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

  Future<void> pump(WidgetTester tester) async {
    await tester.runAsync(() async => photo = await _halves());
    ImagePickerPlatform.instance = _Gallery(photo);
    sent = _Sent();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(initialLocation: Routes.flowers, routes: [
      GoRoute(path: Routes.flowers, builder: (_, __) => const MessagesScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('me'),
        currentPairProvider.overrideWith((ref) async => const Pair(
            id: 'pair', userA: 'me', userB: 'them', inviteCode: 'T')),
        openStripsProvider.overrideWith((ref) => Stream.value(const [])),
        flowerMessagesProvider.overrideWith((ref) => Stream.value(const [])),
        flowerRepositoryProvider.overrideWithValue(sent),
      ],
      child: RepaintBoundary(
        key: _boundary,
        child: MaterialApp.router(
          theme: AppTheme.current,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        ),
      ),
    ));
    await _settle(tester);
  }

  /// The held photo's box on screen: the widget moving under the fingers.
  Rect heldBox(WidgetTester tester) => tester.getRect(find
      .ancestor(of: find.byType(ClipRect), matching: find.byType(GestureDetector))
      .first);

  testWidgets('a picked photo can be twisted, reset, and sent as it was left',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Upload a photo'));
    await _settle(tester, 600);

    // Held whole, and saying what can be done with it.
    expect(find.text('Pinch to zoom, twist to tilt'), findsOneWidget);
    await _shoot(tester, 'camera-held');
    final box = heldBox(tester);
    // Its own shape (3:4), not the screen's.
    expect(box.width / box.height, closeTo(600 / 800, .01));

    await _twistQuarter(tester, box.center);
    await _shoot(tester, 'camera-held-twisted');
    // Moved, so the hint has done its job.
    expect(find.text('Pinch to zoom, twist to tilt'), findsNothing);

    // A double tap puts it back as it was taken.
    await tester.tapAt(box.center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(box.center);
    await tester.pumpAndSettle();
    expect(find.text('Pinch to zoom, twist to tilt'), findsOneWidget);

    // Twisted again, and sent.
    await _twistQuarter(tester, box.center);
    await tester.tap(_labelled('Send photo'));
    await _settle(tester, 1500);
    await tester.pumpAndSettle();

    // 🔴 What arrives is what was on screen: turned a quarter clockwise,
    // the red left half is now the top and the green right half the
    // bottom, at the photo's own size.
    final bytes = sent.bytes;
    expect(bytes, isNotNull, reason: 'it was sent');
    final image = await tester.runAsync(() async =>
        (await (await ui.instantiateImageCodec(bytes!)).getNextFrame()).image);
    addTearDown(image!.dispose);
    expect((image.width, image.height), (600, 800));
    final rgba = (await tester.runAsync(() => image.toByteData(
        format: ui.ImageByteFormat.rawRgba)))!;
    int at(double fx, double fy) {
      final x = (image.width * fx).floor(), y = (image.height * fy).floor();
      final i = (y * image.width + x) * 4;
      return (rgba.getUint8(i) << 16) | (rgba.getUint8(i + 1) << 8) |
          rgba.getUint8(i + 2);
    }

    expect(at(.5, .2), 0xFF0000, reason: 'red on top');
    expect(at(.5, .8), 0x00FF00, reason: 'green below');
  });
}

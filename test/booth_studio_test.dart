import 'dart:io';
import 'dart:ui' as ui;
import 'package:dayflower/core/models/pair.dart';
import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/core/theme/app_theme.dart';
import 'package:dayflower/features/booth/data/booth_camera.dart';
import 'package:dayflower/features/booth/data/strip_repository.dart';
import 'package:dayflower/features/booth/domain/booth_design.dart';
import 'package:dayflower/features/booth/domain/booth_renderer.dart';
import 'package:dayflower/features/booth/domain/strip_compositor.dart';
import 'package:dayflower/features/booth/domain/strip_templates.dart';
import 'package:dayflower/features/booth/presentation/screens/booth_studio_screen.dart';
import 'package:dayflower/features/booth/presentation/screens/booth_archive_screen.dart';
import 'package:dayflower/features/booth/presentation/widgets/booth_visuals.dart';
import 'package:dayflower/features/onboarding/data/user_repository.dart';
import 'package:dayflower/features/pairing/data/pair_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'support/trust_fakes.dart';
import 'trust_fixes_test.dart' show RecordingStrips;

class ReviewCamera extends BoothCamera {
  ReviewCamera(this.bytes);
  final Uint8List bytes;
  bool available = true, opened = false;
  int captures = 0;
  @override
  bool get ready => available && opened;
  @override
  bool get canFlip => false;
  @override
  String? get error => available ? null : 'Camera access was denied.';
  @override
  Future<void> open() async {
    opened = true;
    notifyListeners();
  }

  @override
  Future<void> close() async {
    opened = false;
    notifyListeners();
  }

  @override
  Future<void> flip() async {}
  @override
  Future<Uint8List> capture() async {
    captures++;
    return bytes;
  }

  @override
  Widget preview() => Image.memory(bytes, fit: BoxFit.cover);
}

class _Flowers extends FlowerRepository {
  _Flowers(this.half) : super(offlineClient());
  final Uint8List half;
  int sends = 0;
  bool? widgetTarget;
  @override
  Future<Uint8List> downloadPhoto(String path) async => half;
  @override
  Future<FlowerMessage> sendDayPhoto(
      {required String pairId,
      required String senderId,
      required Uint8List bytes,
      required String fileExtension,
      String? note,
      bool toWidget = true,
      bool toChat = true}) async {
    sends++;
    widgetTarget = toWidget;
    return FlowerMessage(
        id: 'saved',
        pairId: pairId,
        senderId: senderId,
        imagePath: 'pair/output.jpg',
        note: note,
        sentAt: DateTime.now());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List photo, output, half;
  late ReviewCamera camera;
  late RecordingStrips repository;
  late _Flowers flowers;
  final boundary = GlobalKey();
  setUpAll(() async {
    photo = File('test/fixtures/home/partner.png').readAsBytesSync();
    output = await BoothRenderer.render(
        const BoothDesign(), [photo, photo, photo, photo]);
    half = await BoothRenderer.pack([photo, photo, photo, photo]);
    for (final (family, asset) in [
      ('TikTokSans', 'assets/fonts/tiktok/TikTokSans.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });
  setUp(() {
    camera = ReviewCamera(photo);
    repository = RecordingStrips();
    flowers = _Flowers(half);
  });

  Future<void> pump(WidgetTester tester,
      {double width = 390,
      double scale = 1,
      PhotoStrip? invite,
      bool paired = true,
      Future<Uint8List?> Function()? pick}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          boothCameraProvider.overrideWithValue(() => camera),
          boothRenderProvider.overrideWithValue((_, __) async => output),
          boothPhotoPickerProvider.overrideWithValue(
              (_) async => pick == null ? photo : await pick()),
          stripRepositoryProvider.overrideWithValue(repository),
          flowerRepositoryProvider.overrideWithValue(flowers),
          currentUserIdProvider.overrideWithValue('a'),
          currentPairProvider.overrideWith((ref) async => Pair(
              id: 'pair',
              userA: 'a',
              userB: paired ? 'b' : null,
              inviteCode: 'TEST')),
          partnerProfileProvider.overrideWith(
              (ref) async => const UserProfile(id: 'b', displayName: 'Wifey')),
          openStripsProvider.overrideWith(
              (ref) => Stream.value(invite == null ? [] : [invite])),
          flowerMessagesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: AppTheme.current,
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: BoothStudioScreen(joining: invite),
            ))));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final context = tester.element(find.byType(BoothStudioScreen));
      await precacheImage(MemoryImage(photo), context);
      await precacheImage(MemoryImage(output), context);
    });
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    if (find.text(label).evaluate().isEmpty) {
      await tester.scrollUntilVisible(find.text(label), 240);
    }
    await Scrollable.ensureVisible(tester.element(find.text(label).last),
        alignment: .4);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> shotCycle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> snapshot(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_REVIEW')) return;
    await tester.runAsync(() async {
      final b =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await b.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/review/$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> enterCamera(WidgetTester tester) async {
    await tap(tester, 'Solo');
    await tap(tester, 'Rose room');
    await tap(tester, 'Step inside');
  }

  testWidgets(
      'countdowns capture four shots, review before sharing, then print and save to Memories',
      (tester) async {
    await pump(tester);
    await snapshot(tester, 'booth-mode');
    await tap(tester, 'Solo');
    await snapshot(tester, 'booth-looks');
    await tap(tester, 'Rose room');
    await snapshot(tester, 'booth-frames');
    await tap(tester, 'Step inside');
    await snapshot(tester, 'booth-camera');
    await tap(tester, 'Start countdown');
    expect(find.text('3'), findsOneWidget);
    await snapshot(tester, 'booth-countdown');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);
    expect(camera.captures, 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 3; i++) {
      await shotCycle(tester);
    }
    await tester.pumpAndSettle();
    expect(camera.captures, 4);
    expect(camera.opened, isFalse);
    expect(find.text('A keeper?'), findsOneWidget);
    expect(flowers.sends, 0);
    expect(repository.starts, 0);
    await snapshot(tester, 'booth-review');
    await tester.ensureVisible(find.text('Print my strip'));
    await tester.tap(find.text('Print my strip'));
    await tester.pump();
    await snapshot(tester, 'booth-print-0');
    for (var i = 1; i <= 5; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await snapshot(tester, 'booth-print-$i');
    }
    expect(find.byType(PrintingPhoto), findsOneWidget);
    await snapshot(tester, 'booth-printing');
    await tester.pumpAndSettle();
    expect(find.text('Fresh from the booth'), findsOneWidget);
    await snapshot(tester, 'booth-finished');
    await tap(tester, 'Keep in Memories & share in Chat');
    expect(flowers.sends, 1);
    expect(flowers.widgetTarget, isFalse);
    expect(find.text('Shared in Memories & Chat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'backgrounding cancels the countdown and returning does not take an unexpected photo',
      (tester) async {
    await pump(tester);
    await enterCamera(tester);
    await tap(tester, 'Start countdown');
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5));
    expect(camera.captures, 0);
    expect(camera.opened, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 5));
    expect(camera.captures, 0);
    expect(camera.opened, isTrue);
    expect(find.text('Start countdown'), findsOneWidget);
  });

  testWidgets('denied camera and cancelled upload never create a fake shot',
      (tester) async {
    camera.available = false;
    await pump(tester, pick: () async => null);
    await enterCamera(tester);
    expect(find.text('Camera access was denied.'), findsOneWidget);
    await tap(tester, 'Upload a photo');
    expect(find.text('0 of 4 photos'), findsOneWidget);
    expect(camera.captures, 0);
    expect(flowers.sends, 0);
  });

  testWidgets(
      'remote solo half is saved as an invitation, never shown as a finished couple print',
      (tester) async {
    await pump(tester);
    await tap(tester, 'Couple');
    await tap(tester, 'From separate phones');
    await tap(tester, 'Rose room');
    await tap(tester, 'Step inside');
    for (var i = 0; i < 4; i++) {
      await tap(tester, 'Upload a photo');
    }
    await tester.ensureVisible(find.text('Send my photos to Wifey'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Send my photos to Wifey'));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();
    expect(repository.starts, 1);
    expect(repository.joins, 0);
    expect(find.text('Waiting for Wifey'), findsOneWidget);
    expect(find.text('Fresh from the booth'), findsNothing);
  });

  testWidgets(
      'joining a studio invitation keeps its frame and completes the existing strip',
      (tester) async {
    final invite = PhotoStrip(
        id: 'invite',
        pairId: 'pair',
        template: const BoothDesign().id,
        aUser: 'b',
        aPath: 'pair/half.jpg',
        createdAt: DateTime(2026));
    await pump(tester, invite: invite);
    await snapshot(tester, 'booth-couple');
    expect(find.text('Make a little memory'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tap(tester, 'Upload a photo');
    }
    await tester.ensureVisible(find.text('Finish our strip'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Finish our strip'));
      for (var i = 0; i < 100 && repository.joins == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pumpAndSettle();
    expect(repository.joins, 1);
    expect(repository.starts, 0);
    expect(find.text('Fresh from the booth'), findsOneWidget);
    expect(find.text('Shared in Memories & Chat'), findsOneWidget);
  });

  testWidgets(
      'solo session works without pairing and reports failed gallery saves truthfully',
      (tester) async {
    await pump(tester, paired: false);
    await enterCamera(tester);
    for (var i = 0; i < 4; i++) {
      await tap(tester, 'Upload a photo');
    }
    await tap(tester, 'Print my strip');
    var succeeds = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dayflower/media'), (_) async => succeeds);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dayflower/media'), null));
    await tap(tester, 'Save to Photos');
    expect(find.text('Saved to Photos'), findsNothing);
    expect(find.textContaining('Could not save to Photos'), findsOneWidget);
    succeeds = true;
    await tap(tester, 'Save to Photos');
    expect(find.text('Saved to Photos'), findsOneWidget);
    expect(flowers.sends, 0);
    expect(find.text('Keep in Memories & share in Chat'), findsNothing);
  });

  testWidgets('mode, booth and frames stay usable at 320px with large text',
      (tester) async {
    await pump(tester, width: 320, scale: 2);
    await tap(tester, 'Solo');
    expect(tester.takeException(), isNull);
    await tap(tester, 'Classic');
    await tap(tester, 'Polaroid');
    await tap(tester, 'Step inside');
    expect(tester.takeException(), isNull);
  });

  test('all layouts export every distinct photo in its matching preview pane',
      () async {
    final colors = [
      img.ColorRgb8(240, 20, 20),
      img.ColorRgb8(20, 240, 20),
      img.ColorRgb8(20, 20, 240),
      img.ColorRgb8(240, 220, 20)
    ];
    final inputs = colors.map((color) {
      final image = img.Image(width: 64, height: 48);
      img.fill(image, color: color);
      return Uint8List.fromList(img.encodePng(image));
    }).toList();
    for (final layout in BoothLayout.values) {
      final design = BoothDesign(layout: layout);
      final decoded = img.decodeJpg(await BoothRenderer.render(
          design, inputs.take(layout.shots).toList()))!;
      for (var i = 0; i < layout.shots; i++) {
        final rect = design.panes[i];
        final pixel = decoded.getPixel((rect.center.dx * decoded.width).round(),
            (rect.center.dy * decoded.height).round());
        expect(pixel.r, closeTo(colors[i].r, 8));
        expect(pixel.g, closeTo(colors[i].g, 8));
        expect(pixel.b, closeTo(colors[i].b, 8));
      }
    }
    final a = await BoothRenderer.pack(List.filled(4, inputs[0]));
    final b = await BoothRenderer.pack(List.filled(4, inputs[2]));
    const design = BoothDesign();
    final result = img.decodeJpg(await StripCompositor.render(
        template: StripTemplate.byId(design.id), first: a, second: b))!;
    final pane = design.panes.first;
    final left = result.getPixel(
        ((pane.left + pane.width * .25) * result.width).round(),
        (pane.center.dy * result.height).round());
    final right = result.getPixel(
        ((pane.left + pane.width * .75) * result.width).round(),
        (pane.center.dy * result.height).round());
    expect(left.r, greaterThan(200));
    expect(right.b, greaterThan(200));
    await expectLater(
        BoothRenderer.render(design, [inputs.first]), throwsArgumentError);
  });
}

import 'dart:io';

import 'package:dayflower/core/models/user_profile.dart';
import 'package:dayflower/core/theme/app_colors.dart';
import 'package:dayflower/features/tulip/data/chat_shortcut.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

/// Their chat as an icon on the home screen: the icon, what reaches
/// Android, and the Android side agreeing with it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dayflower/chat_shortcut');
  late List<MethodCall> calls;
  late String pinAnswer;
  late int downloads;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChatShortcut.debugSupported = true;
    calls = [];
    pinAnswer = 'asked';
    downloads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'pin' ? pinAnswer : true;
    });
  });

  tearDown(() {
    ChatShortcut.debugSupported = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// A red face in a blue frame, so where the frame lands says how the
  /// photo was placed.
  Uint8List photo() {
    final image = img.Image(width: 512, height: 512)
      ..clear(img.ColorRgb8(30, 60, 220));
    img.fillRect(image,
        x1: 40, y1: 40, x2: 471, y2: 471, color: img.ColorRgb8(220, 30, 60));
    return img.encodePng(image);
  }

  Future<Uint8List> download(String path) async {
    downloads++;
    return photo();
  }

  const wifey = UserProfile(
      id: 'w', displayName: 'Maria', petName: 'Wifey', avatarPath: 'w/1.jpg');

  group('the icon', () {
    test('is their whole photo in the part a launcher shows', () async {
      final png = await chatShortcutIcon(wifey, download: download);
      final icon = img.decodePng(png!)!;
      expect((icon.width, icon.height), (432, 432));
      final middle = icon.getPixel(216, 216);
      expect((middle.r, middle.g, middle.b), (220, 30, 60));
      // The launcher shows from 72px in. Drawn across the whole layer the
      // frame would be far outside that, cut off with the forehead and
      // chin; as the app frames a face, it is just inside.
      final frame = icon.getPixel(80, 216);
      expect(frame.b, greaterThan(180), reason: 'the photo\'s edge shows');
      // And the margin is more of the photo, blurred, never an empty edge.
      final corner = icon.getPixel(3, 3);
      expect(corner.a, 255);
    });

    test('is their flower on the brand gradient without a face', () async {
      const noPhoto = UserProfile(id: 'w', displayName: 'Maria');
      final png = await chatShortcutIcon(noPhoto, download: download);
      final icon = img.decodePng(png!)!;
      expect(downloads, 0);
      final left = icon.getPixel(2, 216);
      expect(left.a, 255);
      expect(left.r, closeTo((AppColors.gradientPink.r * 255).round(), 6));
      expect(left.g, closeTo((AppColors.gradientPink.g * 255).round(), 6));
    });

    test('falls back to the flower when the photo cannot be had', () async {
      final png = await chatShortcutIcon(wifey,
          download: (_) async => throw const SocketException('offline'));
      expect(png, isNotNull);
      final left = img.decodePng(png!)!.getPixel(2, 216);
      expect(left.r, closeTo((AppColors.gradientPink.r * 255).round(), 6));
    });
  });

  group('the shortcut', () {
    test('is called what the app calls them', () {
      expect(ChatShortcut.labelFor(wifey), 'Wifey');
      expect(
          ChatShortcut.labelFor(const UserProfile(
              id: 'w', displayName: 'Maria', petName: '  ')),
          'Maria');
    });

    test('is published once, and again when they change', () async {
      await ChatShortcut.publish(wifey, download: download);
      expect(calls.single.method, 'publish');
      final args = calls.single.arguments as Map;
      expect(args['name'], 'Wifey');
      expect(args['icon'], isA<Uint8List>());

      // An ordinary launch: nothing downloaded or redrawn.
      await ChatShortcut.publish(wifey, download: download);
      expect(calls, hasLength(1));
      expect(downloads, 1);

      // A new photo.
      const newPhoto = UserProfile(
          id: 'w', displayName: 'Maria', petName: 'Wifey', avatarPath: 'w/2.jpg');
      await ChatShortcut.publish(newPhoto, download: download);
      expect(calls, hasLength(2));

      // Signed out, and back in: published again.
      await ChatShortcut.clear();
      expect(calls.last.method, 'clear');
      await ChatShortcut.publish(newPhoto, download: download);
      expect(calls.last.method, 'publish');
    });

    test('says what pinning came to', () async {
      for (final (answer, result) in [
        ('asked', ChatShortcutPin.asked),
        ('already', ChatShortcutPin.already),
        ('unsupported', ChatShortcutPin.unsupported),
      ]) {
        pinAnswer = answer;
        expect(await ChatShortcut.pin(wifey, download: download), result);
      }
      expect((calls.last.arguments as Map)['name'], 'Wifey');
    });

    test('is nothing off Android', () async {
      ChatShortcut.debugSupported = false;
      await ChatShortcut.publish(wifey, download: download);
      expect(await ChatShortcut.pin(wifey, download: download),
          ChatShortcutPin.unsupported);
      await ChatShortcut.clear();
      expect(calls, isEmpty);
    });
  });

  group('Android', () {
    String read(String path) => File(path).readAsStringSync();
    const kotlin = 'android/app/src/main/kotlin/com/dayflower/app/';

    test('answers on the same channel', () {
      final native = read('${kotlin}ChatShortcut.kt');
      expect(
          RegExp(r'const val CHANNEL = "([\w/]+)"').firstMatch(native)?.group(1),
          channel.name);
      expect(read('${kotlin}MainActivity.kt'), contains('ChatShortcut.CHANNEL'));
    });

    // 🔴 Android clears a shortcut's task before starting it. Aimed at
    // MainActivity, that would end the running app, and a call in it.
    test('a tap goes round the running app, not through it', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      final at = manifest.indexOf('android:name=".ShortcutActivity"');
      expect(at, isNot(-1));
      final tag = manifest.substring(
          manifest.lastIndexOf('<activity', at), manifest.indexOf('/>', at));
      expect(tag, contains('android:taskAffinity=""'));
      expect(tag, contains('android:exported="false"'));
      final native = read('${kotlin}ChatShortcut.kt');
      expect(native, contains('Intent(context, ShortcutActivity::class.java)'));
      expect(native, contains('HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION'));
      expect(native, contains('dayflower://chat'));
      expect(read('lib/app.dart'), contains("case 'chat':"));
    });
  });
}

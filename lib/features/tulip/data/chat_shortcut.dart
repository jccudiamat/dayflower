import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/theme/app_colors.dart';

/// Fetches an avatar from storage by its path (UserRepository.downloadAvatar).
typedef AvatarDownload = Future<Uint8List> Function(String path);

/// What asking to put the chat on the home screen came to.
enum ChatShortcutPin {
  /// The launcher is showing its own "Add to home screen" dialog. Not that
  /// the icon is there: the person can still say no.
  asked,

  /// It is on the home screen already, and has just been brought up to date.
  already,

  /// This phone or its launcher cannot be handed one. It is still in the
  /// menu of the app's icon, to drag out from there.
  unsupported,
}

/// Their chat as an icon on the home screen, the way WhatsApp puts a chat
/// there: their face, with Dayflower's badge on it (the launcher adds that),
/// and a tap opens the conversation. Also in the menu that opens when the
/// app's own icon is held.
///
/// Android only: iOS gives an app no way to put an icon on the home screen.
/// The native half is ChatShortcut.kt, and a tap arrives as a widget's does,
/// `dayflower://chat` (DayflowerApp._openWidgetTarget).
class ChatShortcut {
  ChatShortcut._();

  static const _channel = MethodChannel('dayflower/chat_shortcut');

  static bool get supported =>
      debugSupported ?? (!kIsWeb && Platform.isAndroid);

  /// Tests stand in for an Android phone with this.
  @visibleForTesting
  static bool? debugSupported;

  /// What was last published, so an ordinary launch does not download their
  /// photo again to draw the same icon. Bump the version when the drawing
  /// changes, or icons already out there keep the old one.
  static const _publishedKey = 'chat_shortcut_published';
  static const _drawing = 1;

  /// What the icon is called: what the app calls them everywhere else.
  static String labelFor(UserProfile partner) {
    final pet = partner.petName?.trim();
    return pet == null || pet.isEmpty ? partner.displayName : pet;
  }

  /// Keeps the shortcut on [partner]: in the app icon's menu, and any copy
  /// on the home screen brought up to date (a new photo, a new name, or the
  /// other account signed in on this phone).
  static Future<void> publish(UserProfile partner,
      {required AvatarDownload download}) async {
    if (!supported) return;
    final signature = [
      _drawing,
      partner.id,
      labelFor(partner),
      partner.avatarPath ?? '',
      partner.avatar ?? '',
      partner.flower.name,
    ].join('|');
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_publishedKey) == signature) return;
      final icon = await chatShortcutIcon(partner, download: download);
      final done = await _channel.invokeMethod<bool>('publish', {
        'name': labelFor(partner),
        'icon': icon,
      });
      if (done == true) await prefs.setString(_publishedKey, signature);
    } on PlatformException catch (e) {
      debugPrint('chat shortcut publish failed: $e');
    } on MissingPluginException {
      // The Dart side shipped ahead of the Kotlin.
    }
  }

  /// Asks the launcher to put [partner]'s chat on the home screen.
  static Future<ChatShortcutPin> pin(UserProfile partner,
      {required AvatarDownload download}) async {
    if (!supported) return ChatShortcutPin.unsupported;
    try {
      final icon = await chatShortcutIcon(partner, download: download);
      final answer = await _channel.invokeMethod<String>('pin', {
        'name': labelFor(partner),
        'icon': icon,
      });
      return switch (answer) {
        'asked' => ChatShortcutPin.asked,
        'already' => ChatShortcutPin.already,
        _ => ChatShortcutPin.unsupported,
      };
    } on PlatformException catch (e) {
      debugPrint('chat shortcut pin failed: $e');
      return ChatShortcutPin.unsupported;
    } on MissingPluginException {
      return ChatShortcutPin.unsupported;
    }
  }

  /// Signed out or unpaired: out of the app icon's menu. A copy on the home
  /// screen stays, since only the person can take it off, and opens the app
  /// to sign in until the next partner published takes it over.
  static Future<void> clear() async {
    if (!supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_publishedKey);
      await _channel.invokeMethod<bool>('clear');
    } on PlatformException catch (e) {
      debugPrint('chat shortcut clear failed: $e');
    } on MissingPluginException {
      // Nothing native to clear.
    }
  }
}

/// The side of an adaptive icon's layer, in pixels: 108dp at 4x.
const chatShortcutIconSize = 432;

/// How much of the layer a launcher shows, whatever its shape: the middle
/// 72dp of 108. The rest is room for its masks and animations.
const chatShortcutIconWindow = chatShortcutIconSize * 72 / 108;

/// [partner]'s face as a PNG adaptive icon: their photo, else the drawn boy
/// or girl they chose, else their flower on the brand gradient, the same
/// order as UserAvatar. Null only when nothing could be drawn at all, and
/// the shortcut then wears the app's own icon.
///
/// ⚠️ **Framed as the app frames them.** Drawn across the whole layer, the
/// launcher would show only its middle two thirds: a face cut off at the
/// forehead and chin. So the picture fills the window the launcher shows,
/// as it fills an avatar's circle in the app, and a blurred copy of it
/// fills the margin round that, so a mask a little larger than usual shows
/// more of the same rather than an edge.
Future<Uint8List?> chatShortcutIcon(UserProfile partner,
    {required AvatarDownload download}) async {
  ui.Image? face;
  try {
    final path = partner.avatarPath;
    final character = partner.character;
    if (path != null && path.isNotEmpty) {
      face = await _decode(await download(path));
    } else if (character != null) {
      final data = await rootBundle.load(character.asset);
      face = await _decode(data.buffer.asUint8List());
    }
  } catch (e) {
    // Offline, or the photo was deleted under the row: their flower, as
    // everywhere else a face cannot be had.
    debugPrint('chat shortcut face failed: $e');
  }

  try {
    const size = chatShortcutIconSize;
    const side = size * 1.0;
    const layer = Rect.fromLTWH(0, 0, side, side);
    // A hair larger than the window, so no edge of it shows inside a mask.
    final window = Rect.fromCenter(
      center: layer.center,
      width: chatShortcutIconWindow + 12,
      height: chatShortcutIconWindow + 12,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, layer);
    if (face != null) {
      // Solid under the blur: a blur thins out towards its edges, and the
      // corners would be see-through.
      paintImage(
          canvas: canvas,
          rect: layer,
          image: face,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium);
      canvas.saveLayer(layer,
          Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18));
      paintImage(
          canvas: canvas,
          rect: layer.inflate(36),
          image: face,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium);
      canvas.restore();
      paintImage(
          canvas: canvas,
          rect: window,
          image: face,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high);
    } else {
      canvas.drawRect(
          layer, Paint()..shader = AppGradients.cta.createShader(layer));
      final flower = TextPainter(
        text: TextSpan(
          text: partner.flower.emoji,
          // Half the window, as FlowerAvatar draws it in its circle.
          style: const TextStyle(fontSize: chatShortcutIconWindow * 0.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      flower.paint(
          canvas, layer.center - Offset(flower.width / 2, flower.height / 2));
    }
    final image = await recorder.endRecording().toImage(size, size);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    face?.dispose();
    return png?.buffer.asUint8List();
  } catch (e) {
    debugPrint('chat shortcut icon failed: $e');
    return null;
  }
}

Future<ui.Image> _decode(Uint8List bytes) async {
  // At its own size: avatars are stored at 512px square (squareAvatarJpeg),
  // close to what is drawn, and a target size would stretch any that is not
  // square.
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

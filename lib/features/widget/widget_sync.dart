import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../tulip/data/flower_repository.dart';

/// Which content the *adaptive* widget shows. The two dedicated widgets
/// ignore this — they always show their own thing.
enum WidgetMode {
  flower,
  heartbeat;

  static WidgetMode fromName(String? v) =>
      v == heartbeat.name ? heartbeat : flower;
}

/// Home-screen widget bridge.
///
/// Three Android providers share one data store:
///  - `TodaysTulipWidget`  → today's flower (tap opens the Flowers tab)
///  - `HeartbeatWidget`    → pulse counts (tap sends a beat in the background)
///  - `DayflowerWidget`       → adaptive; renders whichever [WidgetMode] is set
///
/// `home_widget` is Android/iOS only, so every call is gated on
/// [isSupported] — on web (our dev preview) these are no-ops rather than
/// MissingPluginException crashes.
class DayflowerWidgets {
  DayflowerWidgets._();

  static const appGroupId = 'group.com.dayflower.app';

  static const flowerProvider = 'com.dayflower.app.TodaysTulipWidget';
  static const heartbeatProvider = 'com.dayflower.app.HeartbeatWidget';
  static const adaptiveProvider = 'com.dayflower.app.DayflowerWidget';
  static const iOSWidgetKind = 'TodaysTulipWidget';

  /// Opens the app. Handled in `app.dart`.
  static const flowersDeepLink = 'dayflower://flowers';

  /// Handled in the background isolate — does NOT open the app.
  static const heartbeatAction = 'dayflower://heartbeat';

  /// Tapping the widget's "Send message" pill. Opens the conversation
  /// rather than acting in the background: there is a sentence to type, and
  /// only the app can take one.
  static const replyDeepLink = 'dayflower://chat';

  /// Tapping the widget's tulip. Handled in the background isolate — the
  /// whole point of a one-tap reaction is that it costs no app launch.
  static const tulipAction = 'dayflower://tulip';

  // Keys read by the native layouts. Keep in sync with the Kotlin providers.
  static const keyFlowerEmoji = 'tulip_emoji';
  static const keyFlowerTitle = 'tulip_title';
  static const keyFlowerBody = 'tulip_body';
  static const keyBeatMine = 'beat_mine';
  static const keyBeatPartner = 'beat_partner';
  static const keyBeatPartnerName = 'beat_partner_name';

  /// The local calendar day the counts above belong to, `yyyy-MM-dd`.
  ///
  /// The widget compares this to its own idea of today and renders zero when
  /// they differ. Without it a phone that never opens the app shows
  /// yesterday's tally indefinitely — counts only change when Dart syncs,
  /// and midnight is not an event Dart hears about.
  static const keyBeatDate = 'beat_date';
  static const keyMode = 'widget_mode';

  /// Marks a pulse the widget should ripple for. Read by HeartbeatRipple.kt,
  /// which ignores markers older than 10s so a widget rebuilt after a reboot
  /// doesn't replay one.
  /// Absolute path to the day photo on disk, or empty when there is none.
  /// A file path rather than bytes: RemoteViews has a hard IPC size limit and
  /// a full-size bitmap blows straight through it.
  static const keyDayPhotoPath = 'day_photo_path';

  /// Epoch millis at which the day photo stops being shown.
  ///
  /// The widget enforces this itself. Dart cannot be relied on to clear the
  /// photo: if the app is never opened, no sync ever runs, and a "24 hour"
  /// photo would sit on the home screen for days.
  static const keyDayPhotoExpiresAt = 'day_photo_expires_at';

  /// Whose day the photo is — drives the story header's name and the
  /// initial in its avatar circle. Empty when there is no live photo.
  static const keyDayOwner = 'day_photo_owner';

  /// The owner's avatar flower, as its emoji. Pushed rather than derived in
  /// Kotlin because the choice lives in Postgres and the widget has no
  /// database — the same reason the name is pushed.
  static const keyDayOwnerFlower = 'day_photo_owner_flower';

  /// Absolute path to the partner's avatar, already cropped to a circle and
  /// downscaled. Empty when they have no photo, which is when the widget
  /// falls back to their flower glyph.
  static const keyDayOwnerAvatar = 'day_photo_owner_avatar';

  /// The id of the message the widget is currently showing, so a tulip
  /// tapped there can say what it is answering. Empty when the widget is
  /// on its fallback glyph and there is nothing to reply to.
  static const keyDayPhotoId = 'day_photo_id';

  static const keyBeatPulseAt = 'beat_pulse_at';
  static const keyBeatPulseDir = 'beat_pulse_dir';

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!isSupported) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      await HomeWidget.registerInteractivityCallback(dayflowerWidgetBackground);
    } catch (e) {
      debugPrint('widget init failed: $e');
    }
  }

  /// Redraws every provider. Cheap — Android ignores providers with no
  /// placed instances.
  static Future<void> _refresh() async {
    for (final provider in [flowerProvider, heartbeatProvider, adaptiveProvider]) {
      await HomeWidget.updateWidget(
        qualifiedAndroidName: provider,
        iOSName: provider == flowerProvider ? iOSWidgetKind : null,
      );
    }
  }

  /// Pushes the flower the partner last pinned to this home screen.
  ///
  /// [received] is [widgetFlowerProvider] — the newest incoming flower whose
  /// sender ticked "put it on their home screen". Flowers sent without the
  /// tick live in the conversation and never land here.
  static Future<void> syncFlower({
    required FlowerMessage? received,
    required bool sentToday,
    required String partnerName,
    String partnerFlower = '🌷',
    String? partnerAvatarPath,
    Future<Uint8List> Function(String path)? downloadPhoto,
    Future<Uint8List> Function(String path)? downloadAvatar,
  }) async {
    if (!isSupported) return;

    // A day photo takes the slot when it is the newest widget-bound message.
    // It has to reach the widget as a FILE: RemoteViews cannot carry a large
    // bitmap across the IPC boundary. Written before the text keys so the
    // widget never redraws with a stale photo still on screen.
    String photoPath = '';
    int photoExpiresAt = 0;
    if (received != null && received.isPhoto && received.isFreshForWidget) {
      photoPath = await _cachePhoto(received, downloadPhoto) ?? '';
      if (photoPath.isNotEmpty) {
        photoExpiresAt = received.sentAt
            .add(FlowerMessage.widgetLifetime)
            .millisecondsSinceEpoch;
      }
    }

    late final String emoji, title, body;
    if (photoPath.isNotEmpty) {
      emoji = '📷';
      title = "$partnerName's day";
      body = received?.note ?? 'Tap to open the conversation.';
    } else if (received?.flower != null) {
      final flower = received!.flower!;
      emoji = flower.emoji;
      title = '${flower.name} from $partnerName';
      body = received.note ?? flower.meaning;
    } else if (sentToday) {
      emoji = '🌱';
      title = 'On its way';
      body = 'Nothing from $partnerName yet — soon.';
    } else {
      emoji = '🌷';
      title = 'Nothing here yet';
      body = 'Tap to send $partnerName a flower.';
    }

    // Only fetched when there is a photo to sit beside — the header, and
    // therefore the avatar, is hidden without one.
    final avatarPath = photoPath.isEmpty
        ? ''
        : await _cacheAvatar(partnerAvatarPath, downloadAvatar) ?? '';

    try {
      await HomeWidget.saveWidgetData<String>(keyDayPhotoPath, photoPath);
      await HomeWidget.saveWidgetData<String>(keyDayOwnerAvatar, avatarPath);
      await HomeWidget.saveWidgetData<String>(
          keyDayPhotoId, photoPath.isEmpty ? '' : (received?.id ?? ''));
      await HomeWidget.saveWidgetData<String>(
          keyDayOwner, photoPath.isEmpty ? '' : partnerName);
      await HomeWidget.saveWidgetData<String>(
          keyDayOwnerFlower, photoPath.isEmpty ? '' : partnerFlower);
      await HomeWidget.saveWidgetData<int>(
          keyDayPhotoExpiresAt, photoExpiresAt);
      await HomeWidget.saveWidgetData<String>(keyFlowerEmoji, emoji);
      await HomeWidget.saveWidgetData<String>(keyFlowerTitle, title);
      await HomeWidget.saveWidgetData<String>(keyFlowerBody, body);
      await _refresh();
    } catch (e) {
      debugPrint('widget flower sync failed: $e');
    }
  }

  /// Caches the partner's avatar as a circular PNG the widget can show.
  ///
  /// ⚠️ **Rounded here, not there.** RemoteViews cannot clip an ImageView
  /// to a circle — there is no `ShapeableImageView` on its supported list
  /// and no way to apply an outline provider across the IPC boundary. So
  /// the circle is cut in Dart and what crosses is a PNG that is already
  /// round, with transparent corners.
  ///
  /// Small on purpose: it draws at 30dp, so 96px covers a 3× screen with
  /// room to spare, and RemoteViews has a hard bitmap budget that the day
  /// photo is already spending most of.
  static Future<String?> _cacheAvatar(
    String? storagePath,
    Future<Uint8List> Function(String path)? downloadAvatar,
  ) async {
    if (storagePath == null || storagePath.isEmpty) return null;
    if (downloadAvatar == null) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      // Keyed on the storage path, so changing your photo writes a new file
      // and the widget cannot keep showing the old face.
      final name = storagePath.hashCode.toUnsigned(32).toRadixString(16);
      final file = File('${dir.path}/avatar_$name.png');
      if (!await file.exists()) {
        final bytes = await downloadAvatar(storagePath);
        final circle = await compute(circleAvatarPng, bytes);
        if (circle == null) return null;
        await file.writeAsBytes(circle);
        await _pruneOldAvatars(dir, keep: file.path);
      }
      return file.path;
    } catch (e) {
      debugPrint('avatar cache failed: $e');
      return null;
    }
  }

  static Future<void> _pruneOldAvatars(Directory dir,
      {required String keep}) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File &&
            entity.path.contains('avatar_') &&
            entity.path != keep) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Litter, not a failure. The widget already has what it needs.
    }
  }

  /// Writes the photo to a stable on-disk path the Android widget can read.
  ///
  /// One fixed filename per pair-photo id, so repeated syncs of the same
  /// photo skip the download entirely — the widget refreshes far more often
  /// than the photo changes.
  static Future<String?> _cachePhoto(
    FlowerMessage message,
    Future<Uint8List> Function(String path)? downloadPhoto,
  ) async {
    if (downloadPhoto == null) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/day_photo_${message.id}.jpg');
      if (!await file.exists()) {
        await file.writeAsBytes(await downloadPhoto(message.imagePath!));
        // Yesterday's photos are dead weight once the slot has moved on.
        await _pruneOldPhotos(dir, keep: file.path);
      }
      return file.path;
    } catch (e) {
      debugPrint('day photo cache failed: $e');
      return null;
    }
  }

  static Future<void> _pruneOldPhotos(Directory dir,
      {required String keep}) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File &&
            entity.path.contains('day_photo_') &&
            entity.path != keep) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Housekeeping only — never worth failing a sync over.
    }
  }

  /// Pushes today's heartbeat counts.
  ///
  /// [pulseSent] makes the widget ripple: true for a beat you just sent, false
  /// for one that just arrived, null for a plain refresh with no animation.
  static Future<void> syncHeartbeat({
    required int mine,
    required int partner,
    required String partnerName,
    bool? pulseSent,
  }) async {
    if (!isSupported) return;
    try {
      await HomeWidget.saveWidgetData<String>(keyBeatMine, '$mine');
      await HomeWidget.saveWidgetData<String>(keyBeatPartner, '$partner');
      await HomeWidget.saveWidgetData<String>(keyBeatDate, _localDateKey());
      await HomeWidget.saveWidgetData<String>(keyBeatPartnerName, partnerName);
      if (pulseSent != null) await _markPulse(sent: pulseSent);
      await _refresh();
    } catch (e) {
      debugPrint('widget heartbeat sync failed: $e');
    }
  }

  /// `yyyy-MM-dd` in local time. Must match the format HeartbeatWidget.kt
  /// builds, or the widget reads every day as stale and shows zero forever.
  static String _localDateKey() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  /// Leaves the marker HeartbeatRipple.kt looks for on its next redraw.
  static Future<void> _markPulse({required bool sent}) async {
    await HomeWidget.saveWidgetData<String>(
      keyBeatPulseAt,
      '${DateTime.now().millisecondsSinceEpoch}',
    );
    await HomeWidget.saveWidgetData<String>(
      keyBeatPulseDir,
      sent ? 'sent' : 'received',
    );
  }

  /// Sets what the adaptive widget renders.
  static Future<void> setMode(WidgetMode mode) async {
    if (!isSupported) return;
    try {
      await HomeWidget.saveWidgetData<String>(keyMode, mode.name);
      await _refresh();
    } catch (e) {
      debugPrint('widget mode set failed: $e');
    }
  }

  static Future<WidgetMode> currentMode() async {
    if (!isSupported) return WidgetMode.flower;
    try {
      return WidgetMode.fromName(
        await HomeWidget.getWidgetData<String>(keyMode),
      );
    } catch (_) {
      return WidgetMode.flower;
    }
  }
}

/// Runs in a background isolate when the Heartbeat widget is tapped — the
/// app is never opened, so nothing from the running app is available here:
/// Flutter bindings, dotenv and Supabase all have to be set up again.
/// Supabase restores the persisted session itself, which is what lets this
/// send as whoever is currently signed in.
@pragma('vm:entry-point')
Future<void> dayflowerWidgetBackground(Uri? uri) async {
  final host = uri?.host;
  if (host != 'heartbeat' && host != 'tulip') return;

  try {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return; // signed out — nothing to send as

    final pairs = await client
        .from('pairs')
        .select('id')
        .or('user_a.eq.$userId,user_b.eq.$userId')
        .limit(1);
    if (pairs.isEmpty) return;

    final pairId = pairs.first['id'] as String;

    // A tulip tapped on the widget is a reaction to the day photo the
    // widget is showing, so it carries `reply_to` — otherwise it arrives in
    // the thread as an unexplained flower some hours after the thing it
    // answers. The id is written alongside the photo at sync time; empty
    // means the widget is on its fallback glyph, and then it is simply a
    // flower with nothing to quote.
    if (host == 'tulip') {
      final replyTo =
          await HomeWidget.getWidgetData<String>(DayflowerWidgets.keyDayPhotoId);
      await client.from('flower_messages').insert({
        'pair_id': pairId,
        'sender_id': userId,
        'flower_type': 'classic_tulip',
        // It answers what is already on their home screen rather than
        // replacing it.
        'to_widget': false,
        if (replyTo != null && replyTo.isNotEmpty) 'reply_to': replyTo,
      });
      return;
    }

    await client.from('heartbeats').insert({
      'pair_id': pairId,
      'sender_id': userId,
    });

    // Bump the count straight away so the widget acknowledges the tap
    // without waiting for the app to next run a sync.
    final shown =
        int.tryParse(await HomeWidget.getWidgetData<String>(
              DayflowerWidgets.keyBeatMine,
            ) ??
            '0') ??
        0;
    await HomeWidget.saveWidgetData<String>(
      DayflowerWidgets.keyBeatMine,
      '${shown + 1}',
    );
    // Ripple the widget the tap came from. This isolate is alive precisely
    // because of that tap, so it's the one case that always animates.
    await DayflowerWidgets._markPulse(sent: true);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: DayflowerWidgets.heartbeatProvider,
    );
    await HomeWidget.updateWidget(
      qualifiedAndroidName: DayflowerWidgets.adaptiveProvider,
    );
  } catch (e) {
    debugPrint('widget heartbeat background send failed: $e');
  }
}

/// Crops [bytes] to a circle and downscales it, for the widget's avatar.
///
/// Top-level so it can run in a `compute` isolate — decoding and redrawing
/// even a small image on the UI thread is visible jank during a sync that
/// already downloads a day photo.
///
/// Returns null rather than throwing on unreadable input. ⚠️ Do not
/// "simplify" that to returning the input: `img.decodeImage` throws on
/// truncated bytes rather than returning null, and a non-circular PNG here
/// would render as a square face inside a round header.
Uint8List? circleAvatarPng(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    const size = 96;
    final square = img.copyResizeCropSquare(decoded, size: size);
    final out = img.Image(width: size, height: size, numChannels: 4);

    // A hand-cut circle rather than a mask blend: `image` has no alpha
    // compositing primitive that keeps the source's own colours, and the
    // arithmetic is two lines.
    const centre = size / 2;
    const radius = size / 2;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = x + 0.5 - centre;
        final dy = y + 0.5 - centre;
        if (dx * dx + dy * dy <= radius * radius) {
          out.setPixel(x, y, square.getPixel(x, y));
        }
      }
    }
    return Uint8List.fromList(img.encodePng(out));
  } catch (_) {
    return null;
  }
}

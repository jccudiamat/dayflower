import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/flower_repository.dart';
import '../../../../core/widgets/storage_image.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../onboarding/data/user_repository.dart';

/// Saving a picture into the phone's own gallery.
///
/// ⚠️ **Not the app's folder.** `share_your_day.dart` already writes a photo
/// to `getExternalStorageDirectory()/Saved`, which is somewhere nothing else
/// looks — a Save that puts a picture where the Gallery will never show it
/// is a button that lies. This goes through MediaStore (`MediaSaver.kt`) and
/// lands in DCIM, beside the phone's own pictures — not in an app album,
/// which is somewhere people have to go looking for.
class MediaSaver {
  MediaSaver._();

  static const _channel = MethodChannel('dayflower/media');

  /// True when it actually saved. ⚠️ Never throws and never guesses —
  /// pre-Android-10 returns false rather than writing somewhere invisible
  /// and reporting success.
  static Future<bool> save(Uint8List bytes, String name) async {
    try {
      final ok = await _channel.invokeMethod<bool>('saveImage', {
        'bytes': bytes,
        'name': name,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// What a picture in the thread opens into.
///
/// One viewer for both kinds, because from the reader's side they are the
/// same thing: a picture somebody sent, big enough to look at properly and
/// worth keeping. A day photo comes down as a signed URL; a flower is a
/// bundled asset. Only [_bytes] cares which.
class MediaViewer extends ConsumerStatefulWidget {
  const MediaViewer({
    super.key,
    required this.title,
    this.subtitle,
    this.caption,
    this.imagePath,
    this.asset,
    required this.fileName,
  }) : assert(imagePath != null || asset != null,
            'a viewer with nothing to view');

  /// Storage path of a day photo, signed on open.
  final String? imagePath;

  /// Bundled flower artwork.
  final String? asset;

  final String title;
  final String? subtitle;

  /// What the sender wrote with it, under the picture.
  final String? caption;
  final String fileName;

  @override
  ConsumerState<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends ConsumerState<MediaViewer> {
  bool _saving = false;

  /// ⚠️ The button says so itself rather than a toast saying it for it. A
  /// snackbar over a full-screen picture covers the picture, and it leaves
  /// nothing behind — come back to the same photo a minute later and there
  /// is no way to tell whether you already have it.
  bool _saved = false;

  Future<Uint8List> _bytes() async {
    final path = widget.imagePath;
    if (path != null) {
      return ref.read(flowerRepositoryProvider).downloadPhoto(path);
    }
    final data = await rootBundle.load(widget.asset!);
    return data.buffer.asUint8List();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    var ok = false;
    try {
      ok = await MediaSaver.save(await _bytes(), widget.fileName);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = ok;
    });
    // Only failure still interrupts. Success is on the button; a failure
    // has to say *something*, or the button simply not changing is the
    // whole error message.
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save that picture.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.xs, AppSpace.xs, AppSpace.sm, AppSpace.xs),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const AppIcon(CupertinoIcons.xmark,
                        color: Colors.white, size: 20),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: AppText.subtitle(Colors.white)),
                        if (widget.subtitle != null)
                          Text(widget.subtitle!,
                              style: AppText.caption(AppColors.onDarkMuted)),
                      ],
                    ),
                  ),
                  _SaveButton(
                    saving: _saving,
                    saved: _saved,
                    onTap: _save,
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                // Pinch and pan, which is the other half of "view it
                // properly" — a picture you cannot zoom is still a thumbnail.
                minScale: 1,
                maxScale: 4,
                child: Center(child: _image()),
              ),
            ),
            if (widget.caption != null && widget.caption!.trim().isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.sm),
                  child: Text(
                    widget.caption!.trim(),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _image() {
    final asset = widget.asset;
    if (asset != null) {
      return Image.asset(asset, fit: BoxFit.contain);
    }
    // The same cached photo the bubble drew - opening it is instant - but
    // decoded larger, because this one can be pinched to 4x.
    return StorageImage.dayPhoto(
      widget.imagePath!,
      fit: BoxFit.contain,
      decodeWidth: MediaQuery.sizeOf(context).width * 2,
      placeholder: const CircularProgressIndicator(color: Colors.white),
      error: (retry) => GestureDetector(
        onTap: retry,
        child: Text('Photo unavailable',
            style: AppText.body(AppColors.onDarkMuted)),
      ),
    );
  }
}

/// Save, saving, saved — one control that reports its own outcome.
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.saving,
    required this.saved,
    required this.onTap,
  });

  final bool saving;
  final bool saved;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    if (saving) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    return TextButton.icon(
      // Tapping again would write a second copy. Once it is in the gallery
      // the button has nothing left to offer.
      onPressed: saved ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: AppColors.success,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      icon: AppIcon(
        saved
            ? CupertinoIcons.checkmark_alt
            : CupertinoIcons.arrow_down_to_line,
        size: 19,
      ),
      label: Text(
        saved ? 'Saved' : 'Save',
        style: AppText.body(saved ? AppColors.success : Colors.white)
            .copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Opens [MediaViewer] over the thread.
///
/// ⚠️ `useRootNavigator` so it covers the bottom nav as well. A full-screen
/// viewer with the app's tab bar still showing underneath reads as a panel,
/// not as the picture.
Future<void> showMediaViewer(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? caption,
  String? imagePath,
  String? asset,
  required String fileName,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => MediaViewer(
        title: title,
        subtitle: subtitle,
        caption: caption,
        imagePath: imagePath,
        asset: asset,
        fileName: fileName,
      ),
    ),
  );
}

/// Opens a photo from the thread the way WhatsApp heads one: who sent it
/// and when, with the caption under the picture.
///
/// 🔴 Every photo used to open as "Your day" or "Their day", including the
/// ones sent from the chat's own camera and gallery buttons, which are
/// photos from a person and never went near the home screen. Only a My Day
/// post is a day, and says so.
Future<void> showPhotoMessage(
  BuildContext context,
  WidgetRef ref,
  FlowerMessage message,
) async {
  final mine = message.senderId == ref.read(currentUserIdProvider);
  // Loaded already wherever the chat is on screen; waited for briefly
  // anywhere it is not, rather than heading their photo "Your partner".
  final partner = ref.read(partnerProfileProvider).valueOrNull ??
      await ref
          .read(partnerProfileProvider.future)
          .timeout(const Duration(seconds: 2), onTimeout: () => null)
          .catchError((Object _) => null);
  if (!context.mounted) return;
  final name = partner?.petName ?? partner?.displayName ?? 'Your partner';
  final note = (message.note ?? '').trim();
  // A card's note opens with the occasion its maker wrote; only the rest is
  // the person talking, as in the bubble.
  final caption =
      message.isCard ? note.split('\n').skip(1).join('\n').trim() : note;
  await showMediaViewer(
    context,
    title: message.toWidget
        ? (mine ? 'Your day' : '$name’s day')
        : (mine ? 'You' : name),
    subtitle: sentAtLabel(message.sentAt),
    caption: caption.isEmpty ? null : caption,
    imagePath: message.imagePath,
    fileName: message.toWidget
        ? 'dayflower-day-${message.id}.jpg'
        : 'dayflower-photo-${message.id}.jpg',
  );
}

/// When something was sent, for a header: "Today, 9:41 AM", "Yesterday,
/// 9:41 AM", the weekday inside a week, then the date.
String sentAtLabel(DateTime sentAt, {DateTime? now}) {
  final at = sentAt.toLocal();
  final clock = now ?? DateTime.now();
  final days = DateTime(clock.year, clock.month, clock.day)
      .difference(DateTime(at.year, at.month, at.day))
      .inDays;
  final time = DateFormat('h:mm a').format(at);
  if (days <= 0) return 'Today, $time';
  if (days == 1) return 'Yesterday, $time';
  if (days < 7) return '${DateFormat('EEEE').format(at)}, $time';
  if (at.year == clock.year) return '${DateFormat('d MMM').format(at)}, $time';
  return '${DateFormat('d MMM y').format(at)}, $time';
}

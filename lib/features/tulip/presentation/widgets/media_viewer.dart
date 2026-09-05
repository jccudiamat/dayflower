import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/flower_repository.dart';

/// Saving a picture into the phone's own gallery.
///
/// ⚠️ **Not the app's folder.** `share_your_day.dart` already writes a photo
/// to `getExternalStorageDirectory()/Saved`, which is somewhere nothing else
/// looks — a Save that puts a picture where the Gallery will never show it
/// is a button that lies. This goes through MediaStore (`MediaSaver.kt`) and
/// lands in Pictures/Dayflower.
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
  final String fileName;

  @override
  ConsumerState<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends ConsumerState<MediaViewer> {
  bool _saving = false;

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
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Saved to your gallery 🌷'
              // ⚠️ Says it did not happen. The old app-folder save reported
              // success for a file no gallery would ever list.
              : "Couldn't save that picture.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.xs,
                  AppSpace.sm, AppSpace.xs),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(CupertinoIcons.xmark,
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
                  IconButton(
                    onPressed: _saving ? null : _save,
                    tooltip: 'Save to your gallery',
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(CupertinoIcons.arrow_down_to_line,
                            color: Colors.white, size: 22),
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
    return FutureBuilder<String>(
      future: ref
          .read(flowerRepositoryProvider)
          .signedPhotoUrl(widget.imagePath!, ttl: const Duration(hours: 1)),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const CircularProgressIndicator(color: Colors.white);
        }
        return Image.network(
          snap.data!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(
            'Photo unavailable',
            style: AppText.body(AppColors.onDarkMuted),
          ),
        );
      },
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
        imagePath: imagePath,
        asset: asset,
        fileName: fileName,
      ),
    ),
  );
}

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/data/user_repository.dart';
import '../../features/tulip/data/flower_repository.dart';
import '../theme/app_colors.dart';

/// Which private bucket an image lives in.
enum StorageBucket { dayPhotos, avatars }

/// Signs a storage path into a URL that can be downloaded, once.
typedef StorageSigner = Future<String> Function(String path);

/// The disk cache every private image shares.
///
/// Its own cache rather than CachedNetworkImage's default one: entries here
/// are keyed by *storage path*, never by URL, and must not be evicted by the
/// gift catalogue's public product photos filling the other.
class StorageImageCache {
  StorageImageCache._();

  static BaseCacheManager _manager = CacheManager(
    Config(
      'dayflower_private_images',
      // Paths are never reused - every upload gets a fresh uuid - so a
      // cached file is never stale, only unused. This only bounds the disk.
      stalePeriod: const Duration(days: 60),
      maxNrOfCacheObjects: 800,
    ),
  );

  static BaseCacheManager get manager => _manager;

  @visibleForTesting
  static set debugManager(BaseCacheManager value) => _manager = value;

  /// Signing out: another account on this phone must not find these.
  static Future<void> clear() async {
    try {
      await manager.emptyCache();
    } catch (e) {
      debugPrint('private image cache clear failed: $e');
    }
    PaintingBinding.instance.imageCache.clear();
  }
}

/// A private storage object as an image, cached by its **path**.
///
/// 🔴 **Why every photo in the app used to blink.** Private objects are read
/// through signed URLs, and a signed URL is different every time one is
/// made. The chat signed a new one inside `build()` for every bubble, so a
/// photo scrolled off and back came back under an address no cache had seen:
/// a spinner, a full re-download, a jump. Elsewhere the URL was stable for
/// the session but drawn with Image.network - no disk cache, so every launch
/// downloaded everything again, and every photo decoded at full camera size,
/// so a few 12-megapixel pictures pushed each other out of the 100 MB
/// in-memory cache while you scrolled.
///
/// Here the identity is (bucket, path), which never changes for an object.
/// The memory cache and the disk cache both key on it, and a URL is signed
/// only on a disk miss - so a photo seen once is never fetched again, on
/// any screen, in any session.
@immutable
class StorageImageProvider extends ImageProvider<StorageImageProvider> {
  const StorageImageProvider({
    required this.bucket,
    required this.path,
    required this.sign,
    this.cacheManager,
  });

  final StorageBucket bucket;
  final String path;

  /// Only called on a disk miss. Deliberately outside equality: two widgets
  /// holding different closures for the same object are the same image.
  final StorageSigner sign;

  /// Tests pass their own.
  final BaseCacheManager? cacheManager;

  String get cacheKey => '${bucket.name}/$path';

  @override
  Future<StorageImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<StorageImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    StorageImageProvider key,
    ImageDecoderCallback decode,
  ) =>
      MultiFrameImageStreamCompleter(
        codec: _load(decode),
        scale: 1,
        debugLabel: cacheKey,
      );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final manager = cacheManager ?? StorageImageCache.manager;
    Uint8List? bytes;
    final cached = await manager.getFileFromCache(cacheKey);
    if (cached != null) {
      try {
        bytes = await cached.file.readAsBytes();
      } catch (_) {
        // The OS can clear an app's cache folder under storage pressure,
        // leaving an entry that points at nothing. Treated as a miss, or
        // every retry would fail the same way forever.
      }
      if (bytes == null || bytes.isEmpty) {
        await manager.removeFile(cacheKey);
        bytes = null;
      }
    }
    if (bytes == null) {
      final fresh = await manager.downloadFile(await sign(path), key: cacheKey);
      bytes = await fresh.file.readAsBytes();
      if (bytes.isEmpty) {
        await manager.removeFile(cacheKey);
        throw StateError('empty image $cacheKey');
      }
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is StorageImageProvider &&
      other.bucket == bucket &&
      other.path == path;

  @override
  int get hashCode => Object.hash(bucket, path);

  @override
  String toString() => 'StorageImageProvider($cacheKey)';
}

/// A private photo, drawn from the cache whenever it can be.
///
/// Use this for anything in the day-photo or avatar bucket - never
/// Image.network with a signed URL, which is what made every screen blink.
///
/// ⚠️ Decoded at the size it is drawn, not the size it was taken. A phone
/// photo is 12 megapixels - 48 MB once decoded - against a 100-200 MB
/// in-memory cache. Pass [decodeWidth] for anything smaller than the screen.
class StorageImage extends ConsumerStatefulWidget {
  const StorageImage({
    super.key,
    required this.bucket,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.decodeWidth,
    this.placeholder,
    this.placeholderHeight,
    this.error,
    this.semanticLabel,
  });

  /// A day photo, a booth strip, anything in the day-photo bucket.
  const StorageImage.dayPhoto(
    String path, {
    Key? key,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Alignment alignment = Alignment.center,
    double? decodeWidth,
    Widget? placeholder,
    double? placeholderHeight,
    Widget Function(VoidCallback retry)? error,
    String? semanticLabel,
  }) : this(
          key: key,
          bucket: StorageBucket.dayPhotos,
          path: path,
          fit: fit,
          width: width,
          height: height,
          alignment: alignment,
          decodeWidth: decodeWidth,
          placeholder: placeholder,
          placeholderHeight: placeholderHeight,
          error: error,
          semanticLabel: semanticLabel,
        );

  final StorageBucket bucket;
  final String path;
  final BoxFit fit;
  final double? width, height;
  final Alignment alignment;

  /// Logical pixels. Defaults to the screen's width, which is the most any
  /// photo in the app is drawn at except in the viewer.
  final double? decodeWidth;

  /// Shown only while a photo is loaded for the first time. A photo already
  /// in memory is drawn on the first frame, so this never flashes over it.
  final Widget? placeholder;

  /// The placeholder's height where the image has none of its own - a chat
  /// photo sizes itself from the picture, which is not there yet.
  final double? placeholderHeight;

  /// Given a retry that forces a fresh attempt.
  final Widget Function(VoidCallback retry)? error;

  /// Null means decorative.
  final String? semanticLabel;

  /// The provider this draws, decoded at [logicalWidth] for the given
  /// [devicePixelRatio]. Public so a screen can precache what it is about
  /// to show.
  static ImageProvider providerFor(
    WidgetRef ref, {
    required StorageBucket bucket,
    required String path,
    required double logicalWidth,
    required double devicePixelRatio,
  }) {
    final base = StorageImageProvider(
      bucket: bucket,
      path: path,
      sign: switch (bucket) {
        StorageBucket.dayPhotos => (p) => ref
            .read(flowerRepositoryProvider)
            .signedPhotoUrl(p, ttl: const Duration(minutes: 30)),
        StorageBucket.avatars => (p) =>
            ref.read(userRepositoryProvider).signedAvatarUrl(p),
      },
    );
    final width = decodePixels(logicalWidth, devicePixelRatio);
    return ResizeImage(base, width: width, allowUpscaling: false);
  }

  /// The width a photo is decoded at, in physical pixels.
  ///
  /// Bucketed to the next 64px so screens drawing the same photo at nearly
  /// the same size share one decode instead of keeping two, and capped at
  /// 2048 - past that a phone screen cannot show the difference.
  static int decodePixels(double logicalWidth, double devicePixelRatio) {
    final px = (logicalWidth * devicePixelRatio).clamp(64, 2048);
    return ((px / 64).ceil() * 64).toInt();
  }

  @override
  ConsumerState<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends ConsumerState<StorageImage> {
  /// Bumped by retry. The Image widget holds its stream for as long as the
  /// provider is equal, so a retry needs a new widget, not a rebuild.
  int _attempt = 0;

  void _retry() {
    // Failed loads are never kept by ImageCache, so a fresh Image resolving
    // the same provider genuinely tries again.
    setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final image = StorageImage.providerFor(
      ref,
      bucket: widget.bucket,
      path: widget.path,
      logicalWidth: widget.decodeWidth ?? media.size.width,
      devicePixelRatio: media.devicePixelRatio,
    );
    Widget placeholder() =>
        widget.placeholder ??
        SizedBox(
          width: widget.width,
          height: widget.height ?? widget.placeholderHeight,
          child: ColoredBox(color: AppColors.surfaceSubtle),
        );
    return Image(
      key: ValueKey(_attempt),
      image: image,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      // Keep the last frame while a new provider resolves, rather than
      // dropping to nothing for a frame.
      gaplessPlayback: true,
      semanticLabel: widget.semanticLabel,
      excludeFromSemantics: widget.semanticLabel == null,
      frameBuilder: (context, child, frame, synchronous) {
        // In memory already: the first build has it, no placeholder at all.
        if (synchronous || frame != null) return child;
        return placeholder();
      },
      errorBuilder: (context, _, __) =>
          widget.error?.call(_retry) ??
          SizedBox(
            width: widget.width,
            height: widget.height ?? widget.placeholderHeight,
            child: ColoredBox(
              color: AppColors.surfaceSubtle,
              child: Center(
                child: IconButton(
                  tooltip: 'Retry photo',
                  onPressed: _retry,
                  icon: Icon(Icons.refresh, color: AppColors.muted),
                ),
              ),
            ),
          ),
    );
  }
}

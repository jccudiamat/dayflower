import 'dart:async';

import 'package:dayflower/core/widgets/storage_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 🔴 Photos blinked everywhere - worst when scrolling back up the chat -
/// because they were cached, when at all, under signed URLs, and a signed URL
/// is new every time one is made. These hold the three things that stop it:
/// one download per photo ever, identity by storage path, and a photo that
/// comes back on screen drawn on its first frame with no placeholder.
final _png = img.encodePng(img.Image(width: 8, height: 6));

class _Downloads extends FileService {
  int calls = 0;

  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    calls++;
    return _Response();
  }
}

class _Response implements FileServiceResponse {
  @override
  Stream<List<int>> get content => Stream.value(_png);
  @override
  int? get contentLength => _png.length;
  @override
  int get statusCode => 200;
  @override
  DateTime get validTill => DateTime.now().add(const Duration(days: 7));
  @override
  String? get eTag => null;
  @override
  String get fileExtension => '.png';
}

var _configs = 0;
CacheManager _manager(_Downloads downloads) => CacheManager(Config(
      'storage-image-test-${_configs++}',
      repo: NonStoringObjectProvider(),
      fileSystem: MemoryCacheSystem(),
      fileService: downloads,
    ));

Future<void> _load(ImageProvider provider) {
  final done = Completer<void>();
  provider.resolve(ImageConfiguration.empty).addListener(ImageStreamListener(
        (_, __) {
          if (!done.isCompleted) done.complete();
        },
        onError: (error, _) {
          if (!done.isCompleted) done.completeError(error);
        },
      ));
  return done.future;
}

void main() {
  tearDown(() => PaintingBinding.instance.imageCache.clear());

  test('a photo is the same image whoever asks for it, however signed', () {
    Future<String> a(String p) async => 'https://x/$p?token=1';
    Future<String> b(String p) async => 'https://x/$p?token=2';
    const path = 'pair/photo.jpg';
    final one = StorageImageProvider(
        bucket: StorageBucket.dayPhotos, path: path, sign: a);
    final two = StorageImageProvider(
        bucket: StorageBucket.dayPhotos, path: path, sign: b);
    expect(one, two);
    expect(one.hashCode, two.hashCode);
    // The same path in another bucket is another object.
    expect(
        one,
        isNot(StorageImageProvider(
            bucket: StorageBucket.avatars, path: path, sign: a)));
  });

  testWidgets('signed and downloaded once, then never again', (tester) async {
    final downloads = _Downloads();
    var signs = 0;
    Future<String> sign(String p) async => 'https://x/$p?token=${++signs}';

    // ⚠️ Everything inside runAsync, the manager included: made on the test's
    // fake clock, its internal futures never resolve in real time.
    await tester.runAsync(() async {
      final manager = _manager(downloads);
      await _load(StorageImageProvider(
          bucket: StorageBucket.dayPhotos,
          path: 'pair/a.jpg',
          sign: sign,
          cacheManager: manager));
      expect(signs, 1);
      expect(downloads.calls, 1);

      // Memory emptied - a long scroll, or the app backgrounded - and a
      // rebuilt widget with a new signing closure asks again.
      PaintingBinding.instance.imageCache.clear();
      await _load(StorageImageProvider(
          bucket: StorageBucket.dayPhotos,
          path: 'pair/a.jpg',
          sign: sign,
          cacheManager: manager));
      expect(signs, 1, reason: 'served from disk, no new URL');
      expect(downloads.calls, 1, reason: 'served from disk, no download');
    });
  });

  testWidgets('scrolled back into view, it is there on the first frame',
      (tester) async {
    final downloads = _Downloads();
    const decodeWidth = 100.0;
    Widget photo() => const ProviderScope(
          child: MaterialApp(
            home: Center(
              child: StorageImage.dayPhoto('pair/b.jpg',
                  width: 100,
                  height: 75,
                  decodeWidth: decodeWidth,
                  placeholder: Text('placeholder')),
            ),
          ),
        );

    // Seen once already: on disk, and loaded into memory under exactly the
    // key the widget will ask for. The signer would throw - there is no
    // network here, and a photo seen before must not need one.
    await tester.runAsync(() async {
      final manager = _manager(downloads);
      StorageImageCache.debugManager = manager;
      await manager.putFile('dayPhotos/pair/b.jpg', _png, fileExtension: 'png');
      await _load(ResizeImage(
        StorageImageProvider(
          bucket: StorageBucket.dayPhotos,
          path: 'pair/b.jpg',
          sign: (_) async => throw StateError('no network'),
          cacheManager: manager,
        ),
        width: StorageImage.decodePixels(
            decodeWidth, tester.view.devicePixelRatio),
        allowUpscaling: false,
      ));
    });

    // Scrolled back into view: a brand-new widget for the same photo.
    await tester.pumpWidget(photo());
    // 🔴 The whole bug: no placeholder, not even for one frame.
    expect(find.text('placeholder'), findsNothing);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(downloads.calls, 0);
  });
}

import 'dart:async';

import 'package:dayflower/core/widgets/storage_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Runs before every test file (flutter_test picks this file up by name).
///
/// ⚠️ Private photos draw through StorageImage, whose real disk cache sits
/// on sqflite and path_provider - plugins with no answer in a test - and
/// whose decoding needs the real clock, which a widget test's fake one never
/// hands over. A photo would load forever, and any screen showing a spinner
/// while it waited would never settle.
///
/// So every test starts offline: the cache refuses at once, on the test's
/// own clock, and the photo shows its error state - exactly what a phone
/// with no connection and nothing cached would show. A test that wants a
/// real photo installs a real manager inside runAsync; see
/// storage_image_test.dart.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  StorageImageCache.debugManager = _Offline();
  await testMain();
}

class _Offline implements BaseCacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(StateError('no private images in tests'));
}

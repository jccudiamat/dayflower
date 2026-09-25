import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';

/// What a report is about. Stored by [name], which migration 0048 checks.
enum FeedbackKind {
  bug('Bug', 'What happened, and what did you expect to happen?'),
  suggestion('Suggestion', 'What would make Dayflower better for you two?');

  const FeedbackKind(this.label, this.prompt);

  final String label;

  /// The field's hint: the question each kind of report answers.
  final String prompt;
}

/// A picture attached to a report, as picked.
typedef FeedbackImage = ({Uint8List bytes, String extension});

/// Bugs and suggestions, sent to the people who make Dayflower.
///
/// Rows in `feedback`, screenshots in the private `feedback` bucket
/// (migration 0048). The app can write them and read back only its own;
/// they are read in the Supabase dashboard.
class FeedbackRepository {
  FeedbackRepository(this._client);

  final SupabaseClient _client;

  static const bucket = 'feedback';

  /// At most this many screenshots per report, as the table checks.
  static const maxImages = 3;

  /// Longest a report may be, as the table checks.
  static const maxLength = 4000;

  Future<void> send({
    required String userId,
    required FeedbackKind kind,
    required String message,
    List<FeedbackImage> images = const [],
    String? appVersion,
  }) async {
    assert(images.length <= maxImages);
    final uploaded = <String>[];
    try {
      for (final image in images) {
        final ext = image.extension == 'png' ? 'png' : 'jpg';
        // <user_id>/… : the first folder is what the storage policy reads.
        final path = '$userId/${DateTime.now().microsecondsSinceEpoch}-'
            '${Random().nextInt(1 << 32)}.$ext';
        await _client.storage.from(bucket).uploadBinary(
              path,
              image.bytes,
              fileOptions: FileOptions(
                contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
                upsert: false,
              ),
            );
        uploaded.add(path);
      }
      // ⚠️ No `.select()`: nothing here needs the row back, and asking for
      // it would make a send depend on the read policy as well.
      await _client.from('feedback').insert({
        'user_id': userId,
        'kind': kind.name,
        'message': message.trim(),
        'image_paths': uploaded,
        if (appVersion != null) 'app_version': appVersion,
        'platform': platformLabel(),
      });
    } catch (_) {
      // The report did not land, so neither should its screenshots: a
      // picture of someone's messages with no report to explain it is not
      // worth keeping. Best effort; the failure worth reporting is the one
      // being rethrown.
      if (uploaded.isNotEmpty) {
        try {
          await _client.storage.from(bucket).remove(uploaded);
        } catch (e) {
          debugPrint('feedback cleanup failed: $e');
        }
      }
      rethrow;
    }
  }

  /// "android 14 (…)", or "web": what a bug needs to be reproduced on.
  static String platformLabel() {
    if (kIsWeb) return 'web';
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => FeedbackRepository(ref.watch(supabaseClientProvider)),
);

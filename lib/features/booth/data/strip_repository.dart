import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';
import '../../tulip/data/flower_repository.dart';
import '../domain/strip_compositor.dart';
import '../domain/strip_templates.dart';

/// A booth strip: one templated photo, made of one or two halves.
///
/// Solo templates never become rows — they composite and post immediately.
/// A row exists only when there is something to wait for.
class PhotoStrip {
  const PhotoStrip({
    required this.id,
    required this.pairId,
    required this.template,
    required this.aUser,
    required this.aPath,
    this.bUser,
    this.bPath,
    this.completedAt,
    required this.createdAt,
  });

  final String id;
  final String pairId;
  final String template;
  final String aUser;
  final String aPath;
  final String? bUser;
  final String? bPath;
  final DateTime? completedAt;
  final DateTime createdAt;

  StripTemplate get style => StripTemplate.byId(template);
  bool get isComplete => completedAt != null;

  /// Both halves are in but the composite never got posted — a send that
  /// died between filling slot B and uploading the result. Recoverable.
  bool get isFullButUnposted => bPath != null && completedAt == null;

  factory PhotoStrip.fromMap(Map<String, dynamic> m) => PhotoStrip(
        id: m['id'] as String,
        pairId: m['pair_id'] as String,
        template: m['template'] as String,
        aUser: m['a_user'] as String,
        aPath: m['a_path'] as String,
        bUser: m['b_user'] as String?,
        bPath: m['b_path'] as String?,
        completedAt: m['completed_at'] == null
            ? null
            : DateTime.parse(m['completed_at'] as String).toLocal(),
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

class StripRepository {
  StripRepository(this._client, this._flowers);

  final SupabaseClient _client;
  final FlowerRepository _flowers;

  /// Open strips for the pair, newest first. Live, so a half started on one
  /// phone appears on the other without a refresh — which is the entire
  /// point of an async duo.
  Stream<List<PhotoStrip>> watchOpen(String pairId) {
    return _client
        .from('photo_strips')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map(PhotoStrip.fromMap)
            .where((s) => !s.isComplete)
            .toList());
  }

  /// Solo template: composite and post in one go. No row — there is nobody
  /// to wait for, so a strip record would be bookkeeping with no reader.
  Future<void> postSolo({
    required String pairId,
    required String senderId,
    required StripTemplate template,
    required Uint8List bytes,
  }) async {
    final composed =
        await StripCompositor.render(template: template, first: bytes);
    await _flowers.sendDayPhoto(
      pairId: pairId,
      senderId: senderId,
      bytes: composed,
      fileExtension: 'jpg',
      note: template.name,
    );
  }

  /// Duo template, first half. Leaves the strip open for the partner.
  Future<PhotoStrip> startDuo({
    required String pairId,
    required String senderId,
    required StripTemplate template,
    required Uint8List bytes,
  }) async {
    final path = await _uploadHalf(pairId, bytes);
    final row = await _client
        .from('photo_strips')
        .insert({
          'pair_id': pairId,
          'template': template.id,
          'is_duo': true,
          'a_user': senderId,
          'a_path': path,
        })
        .select()
        .single();
    return PhotoStrip.fromMap(row);
  }

  /// Duo template, second half — then composite and post.
  ///
  /// Slot B is written *before* the composite so the work is never lost: if
  /// rendering or the upload dies here the strip is left [isFullButUnposted]
  /// and [finish] can pick it up, rather than the joiner's photo vanishing.
  Future<void> joinDuo({
    required PhotoStrip strip,
    required String senderId,
    required Uint8List bytes,
  }) async {
    final path = await _uploadHalf(strip.pairId, bytes);
    await _client
        .from('photo_strips')
        .update({'b_user': senderId, 'b_path': path})
        .eq('id', strip.id);

    await finish(
      strip: PhotoStrip(
        id: strip.id,
        pairId: strip.pairId,
        template: strip.template,
        aUser: strip.aUser,
        aPath: strip.aPath,
        bUser: senderId,
        bPath: path,
        createdAt: strip.createdAt,
      ),
      senderId: senderId,
    );
  }

  /// Renders a full strip and posts it as an ordinary day photo.
  ///
  /// Deliberately reuses [FlowerRepository.sendDayPhoto]: the composite is
  /// just a JPEG, so the thread, the widget slot and the 24h expiry all work
  /// with no second code path.
  Future<void> finish({
    required PhotoStrip strip,
    required String senderId,
  }) async {
    if (strip.bPath == null) return;

    final a = await _flowers.downloadPhoto(strip.aPath);
    final b = await _flowers.downloadPhoto(strip.bPath!);
    final composed = await StripCompositor.render(
      template: strip.style,
      first: a,
      second: b,
    );

    final message = await _flowers.sendDayPhoto(
      pairId: strip.pairId,
      senderId: senderId,
      bytes: composed,
      fileExtension: 'jpg',
      note: strip.style.name,
    );

    await _client.from('photo_strips').update({
      'completed_at': DateTime.now().toUtc().toIso8601String(),
      'message_id': message.id,
    }).eq('id', strip.id);
  }

  /// Abandon a half you started.
  Future<void> cancel(String stripId) async {
    await _client.from('photo_strips').delete().eq('id', stripId);
  }

  /// Halves share the day-photo bucket and the `<pair_id>/` prefix, so
  /// 0013's Storage policies already cover them.
  Future<String> _uploadHalf(String pairId, Uint8List bytes) async {
    final path = '$pairId/strip-${_uuid()}.jpg';
    await _client.storage.from(dayPhotoBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return path;
  }

  static String _uuid() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
}

final stripRepositoryProvider = Provider<StripRepository>((ref) {
  return StripRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(flowerRepositoryProvider),
  );
});

/// Open (incomplete) strips for the pair.
final openStripsProvider =
    StreamProvider.autoDispose<List<PhotoStrip>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(stripRepositoryProvider).watchOpen(pair.id);
});

/// A half **I** started, still waiting on my partner.
final myOpenStripProvider = Provider.autoDispose<PhotoStrip?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final strips = ref.watch(openStripsProvider).valueOrNull ?? const [];
  for (final s in strips) {
    if (s.aUser == userId && s.bPath == null) return s;
  }
  return null;
});

/// A half **they** started, waiting on me. This is the invite.
final stripAwaitingMeProvider = Provider.autoDispose<PhotoStrip?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final strips = ref.watch(openStripsProvider).valueOrNull ?? const [];
  for (final s in strips) {
    if (s.aUser != userId && s.bPath == null) return s;
  }
  return null;
});

import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/avatar_flower.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../pairing/data/pair_repository.dart';

class UserRepository {
  UserRepository(this._client);
  final SupabaseClient _client;

  Future<UserProfile?> getProfile(String userId) async {
    final row =
        await _client.from('users').select().eq('id', userId).maybeSingle();
    if (row == null) return null;
    return UserProfile.fromMap(row);
  }

  /// Sets — or clears — how you are feeling.
  ///
  /// The timestamp goes with it every time, because a mood without one
  /// cannot be told apart from a mood set last week. Cleared together too:
  /// leaving a stale `mood_at` behind would make the next read think an
  /// absent mood was a fresh one.
  Future<void> setMood(String userId, String? moodName) async {
    await _client.from('users').update({
      'mood': moodName,
      'mood_at': moodName == null
          ? null
          : DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  Future<void> updateTimezone(String userId, String timezone) async {
    await _client
        .from('users')
        .update({'timezone': timezone}).eq('id', userId);
  }

  /// Updates the fields the user can edit from Settings. Passing null
  /// leaves a field untouched; pet name clears when given an empty string.
  Future<void> updateProfile(
    String userId, {
    String? displayName,
    String? petName,
    AvatarFlower? avatar,
    String? gender,
  }) async {
    final patch = <String, dynamic>{
      if (displayName != null && displayName.trim().isNotEmpty)
        'display_name': displayName.trim(),
      if (petName != null) 'pet_name': petName.trim().isEmpty ? null : petName.trim(),
      // Writing the id, not the enum: the column is text and an unknown id
      // from a newer build must degrade to the default, not crash a decode.
      if (avatar != null) 'avatar': avatar.id,
      if (gender != null) 'gender': gender.trim().isEmpty ? null : gender.trim(),
    };
    if (patch.isEmpty) return;
    await _client.from('users').update(patch).eq('id', userId);
  }

  /// Private Storage bucket created by migration 0020.
  static const avatarBucket = 'avatars';

  /// Uploads a processed avatar and points the profile row at it.
  ///
  /// [bytes] must already have been through `squareAvatarJpeg` — this does
  /// no processing of its own, so that the expensive part can run in an
  /// isolate and the caller can show a failure before anything is written.
  ///
  /// Returns the new object path.
  Future<String> setAvatarPhoto({
    required String userId,
    required Uint8List bytes,
  }) async {
    // <user_id>/<uuid>.jpg — the leading segment is what the Storage RLS
    // policy reads to decide who owns this, so it must stay first.
    final path = '$userId/${const Uuid().v4()}.jpg';

    await _client.storage.from(avatarBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );

    // The old object is read off the row *before* the row is repointed, so
    // a failure here leaves the old photo intact and referenced rather than
    // deleted and missing.
    final previous = (await _client
        .from('users')
        .select('avatar_path')
        .eq('id', userId)
        .maybeSingle())?['avatar_path'] as String?;

    await _client.from('users').update({'avatar_path': path}).eq('id', userId);

    // Best effort, and deliberately after the row is updated: an orphaned
    // object costs a few kilobytes, whereas deleting first and then failing
    // the update would leave the profile pointing at nothing.
    if (previous != null && previous != path) {
      await _deleteAvatarObject(previous);
    }
    return path;
  }

  /// Drops back to the flower.
  ///
  /// Clears the pointer first for the same reason as above — the row must
  /// never reference an object that is already gone.
  Future<void> removeAvatarPhoto(String userId) async {
    final previous = (await _client
        .from('users')
        .select('avatar_path')
        .eq('id', userId)
        .maybeSingle())?['avatar_path'] as String?;

    await _client.from('users').update({'avatar_path': null}).eq('id', userId);
    if (previous != null) await _deleteAvatarObject(previous);
  }

  Future<void> _deleteAvatarObject(String path) async {
    try {
      await _client.storage.from(avatarBucket).remove([path]);
    } catch (_) {
      // An avatar nobody references any more is litter, not a failure the
      // user can do anything about. Swallowed so replacing a photo still
      // reports success.
    }
  }

  /// The avatar's bytes.
  ///
  /// For the home-screen widget, which needs a real file on disk rather
  /// than a URL — RemoteViews cannot fetch anything itself.
  Future<Uint8List> downloadAvatar(String path) =>
      _client.storage.from(avatarBucket).download(path);

  /// A URL the image loader can actually fetch.
  ///
  /// Long-lived on purpose. The bucket is private, so every render needs a
  /// signature — but a signed URL is unique per signing, which means a
  /// short TTL would defeat `cached_network_image`'s URL-keyed cache and
  /// re-download the same face on every rebuild. One signature per week,
  /// cached by [avatarUrlProvider], is the trade.
  Future<String> signedAvatarUrl(String path,
          {Duration ttl = const Duration(days: 7)}) =>
      _client.storage.from(avatarBucket).createSignedUrl(path, ttl.inSeconds);

  Future<UserProfile> createProfile({
    required String userId,
    required String displayName,
    String? petName,
    String timezone = 'UTC',
    String? gender,
  }) async {
    final profile = UserProfile(
      id: userId,
      displayName: displayName,
      petName: petName,
      timezone: timezone,
      gender: gender,
      // Left null on purpose. A null avatar means "never chosen", which is
      // what lets the gender default apply — and lets it change later if the
      // gender does. Writing the default here would freeze it forever.
    );
    // Upsert so a retry after a half-failed submit doesn't hit a
    // duplicate-key error on the existing row.
    await _client.from('users').upsert(profile.toInsertMap());
    return profile;
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's profile row, or null if onboarding hasn't been
/// completed yet. Re-run with `ref.invalidate(userProfileProvider)` after
/// creating the profile.
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(userRepositoryProvider).getProfile(userId);
});

/// The partner's profile, live.
///
/// A stream rather than a one-shot read, and that is what migration 0024
/// added `users` to the realtime publication for: a mood is only worth
/// sharing if it appears on the other phone while they are looking at it.
/// Everything else on a profile changes rarely enough that the old
/// re-read-on-navigation was fine.
final partnerProfileStreamProvider =
    StreamProvider.autoDispose<UserProfile?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (userId == null || pair == null) return Stream.value(null);
  final partnerId = pair.partnerIdFor(userId);
  if (partnerId == null) return Stream.value(null);
  return ref
      .watch(supabaseClientProvider)
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', partnerId)
      .map((rows) => rows.isEmpty ? null : UserProfile.fromMap(rows.first));
});

/// The partner's profile, or null until paired. RLS allows reading the
/// partner's row once the pair is linked.
final partnerProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (userId == null || pair == null) return null;
  final partnerId = pair.partnerIdFor(userId);
  if (partnerId == null) return null;
  return ref.watch(userRepositoryProvider).getProfile(partnerId);
});

/// A signed URL for one avatar object, cached for the session.
///
/// Family-keyed on the storage path and deliberately **not** autoDispose:
/// there are exactly two of these in the whole app, and re-signing every
/// time the last widget showing a face leaves the tree would mean a
/// round-trip on every screen change. See `signedAvatarUrl` for why the
/// signature has to be stable rather than fresh.
///
/// Invalidate it after changing a photo — the path changes, so a new key is
/// created anyway, but the old entry should not linger pointing at an
/// object that has just been deleted.
final avatarUrlProvider =
    FutureProvider.family<String?, String>((ref, path) async {
  if (path.isEmpty) return null;
  try {
    return await ref.watch(userRepositoryProvider).signedAvatarUrl(path);
  } catch (_) {
    // Signing can fail on a dead connection or a deleted object. Null means
    // "draw the flower", which is the correct answer to both.
    return null;
  }
});

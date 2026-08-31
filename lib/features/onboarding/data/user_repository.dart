import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

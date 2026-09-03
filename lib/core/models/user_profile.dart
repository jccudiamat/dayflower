import 'avatar_flower.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.petName,
    this.timezone = 'UTC',
    this.avatar,
    this.avatarPath,
    this.gender,
  });

  final String id;
  final String displayName;
  final String? petName;
  final String timezone;

  /// [AvatarFlower.id], or null when never chosen. Null is meaningful: it is
  /// what lets [flower] fall back to the gender default instead of a pick.
  final String? avatar;

  /// Storage object path in the private `avatars` bucket, or null when no
  /// photo has been uploaded. Not a URL — the bucket is private, so a
  /// signed one is minted at render time (see `avatarUrlProvider`).
  final String? avatarPath;

  /// Only ever used to choose the default avatar. Never rendered.
  final String? gender;

  /// Whether this person has a photo rather than a flower.
  ///
  /// The flower stays underneath either way: it is what renders while the
  /// signed URL is in flight, and what renders if the image fails. See the
  /// header of migration 0020.
  bool get hasPhoto => avatarPath != null && avatarPath!.isNotEmpty;

  /// The flower to draw for this person, everywhere.
  AvatarFlower get flower =>
      AvatarFlower.forUser(avatar: avatar, gender: gender);

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        displayName: map['display_name'] as String,
        petName: map['pet_name'] as String?,
        timezone: map['timezone'] as String? ?? 'UTC',
        // Both absent on rows written before migration 0017.
        avatar: map['avatar'] as String?,
        // Absent on rows written before migration 0020.
        avatarPath: map['avatar_path'] as String?,
        gender: map['gender'] as String?,
      );

  Map<String, dynamic> toInsertMap() => {
        'id': id,
        'display_name': displayName,
        if (petName != null) 'pet_name': petName,
        'timezone': timezone,
        if (avatar != null) 'avatar': avatar,
        if (avatarPath != null) 'avatar_path': avatarPath,
        if (gender != null) 'gender': gender,
      };
}

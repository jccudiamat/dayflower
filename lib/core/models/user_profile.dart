import 'avatar_flower.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.petName,
    this.timezone = 'UTC',
    this.avatar,
    this.gender,
  });

  final String id;
  final String displayName;
  final String? petName;
  final String timezone;

  /// [AvatarFlower.id], or null when never chosen. Null is meaningful: it is
  /// what lets [flower] fall back to the gender default instead of a pick.
  final String? avatar;

  /// Only ever used to choose the default avatar. Never rendered.
  final String? gender;

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
        gender: map['gender'] as String?,
      );

  Map<String, dynamic> toInsertMap() => {
        'id': id,
        'display_name': displayName,
        if (petName != null) 'pet_name': petName,
        'timezone': timezone,
        if (avatar != null) 'avatar': avatar,
        if (gender != null) 'gender': gender,
      };
}

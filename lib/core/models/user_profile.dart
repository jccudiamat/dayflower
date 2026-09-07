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
    this.mood,
    this.moodAt,
    this.city,
    this.cityLat,
    this.cityLon,
    this.birthday,
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

  /// Where they are, as a label: "Tuguegarao City, Cagayan Valley,
  /// Philippines". Null until a city has been picked.
  ///
  /// ⚠️ Separate from [timezone] on purpose. The zone is the clock; the city
  /// is the distance. Everyone in Asia/Manila used to be measured from
  /// Manila itself, which put someone in Tuguegarao ~300 miles from where
  /// they actually are — see migration 0034.
  final String? city;

  final double? cityLat;
  final double? cityLon;

  /// Optional, and asked for that way. A date, never an instant: a birthday
  /// is the same calendar day everywhere, and an instant would shift it
  /// across midnight for exactly the couples this app is for.
  final DateTime? birthday;

  /// Whether this profile can give a real distance rather than an estimate
  /// from its timezone.
  bool get hasPlace => cityLat != null && cityLon != null;

  /// Only ever used to choose the default avatar. Never rendered.
  final String? gender;

  /// The `Mood` enum's name, or null when nothing is set. Free text on the
  /// column and parsed leniently here, so a mood a newer build knows about
  /// reads as "none" rather than crashing this decode.
  final String? mood;

  /// When it was set. ⚠️ Without this a mood chosen on Tuesday is still
  /// being reported as how somebody feels on Friday — see [freshMood].
  final DateTime? moodAt;

  /// How long a mood is worth showing to the other person.
  ///
  /// A day. Long enough that setting one in the morning still means
  /// something that evening, short enough that it never becomes furniture
  /// nobody has looked at in a week.
  static const moodLifetime = Duration(hours: 24);

  /// The mood, if it is recent enough to still be true.
  ///
  /// Null once it has gone stale, which the UI shows as nothing at all
  /// rather than as an old feeling presented as a current one.
  String? get freshMood {
    final name = mood;
    final at = moodAt;
    if (name == null || name.isEmpty) return null;
    if (at == null) return null;
    return DateTime.now().difference(at) < moodLifetime ? name : null;
  }

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
        // Both absent on rows read before migration 0024.
        mood: map['mood'] as String?,
        moodAt: map['mood_at'] == null
            ? null
            : DateTime.parse(map['mood_at'] as String).toLocal(),
        // All four absent on rows read before migration 0034.
        city: map['city'] as String?,
        cityLat: (map['city_lat'] as num?)?.toDouble(),
        cityLon: (map['city_lon'] as num?)?.toDouble(),
        // ⚠️ Parsed, not localised. `date` arrives as "1998-04-12" and
        // toLocal() on it would land on the 11th west of UTC.
        birthday: map['birthday'] == null
            ? null
            : DateTime.tryParse(map['birthday'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'id': id,
        'display_name': displayName,
        if (petName != null) 'pet_name': petName,
        'timezone': timezone,
        if (avatar != null) 'avatar': avatar,
        if (avatarPath != null) 'avatar_path': avatarPath,
        if (gender != null) 'gender': gender,
        if (city != null) 'city': city,
        if (cityLat != null) 'city_lat': cityLat,
        if (cityLon != null) 'city_lon': cityLon,
        if (birthday != null) 'birthday': isoDate(birthday!),
      };
}

/// A calendar date as Postgres `date` wants it, with no time and no zone.
String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class Pair {
  const Pair({
    required this.id,
    required this.userA,
    this.userB,
    required this.inviteCode,
    this.togetherSince,
  });

  final String id;
  final String userA;
  final String? userB;
  final String inviteCode;

  /// The day the two of you started, or null when nobody has said yet.
  ///
  /// A [DateTime] at midnight standing in for a calendar date — the column
  /// is a `date`, deliberately. "We got together on 10 April 2022" has no
  /// time of day, and giving it one would land the anniversary on a
  /// different day for each of you the moment you are in different
  /// timezones, which in this app is the normal case.
  ///
  /// Null is meaningful: everything derived from it — days together, the
  /// monthsary, the anniversary — stays hidden rather than guessed.
  final DateTime? togetherSince;

  bool get isLinked => userB != null;

  /// The other partner's user id, from [selfId]'s point of view.
  /// Null if not linked yet.
  String? partnerIdFor(String selfId) {
    if (userB == null) return null;
    return userA == selfId ? userB : userA;
  }

  factory Pair.fromMap(Map<String, dynamic> map) => Pair(
        id: map['id'] as String,
        userA: map['user_a'] as String,
        userB: map['user_b'] as String?,
        inviteCode: map['invite_code'] as String,
        // Absent on rows read before migration 0021.
        togetherSince: map['together_since'] == null
            ? null
            : DateTime.parse(map['together_since'] as String),
      );
}

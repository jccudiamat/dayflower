class Pair {
  const Pair({
    required this.id,
    required this.userA,
    this.userB,
    required this.inviteCode,
  });

  final String id;
  final String userA;
  final String? userB;
  final String inviteCode;

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
      );
}

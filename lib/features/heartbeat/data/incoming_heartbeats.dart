import 'heartbeat_repository.dart';

/// Distinguishes new partner taps from the initial snapshot and reconnects.
class IncomingHeartbeats {
  String? _scope;
  Set<String>? _seen;

  void reset() {
    _scope = null;
    _seen = null;
  }

  /// How many new taps by the partner, and when the newest of them
  /// happened.
  ///
  /// ⚠️ The timestamp is not decoration: PulseAlerts compares it against the
  /// newest tap it has already announced, which is what stops the same heart
  /// being counted once over realtime and again when its push lands. Null
  /// when the count is zero.
  ({int count, DateTime? newestAt}) take({
    required String pairId,
    required String userId,
    required String partnerId,
    required List<Heartbeat> beats,
    required DateTime now,
  }) {
    final scope = '$pairId/$userId';
    final ids = beats.map((beat) => beat.id).toSet();
    if (_scope != scope || _seen == null) {
      _scope = scope;
      _seen = ids;
      return (count: 0, newestAt: null);
    }
    final incoming = beats.where((beat) {
      final age = now.difference(beat.sentAt);
      return !_seen!.contains(beat.id) &&
          beat.senderId == partnerId &&
          !age.isNegative &&
          age <= const Duration(minutes: 2);
    }).toList(growable: false);
    // Keep IDs across temporary empty snapshots and short reconnects.
    _seen!.addAll(ids);
    if (_seen!.length > 2000) _seen = ids;

    DateTime? newest;
    for (final beat in incoming) {
      if (newest == null || beat.sentAt.isAfter(newest)) newest = beat.sentAt;
    }
    return (count: incoming.length, newestAt: newest);
  }
}

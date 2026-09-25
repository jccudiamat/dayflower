import 'package:flutter/foundation.dart';

/// What arrived, and how loudly it should land.
///
/// The edge function sends **data-only** FCM messages — no `notification`
/// block — precisely so this decision happens here rather than in the system
/// tray. A `notification` payload is drawn by Android and never reaches the
/// app while it is backgrounded, which would make a full-screen ring
/// impossible.
///
/// Parsed rather than trusted: the payload crosses the network as a map of
/// strings, and a build newer than this one may send kinds it has never
/// heard of.
enum PushKind {
  /// The one thing allowed to take over the screen. A call expires if it is
  /// not seen while it is happening.
  call,

  photo,
  flower,
  message,

  /// A love tap. Drawn by PulseAlerts rather than as an ordinary banner —
  /// it has its own sound, its own vibration waveform, and a count that
  /// accumulates across a burst. See migration 0046 for why it pushes at
  /// all, having deliberately not done so since 0031.
  heartbeat,

  /// They picked a mood, or changed it (migration 0049). Quiet, on the
  /// activity channel: worth knowing, not worth a heads-up.
  mood;

  static PushKind? byId(String? id) {
    for (final kind in PushKind.values) {
      if (kind.name == id) return kind;
    }
    // An unknown kind from a newer build renders as a quiet message rather
    // than being dropped — the same rule `CallMode.byId` follows. Something
    // arrived; saying so is better than silence.
    return id == null ? null : PushKind.message;
  }

  /// Whether this should ring rather than sit in the tray.
  bool get interrupts => this == PushKind.call;
}

@immutable
class PushMessage {
  const PushMessage({
    required this.kind,
    required this.title,
    required this.body,
    this.messageId,
    this.pairId,
    this.callMode,
    this.sentAt,
  });

  final PushKind kind;
  final String title;
  final String body;

  /// The `flower_messages` row. For a call this is what the ring screen
  /// answers, so it is the one field a call cannot arrive without.
  final String? messageId;

  final String? pairId;

  /// `'voice'` or `'video'`, empty or null for anything else.
  final String? callMode;

  /// When the tap happened, for a heartbeat. Null for everything else.
  ///
  /// ⚠️ The app receives a tap twice when it is backgrounded but alive —
  /// once over realtime, once as this push. PulseAlerts compares this
  /// against the newest tap it has already announced, so one heart is never
  /// counted as two. Without it the push path could only ever say "one".
  final DateTime? sentAt;

  bool get isVideoCall => callMode == 'video';

  /// A call with no row to answer is not something to ring about — tapping
  /// it could only open a call screen with nothing behind it.
  bool get isActionableCall =>
      kind == PushKind.call && (messageId?.isNotEmpty ?? false);

  /// Builds one from FCM's `data` map, which is always `Map<String, String>`
  /// on the wire regardless of what was sent.
  static PushMessage? parse(Map<String, dynamic> data) {
    final kind = PushKind.byId(data['kind'] as String?);
    if (kind == null) return null;

    final title = (data['title'] as String?)?.trim();
    final body = (data['body'] as String?)?.trim();

    return PushMessage(
      kind: kind,
      // Falling back rather than refusing: a notification with a blank title
      // is still worth showing, and dropping it would lose the event
      // entirely over a formatting problem.
      title: (title?.isNotEmpty ?? false) ? title! : 'Dayflower',
      body: (body?.isNotEmpty ?? false) ? body! : 'Something arrived',
      messageId: data['messageId'] as String?,
      pairId: data['pairId'] as String?,
      callMode: data['callMode'] as String?,
      // Millis as a string, because FCM data values are always strings.
      // Unparseable or absent is null, and the heartbeat path treats that
      // as "now" rather than dropping a tap over a formatting problem.
      sentAt: _millis(data['sentAtMs']),
    );
  }

  static DateTime? _millis(Object? value) {
    final ms = int.tryParse('${value ?? ''}');
    return ms == null || ms <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}

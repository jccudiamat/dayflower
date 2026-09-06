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
  message;

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
    );
  }
}

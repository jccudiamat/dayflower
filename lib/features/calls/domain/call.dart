import 'package:flutter/cupertino.dart';

/// Voice or video — the only thing that differs between the two calls this
/// app makes.
///
/// Deliberately not two features. The session, the room, the token and the
/// transport are identical; video is this flag plus a camera track. Building
/// them separately would mean two of everything to keep in step, and the
/// second one would drift.
enum CallMode {
  /// ~40 kbps of Opus. Survives a throttled or lossy path long after video
  /// stops, which is why it is the safer default on an unknown network.
  voice('Voice call', CupertinoIcons.phone_fill),

  /// Several hundred kbps upward. The first thing to fail when a carrier is
  /// degrading rather than blocking outright.
  video('Video call', CupertinoIcons.video_camera_solid);

  const CallMode(this.label, this.icon);

  final String label;
  final IconData icon;

  /// The stored value. Matches the `call_mode` CHECK in migration 0025.
  String get id => name;

  /// Null for anything that is not a call, and for a `call_mode` written by
  /// a newer build than this one. An unknown mode reads as "not a call I
  /// understand" and renders as an ordinary message rather than crashing the
  /// decode — the same rule `mood` and `avatar` follow.
  static CallMode? byId(String? id) {
    for (final mode in CallMode.values) {
      if (mode.id == id) return mode;
    }
    return null;
  }
}

/// Where a call is in its life.
///
/// One enum for both sides of the call. Which of these you can reach depends
/// on who you are — only the receiver sees [ringing], only the caller passes
/// through [dialling] — but the screen is the same widget either way, and a
/// single status is what keeps it that way.
enum CallStatus {
  /// Placing the call: the row is being written and the transport is being
  /// asked for a room. What the caller sees first.
  dialling,

  /// A live call this phone has not answered yet. What the receiver sees.
  ringing,

  /// Answered, negotiating media. Both sides pass through this.
  connecting,

  /// Media is flowing.
  live,

  /// Over, by either side. Terminal.
  ended,

  /// Never connected, or dropped and could not recover. Terminal, and the
  /// only status that carries a [CallFailure].
  failed;

  bool get isTerminal => this == ended || this == failed;

  /// Whether the call controls (mute, camera, end) should be on screen.
  bool get isActive => this == connecting || this == live || this == dialling;
}

/// Why a call did not happen, in the terms the person holding the phone
/// would use — not the transport's.
///
/// The distinction that matters here is [unreachable] versus everything
/// else. On a restricted network the media path fails while the thread keeps
/// working perfectly, and an app that says "check your connection" in that
/// moment is telling the user something false about a connection that is
/// visibly fine.
enum CallFailure {
  /// No provider configured in this build. Development state, not a user
  /// state — but it has to render as something, and pretending to dial and
  /// then timing out would be worse.
  notConfigured(
    'Calling isn’t switched on yet',
    'This build has no calling service configured. Your message still sent.',
  ),

  /// The signalling or media path never came up. The likely one on a
  /// restricted carrier: the app is online, the call is not.
  unreachable(
    'Couldn’t reach them',
    'Video and voice calls don’t work on every network. Your message still '
        'sent — they’ll see it.',
  ),

  /// The microphone (or camera) was refused at the OS level.
  noPermission(
    'Dayflower needs your microphone',
    'Allow microphone access to make a call.',
  ),

  /// Connected, then lost, and could not re-establish.
  dropped(
    'The call dropped',
    'The connection gave out. Try again, or just send a message.',
  ),

  /// The month's calling is spent.
  ///
  /// The detail line is filled in at render time with the reset date —
  /// see [CallUsage.resetsOn]. A limit with no stated end reads as the
  /// feature having been taken away rather than paused, which is why this
  /// is the one failure whose text is not complete here.
  quotaExhausted(
    'You have talked a lot this month',
    'Calling comes back on the 1st. Messages, flowers and heartbeats are '
        'all still yours.',
  );

  const CallFailure(this.title, this.detail);

  /// Headline on the failure screen — what happened, in their words.
  final String title;

  /// The line under it: why, and what still works. Never an apology, and
  /// never a guess at whose fault it was.
  final String detail;
}

/// A flower thrown across the call.
///
/// The one control on the call screen that no video SDK ships, and the
/// reason this is Dayflower's call and not a generic one: mid-sentence, you
/// hand them a tulip and it lands on their screen.
@immutable
class CallReaction {
  const CallReaction({
    required this.id,
    required this.emoji,
    required this.mine,
    required this.at,
  });

  /// Distinguishes two identical tulips sent a second apart, so the overlay
  /// animates the new one instead of treating it as the old one still in
  /// flight.
  final String id;

  final String emoji;

  /// Yours or theirs. Only changes where it starts from on screen.
  final bool mine;

  final DateTime at;

  /// How long one stays on screen. Long enough to read as a gesture, short
  /// enough that a flurry of them never covers the other person's face.
  static const lifetime = Duration(seconds: 4);

  bool get isExpired => DateTime.now().difference(at) > lifetime;
}

/// A call, as this phone currently understands it.
@immutable
class CallSession {
  const CallSession({
    required this.messageId,
    required this.room,
    required this.mode,
    required this.status,
    required this.isCaller,
    this.startedAt,
    this.failure,
    this.micEnabled = true,
    this.cameraEnabled = true,
    this.partnerSpeaking = false,
    this.reactions = const [],
  });

  /// The `flower_messages` row this call is. The bubble in the thread and
  /// the screen on top of it are the same object, which is what lets a call
  /// be joined from the thread minutes later.
  final String messageId;

  final String room;
  final CallMode mode;
  final CallStatus status;

  /// Who placed it. Decides [dialling] versus [ringing], and nothing else.
  final bool isCaller;

  /// When media actually started — not when the row was written. The timer
  /// counts from here, so the seconds spent connecting are not billed to the
  /// conversation.
  final DateTime? startedAt;

  /// Set only when [status] is [CallStatus.failed].
  final CallFailure? failure;

  final bool micEnabled;

  /// Meaningless on a voice call, where it is forced false and stays there.
  final bool cameraEnabled;

  /// Drives the ripple on the voice screen. False on video, where you can
  /// see them and a breathing ring would be noise.
  final bool partnerSpeaking;

  /// Flowers currently in flight, both directions. Expired ones are dropped
  /// by the notifier rather than filtered here, so the list the overlay sees
  /// is stable between ticks.
  final List<CallReaction> reactions;

  bool get isVideo => mode == CallMode.video;

  /// How long the call has been up. Null until media starts, so the screen
  /// shows "Connecting…" rather than a timer sitting at 00:00.
  Duration? get elapsed =>
      startedAt == null ? null : DateTime.now().difference(startedAt!);

  CallSession copyWith({
    CallStatus? status,
    DateTime? startedAt,
    CallFailure? failure,
    bool? micEnabled,
    bool? cameraEnabled,
    bool? partnerSpeaking,
    List<CallReaction>? reactions,
  }) {
    return CallSession(
      messageId: messageId,
      room: room,
      mode: mode,
      status: status ?? this.status,
      isCaller: isCaller,
      startedAt: startedAt ?? this.startedAt,
      // Cleared on any status change that isn't a failure: a retry that
      // reaches `connecting` must not keep rendering the last error.
      failure: status != null && status != CallStatus.failed
          ? null
          : (failure ?? this.failure),
      micEnabled: micEnabled ?? this.micEnabled,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      partnerSpeaking: partnerSpeaking ?? this.partnerSpeaking,
      reactions: reactions ?? this.reactions,
    );
  }
}

/// `04:12`, and `1:04:12` once a call runs past the hour.
///
/// Lives here rather than in the screen so the thread's ended-call line and
/// the in-call timer cannot disagree about what a duration looks like.
String formatCallDuration(Duration d) {
  final seconds = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
  return [
    if (h > 0) h.toString(),
    mm,
    s.toString().padLeft(2, '0'),
  ].join(':');
}

/// The same duration in words, for the line a finished call leaves behind.
///
/// `4 min 12 sec` rather than `04:12`: the bubble is read once, in passing,
/// months later — the clock format is for something you are watching tick.
String describeCallDuration(Duration d) {
  final seconds = d.inSeconds < 0 ? 0 : d.inSeconds;
  if (seconds < 60) return '$seconds sec';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m < 60) return s == 0 ? '$m min' : '$m min $s sec';
  final h = m ~/ 60;
  final rm = m % 60;
  return rm == 0 ? '$h hr' : '$h hr $rm min';
}

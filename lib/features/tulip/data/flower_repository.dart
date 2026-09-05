import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../calls/domain/call.dart';
import '../../pairing/data/pair_repository.dart';
import '../domain/flower_catalog.dart';

/// One message in the couple's conversation.
///
/// The table started life as one-flower-a-day and now backs a chat, so a row
/// is one of:
///  - a **flower** ([flowerType] set), optionally captioned by [note],
///  - a **day photo** ([imagePath] set), optionally captioned by [note],
///  - a **call** ([callMode] set — see migration 0025), or
///  - a **text message** (none of the three set; [note] carries the text).
///
/// Migration 0025 enforces that at least one of the four is present.
class FlowerMessage {
  const FlowerMessage({
    required this.id,
    required this.pairId,
    required this.senderId,
    this.flowerType,
    this.imagePath,
    this.note,
    required this.sentAt,
    this.seenAt,
    this.toWidget = false,
    this.toChat = true,
    this.replyTo,
    this.callMode,
    this.callRoom,
    this.callEndedAt,
  });

  final String id;
  final String pairId;
  final String senderId;

  /// Null for a plain text message.
  final String? flowerType;

  /// Storage object path in the private `day_photos` bucket, keyed
  /// `<pairId>/<uuid>.jpg`. Not a URL — the bucket is private, so the app
  /// mints a short-lived signed URL when it actually needs to render this.
  final String? imagePath;

  /// The flower's caption, or — when [flowerType] is null — the message text.
  final String? note;

  final DateTime sentAt;
  final DateTime? seenAt;

  /// The sender chose to push this flower to the recipient's home-screen
  /// widget. Always false for text — the widget only renders flowers.
  final bool toWidget;

  /// The message this answers, when it is a reply from the story viewer or
  /// the home-screen widget. Null for everything else, which is most of it.
  ///
  /// `set null` on the far side, so deleting a photo leaves the reply to it
  /// intact — see migration 0023.
  final String? replyTo;

  /// Whether this belongs in the conversation. False only for a day photo
  /// sent straight to the home screen — flowers and text are always chat.
  final bool toChat;

  /// `'voice'` or `'video'` when this row is a call, null for everything
  /// else. Decoded through [CallMode.byId], which returns null for a value
  /// this build doesn't know — so a call placed by a newer app renders as an
  /// ordinary message here instead of crashing the thread.
  final String? callMode;

  /// The room both phones join. Stored rather than recomputed so a call
  /// started under an older naming scheme stays joinable from its own row.
  final String? callRoom;

  /// Null while the call is live. [sentAt] is when it started.
  final DateTime? callEndedAt;

  bool get isSeen => seenAt != null;

  /// A "Share your day" photo.
  bool get isPhoto => imagePath != null;

  /// A text-only message — no flower, no photo, no call.
  ///
  /// ⚠️ The call clause is load-bearing: a call row carries none of the
  /// other three, so without it every call would report as text and render
  /// as an empty bubble.
  bool get isText => flowerType == null && imagePath == null && !isCall;

  /// A call — live or long finished.
  bool get isCall => call != null;

  /// Typed [callMode]. Null for every row that is not a call.
  CallMode? get call => CallMode.byId(callMode);

  /// A call nobody has hung up.
  ///
  /// Time-boxed as well as flag-checked. A call whose row was never closed —
  /// both apps killed mid-call, a hang-up that never reached the server —
  /// would otherwise advertise itself as live in the thread forever, and the
  /// header would keep offering to join a room with nobody in it.
  static const staleCallAfter = Duration(hours: 2);

  bool get isLiveCall =>
      isCall &&
      callEndedAt == null &&
      DateTime.now().difference(sentAt) < staleCallAfter;

  /// How long the call lasted, or has been running. Null if not a call.
  Duration? get callDuration => !isCall
      ? null
      : (callEndedAt ?? DateTime.now()).difference(sentAt);

  /// How long this has left on the recipient's home screen.
  ///
  /// The bloom lasts a day: a photo leaves the widget 24h after it was sent,
  /// but the row is never touched, so it stays in the conversation forever.
  /// Computed rather than stored — see the note in migration 0013.
  static const widgetLifetime = Duration(hours: 24);

  bool get isFreshForWidget =>
      DateTime.now().difference(sentAt) < widgetLifetime;

  /// Null once it has expired. Drives the ring countdown on the story bar.
  Duration? get widgetTimeLeft {
    final left = widgetLifetime - DateTime.now().difference(sentAt);
    return left.isNegative ? null : left;
  }

  /// How this message reads on a lock screen.
  ///
  /// Lives on the model rather than in the notification service so it can
  /// be tested without a phone attached — and because "what is this
  /// message, in one line" is a question the thread and the widget could
  /// both want answered later.
  String get alertLine {
    final note = this.note?.trim() ?? '';

    // The caption leads for a photo: "📷 at the beach" says more than
    // "shared their day" ever does, and the emoji keeps it obvious that
    // there is a picture behind it.
    if (isPhoto) return note.isEmpty ? 'Shared their day 📷' : '📷  $note';

    // A live call is the one message in this app that is worth interrupting
    // someone for, so it says what it wants rather than what it is.
    if (isCall) {
      final kind = call == CallMode.video ? 'Video call' : 'Voice call';
      return isLiveCall ? '$kind — tap to join' : '$kind ended';
    }

    if (isText) return note;

    // Non-null by here: the two returns above cover every case where
    // `flowerType` is null, and `FlowerCatalog.byId` falls back to the
    // classic tulip rather than returning null for an id it doesn't know.
    // So an unrecognised flower is named as a tulip, never as a crash.
    final bloom = flower!;
    final sent = 'Sent you a ${bloom.name} ${bloom.emoji}';
    return note.isEmpty ? sent : '$sent — $note';
  }

  /// The artwork this message carries, or null if it's text.
  Flower? get flower =>
      flowerType == null ? null : FlowerCatalog.byId(flowerType!);

  factory FlowerMessage.fromMap(Map<String, dynamic> map) => FlowerMessage(
        id: map['id'] as String,
        pairId: map['pair_id'] as String,
        senderId: map['sender_id'] as String,
        flowerType: map['flower_type'] as String?,
        // Rows written before 0013 ran have no column at all.
        imagePath: map['image_path'] as String?,
        note: map['note'] as String?,
        sentAt: DateTime.parse(map['sent_at'] as String).toLocal(),
        seenAt: map['seen_at'] == null
            ? null
            : DateTime.parse(map['seen_at'] as String).toLocal(),
        // Rows written before 0009 ran have no column at all.
        toWidget: map['to_widget'] as bool? ?? false,
        toChat: map['to_chat'] as bool? ?? true,
        // Absent on rows written before migration 0023.
        replyTo: map['reply_to'] as String?,
        // Absent on rows written before migration 0025.
        callMode: map['call_mode'] as String?,
        callRoom: map['call_room'] as String?,
        callEndedAt: map['call_ended_at'] == null
            ? null
            : DateTime.parse(map['call_ended_at'] as String).toLocal(),
      );
}

/// Private Storage bucket created by migration 0013.
const dayPhotoBucket = 'day_photos';

class FlowerRepository {
  FlowerRepository(this._client);
  final SupabaseClient _client;

  /// The pair's whole conversation, **newest first**, live-updating.
  ///
  /// `ascending: false` is spelled out even though it is the default:
  /// `SupabaseStreamBuilder.order()` descends unless told otherwise, so a
  /// bare `.order('sent_at')` *reads* as oldest-first and is not. That
  /// mismatch is what silently inverted the whole thread.
  Stream<List<FlowerMessage>> watchPairFlowers(String pairId) {
    return _client
        .from('flower_messages')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .order('sent_at', ascending: false)
        .map((rows) => rows.map(FlowerMessage.fromMap).toList());
  }

  /// Sends a flower, optionally captioned.
  ///
  /// [toWidget] puts it on the recipient's home-screen widget — their app
  /// reads the newest received flower carrying the flag (see
  /// [widgetFlowerProvider]), so sending another one replaces it.
  Future<FlowerMessage> sendFlower({
    required String pairId,
    required String senderId,
    required String flowerType,
    String? note,
    required bool toWidget,
    String? replyTo,
  }) {
    return _insert({
      'pair_id': pairId,
      'sender_id': senderId,
      'flower_type': flowerType,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'to_widget': toWidget,
      if (replyTo != null) 'reply_to': replyTo,
    });
  }

  /// Sends a plain text message. Empty text is rejected by the DB's
  /// `flower_messages_has_content` check, so callers must trim first.
  Future<FlowerMessage> sendText({
    required String pairId,
    required String senderId,
    required String text,
    String? replyTo,
  }) {
    return _insert({
      'pair_id': pairId,
      'sender_id': senderId,
      'note': text.trim(),
      if (replyTo != null) 'reply_to': replyTo,
    });
  }

  /// Uploads a "Share your day" photo and posts it to the thread.
  ///
  /// Two steps that must not be reordered: the object goes to Storage first,
  /// because a row pointing at a path that failed to upload would render as
  /// a permanently broken bubble that nothing can repair. If the insert
  /// fails after a successful upload the object is orphaned instead, which
  /// is invisible and cheap.
  ///
  /// [toWidget] is what puts it on the partner's home screen; it leaves
  /// there on its own 24h later (computed, never deleted).
  /// Where a day photo is allowed to show up.
  ///
  /// Three real states rather than two with a relabelled duplicate — see
  /// the header of 0018_day_photo_targets.sql.
  Future<FlowerMessage> sendDayPhotoTo({
    required String pairId,
    required String senderId,
    required Uint8List bytes,
    required String fileExtension,
    required DayPhotoTarget target,
    String? note,
  }) =>
      sendDayPhoto(
        pairId: pairId,
        senderId: senderId,
        bytes: bytes,
        fileExtension: fileExtension,
        note: note,
        toWidget: target.toWidget,
        toChat: target.toChat,
      );

  Future<FlowerMessage> sendDayPhoto({
    required String pairId,
    required String senderId,
    required Uint8List bytes,
    required String fileExtension,
    String? note,
    bool toWidget = true,
    bool toChat = true,
  }) async {
    // <pair_id>/<uuid>.<ext> — the leading segment is what the Storage RLS
    // policy reads to check pair membership, so it must stay first.
    final ext = fileExtension.replaceAll('.', '').toLowerCase();
    final path = '$pairId/${_uuid()}.$ext';

    await _client.storage.from(dayPhotoBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
            upsert: false,
          ),
        );

    return _insert({
      'pair_id': pairId,
      'sender_id': senderId,
      'image_path': path,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'to_widget': toWidget,
      'to_chat': toChat,
    });
  }

  /// A readable URL for a private object, valid for [ttl].
  ///
  /// The bucket is private, so there is no permanent URL to cache — every
  /// render needs a fresh signature.
  Future<String> signedPhotoUrl(String path,
      {Duration ttl = const Duration(hours: 1)}) {
    return _client.storage
        .from(dayPhotoBucket)
        .createSignedUrl(path, ttl.inSeconds);
  }

  /// Downloads the bytes — the widget needs a real file on disk, not a URL.
  Future<Uint8List> downloadPhoto(String path) {
    return _client.storage.from(dayPhotoBucket).download(path);
  }

  static String _uuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(1 << 32);
    return '$now-$rand';
  }

  Future<FlowerMessage> _insert(Map<String, dynamic> values) async {
    final row =
        await _client.from('flower_messages').insert(values).select().single();
    return FlowerMessage.fromMap(row);
  }

  Future<void> markSeen(String messageId) async {
    await _client
        .from('flower_messages')
        .update({'seen_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', messageId)
        .filter('seen_at', 'is', null);
  }

  /// Read receipts for the whole thread — what opening the chat means.
  ///
  /// The recipient-only RLS update policy is what keeps this honest: the
  /// `neq` is belt-and-braces, the database would reject marking your own
  /// messages seen either way.
  Future<void> markThreadSeen({
    required String pairId,
    required String userId,
  }) async {
    await _client
        .from('flower_messages')
        .update({'seen_at': DateTime.now().toUtc().toIso8601String()})
        .eq('pair_id', pairId)
        .neq('sender_id', userId)
        .filter('seen_at', 'is', null);
  }
}

final flowerRepositoryProvider = Provider<FlowerRepository>((ref) {
  return FlowerRepository(ref.watch(supabaseClientProvider));
});

/// The couple's conversation, **newest first**. Empty until paired.
///
/// Newest-first is what a `reverse: true` chat list wants — index 0 sits at
/// the bottom of the screen, and appending a message doesn't shift the
/// scroll offset of everything above it. It is also what the `for … return`
/// scans below rely on to mean "most recent".
///
/// This used to `.reversed` the repository's output. The repository was
/// already descending, so the flip handed every consumer an oldest-first
/// list: the thread rendered upside down, and the Home card and home-screen
/// widget showed the *first* flower ever received instead of the latest.
final flowerMessagesProvider =
    StreamProvider.autoDispose<List<FlowerMessage>>((ref) {
  final pair = ref.watch(currentPairProvider).valueOrNull;
  if (pair == null || !pair.isLinked) return Stream.value(const []);
  return ref.watch(flowerRepositoryProvider).watchPairFlowers(pair.id);
});

/// The most recent flower my partner sent me, whenever it arrived.
///
/// Replaced the old today-only lookup when flowers stopped being once-daily:
/// the Home card would otherwise sit empty for the rest of the week just
/// because nothing landed since midnight.
final latestReceivedFlowerProvider =
    Provider.autoDispose<FlowerMessage?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final messages = ref.watch(flowerMessagesProvider).valueOrNull ?? const [];
  for (final m in messages) {
    // `!isText` alone used to mean "a flower or a photo". Since 0025 it also
    // matches a call, which has no artwork and would render the Home card
    // empty — hence the explicit exclusion rather than a tighter `!isText`.
    if (m.senderId != userId && !m.isText && !m.isCall) return m;
  }
  return null;
});

/// What the home-screen widget shows: the newest thing my partner sent me
/// and marked for my home screen — a flower, or a "Share your day" photo.
///
/// **Newest wins.** Flowers and photos compete for the same single slot, so
/// the scan takes the first eligible message rather than preferring a kind.
/// The list is newest-first, which is what makes that correct.
///
/// A photo is only eligible for its first 24 hours ([isFreshForWidget]).
/// After that it falls out of this provider and the widget reverts to
/// whatever is next — while the message itself stays in the thread, which
/// is the whole point of the feature.
final widgetFlowerProvider = Provider.autoDispose<FlowerMessage?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final messages = ref.watch(flowerMessagesProvider).valueOrNull ?? const [];
  for (final m in messages) {
    if (m.senderId == userId || !m.toWidget) continue;
    if (m.isText) continue;
    if (m.isPhoto && !m.isFreshForWidget) continue;
    return m;
  }
  return null;
});

/// My partner's current day photo — the ring on the story bar, and what the
/// viewer opens. Null once it has aged out of its 24 hours.
final partnerDayPhotoProvider = Provider.autoDispose<FlowerMessage?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final messages = ref.watch(flowerMessagesProvider).valueOrNull ?? const [];
  for (final m in messages) {
    if (m.senderId != userId && m.isPhoto && m.isFreshForWidget) return m;
  }
  return null;
});

/// My own current day photo. Drives whether the story bar offers "Your day"
/// as an add button or as a live ring.
final myDayPhotoProvider = Provider.autoDispose<FlowerMessage?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final messages = ref.watch(flowerMessagesProvider).valueOrNull ?? const [];
  for (final m in messages) {
    if (m.senderId == userId && m.isPhoto && m.isFreshForWidget) return m;
  }
  return null;
});

/// Whether I've sent a flower today (local day). Only drives copy now that
/// the once-a-day rule is gone — nothing is blocked by it.
final sentFlowerTodayProvider = Provider.autoDispose<bool>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final messages = ref.watch(flowerMessagesProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  return messages.any((m) =>
      m.senderId == userId &&
      !m.isText &&
      m.sentAt.year == now.year &&
      m.sentAt.month == now.month &&
      m.sentAt.day == now.day);
});

/// Unread messages from my partner — the badge on the Flowers tab.
final unreadMessageCountProvider = Provider.autoDispose<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final messages = ref.watch(flowerMessagesProvider).valueOrNull ?? const [];
  return messages
      .where((m) => m.senderId != userId && !m.isSeen)
      .length;
});

/// A signed URL for one day photo, minted once and kept.
///
/// ⚠️ **Not a convenience — a correctness fix.** The home arch used to call
/// `signedPhotoUrl` straight inside `build`, which hands `FutureBuilder` a
/// brand new Future on every single rebuild: a fresh signing round-trip
/// each time, and the placeholder flashing in between. That was survivable
/// only because the arch almost never rebuilt. The moment anything animates
/// it — a swipe, a transition — it becomes one network request per frame.
///
/// Family-keyed on the storage path and deliberately **not** autoDispose,
/// for the same reason as `avatarUrlProvider`: the URL has to stay stable
/// or Flutter's image cache, which keys on it, can never hit.
///
/// The TTL is long relative to the photo itself. A day photo leaves the
/// home screen after 24 hours ([FlowerMessage.widgetLifetime]), so a
/// signature that outlives any plausible session cannot outlive the thing
/// it points at.
final dayPhotoUrlProvider =
    FutureProvider.family<String?, String>((ref, path) async {
  if (path.isEmpty) return null;
  try {
    return await ref
        .watch(flowerRepositoryProvider)
        .signedPhotoUrl(path, ttl: const Duration(hours: 12));
  } catch (_) {
    // Null means "draw the empty panel", which is the right answer to both
    // a dead connection and an object that is no longer there.
    return null;
  }
});

/// Where a day photo should land. Ordered as the camera offers them, with
/// [widget] first because parking a photo on their home screen is what
/// "share your day" means — the thread copy is the extra, not the point.
enum DayPhotoTarget {
  widget('Widget', '🏠', toWidget: true, toChat: false),
  chat('Chat', '💬', toWidget: false, toChat: true),
  both('Both', '✨', toWidget: true, toChat: true);

  const DayPhotoTarget(
    this.label,
    this.emoji, {
    required this.toWidget,
    required this.toChat,
  });

  final String label;
  final String emoji;
  final bool toWidget;
  final bool toChat;
}

/// The conversation, minus anything sent only to the home screen.
///
/// Filtered here rather than in the query because [flowerMessagesProvider]
/// also feeds the widget and day-photo lookups, which specifically need the
/// rows this hides.
/// Keeps the AsyncValue rather than flattening to a list: the thread needs
/// loading and error apart from empty, and `valueOrNull ?? []` would render
/// a failed load as "no messages yet" — which looks identical to the honest
/// empty state and means the opposite.
final chatMessagesProvider =
    Provider.autoDispose<AsyncValue<List<FlowerMessage>>>((ref) {
  return ref.watch(flowerMessagesProvider).whenData(
        (messages) => messages.where((m) => m.toChat).toList(growable: false),
      );
});

import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/flower_repository.dart';
import '../../data/reaction_choices.dart';
import '../../data/reaction_repository.dart';
import 'media_viewer.dart';
import 'message_quote.dart';
import 'call_bubble.dart';

/// One message in the thread — a flower or a line of text.
///
/// Mine and theirs are told apart by side and fill (blush vs white), not by
/// the signature gradient: design.md spends that gradient on the primary
/// action once per screen region, and here that's the send button.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onReply,
    this.onDelete,
  });

  /// Null where a thread has no composer to reply into.
  final VoidCallback? onReply;

  /// Null on their messages. See _showActions.
  final VoidCallback? onDelete;

  final FlowerMessage message;
  final bool isMine;

  static final _time = DateFormat.jm();

  @override
  Widget build(BuildContext context) {
    // A call is neither a flower nor words, and it doesn't take the mine/
    // theirs bubble treatment: a live one is an invitation with its own
    // card, a finished one is a centred line of history. See CallBubble.
    if (message.isCall) {
      return CallBubble(message: message, isMine: isMine);
    }

    const radius = Radius.circular(AppRadius.lg);
    final shape = BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      // Squared corner on the speaker's side — the tail, without drawing one.
      bottomLeft: isMine ? radius : const Radius.circular(4),
      bottomRight: isMine ? const Radius.circular(4) : radius,
    );

    // ⚠️ A flower gets **no bubble**. The Polaroid is already a card with
    // its own frame, border and shadow, and putting it inside the speech
    // bubble drew a card inside a card — two borders, two backgrounds, and
    // a tinted margin around a white photograph.
    if (message.flower != null) {
      return _pressable(
          context,
          Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.66,
              ),
              child: _buildFlower(context),
            ),
          ));
    }

    return _pressable(
        context,
        Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.76,
            ),
            decoration: BoxDecoration(
              color: isMine ? AppColors.blush : AppColors.surface,
              borderRadius: shape,
              border: Border.all(
                color: isMine ? AppColors.blushMid : AppColors.border,
              ),
            ),
            child: ClipRRect(
              borderRadius: shape,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // What this is answering, above what it says.
                  if (message.replyTo != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child:
                          MessageQuote(replyTo: message.replyTo, onDark: false),
                    ),
                  message.isPhoto ? _buildPhoto(context) : _buildText(),
                ],
              ),
            ),
          ),
        ));
  }

  /// Swipe right to reply; long-press for everything else.
  ///
  /// 🔴 Reply used to be buried in the long-press menu with Delete. Two very
  /// different acts behind one gesture, and the common one — answering
  /// something — cost a press, a wait, a sheet and a tap. Swipe is the
  /// gesture every messaging app has taught for exactly this, and it costs
  /// one movement.
  ///
  /// ⚠️ Long-press stays, for Delete. It is the destructive one, so it keeps
  /// the deliberate gesture: nothing should be deletable by a flick.
  Widget _pressable(BuildContext context, Widget child) {
    // 🔴 Long-press is on **every** message now, not only your own. It used
    // to be gated on `onDelete`, which is null on theirs — so their
    // messages had no long-press at all, and reacting is the one thing you
    // do to something somebody else said.
    final body = GestureDetector(
      // 🔴 `onLongPressStart`, not `onLongPress`: the bar floats over the
      // message it belongs to, and the only way to know where that is is
      // where the finger landed.
      onLongPressStart: (details) =>
          _showActions(context, details.globalPosition),
      child: child,
    );

    // Marks hang under the bubble on the speaker's side, so they read as
    // belonging to that message rather than to the one below it.
    final marked = Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [body, _ReactionPill(messageId: message.id)],
    );

    if (onReply == null) return marked;
    return _SwipeToReply(onReply: onReply!, child: marked);
  }

  /// The floating bar, over the message that was pressed.
  ///
  /// 🔴 Was a modal bottom sheet. A sheet slides up from the far edge of a
  /// tall phone, which puts the six choices as far from the message as the
  /// screen allows — you press a bubble at the top and answer it at the
  /// bottom, having lost sight of which one you pressed. Every messenger
  /// floats this for the same reason.
  void _showActions(BuildContext context, Offset at) {
    HapticFeedback.selectionClick();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      // Light enough that the thread stays readable behind it — the message
      // you are answering has to stay visible, which is the whole point.
      barrierColor: Colors.black.withValues(alpha: .16),
      transitionDuration: AppMotion.micro,
      pageBuilder: (_, __, ___) => _ReactionOverlay(
        at: at,
        isMine: isMine,
        messageId: message.id,
        onDelete: onDelete,
      ),
      transitionBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: AppMotion.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .88, end: 1).animate(curved),
            // Grows out of the message rather than the middle of nowhere.
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: child,
          ),
        );
      },
    );
  }

  // ── Text message ──────────────────────────────────
  Widget _buildText() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message.note ?? '', style: AppText.body(AppColors.ink)),
          const SizedBox(height: 2),
          _MetaRow(message: message, isMine: isMine, time: _time),
        ],
      ),
    );
  }

  // ── Day photo ─────────────────────────────────────
  /// The photo stays here forever, even after it has dropped off the
  /// partner's home screen — that expiry is a widget rule, not a data one.
  /// Once it has expired the bubble says so, so the two surfaces don't
  /// silently disagree.
  Widget _buildPhoto(BuildContext context) {
    // Only a photo that was actually sent to the home screen can have left
    // it. A chat-only photo never went, so saying it expired invents a
    // history the sender did not choose.
    final expired = message.toWidget && !message.isFreshForWidget;
    return Consumer(
      builder: (context, ref, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            // Tapping a picture opens it. Obvious enough that its absence
            // read as the thumbnail being all there was.
            onTap: () => showMediaViewer(
              context,
              title: isMine ? 'Your day' : 'Their day',
              subtitle: message.note,
              imagePath: message.imagePath,
              fileName: 'dayflower-day-${message.id}.jpg',
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: FutureBuilder<String>(
                future: ref
                    .read(flowerRepositoryProvider)
                    .signedPhotoUrl(message.imagePath!),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Container(
                      height: 160,
                      color: AppColors.surfaceSubtle,
                      alignment: Alignment.center,
                      child:
                          Text('Photo unavailable', style: AppText.caption()),
                    );
                  }
                  if (!snap.hasData) {
                    return const SizedBox(
                      height: 180,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  return Image.network(
                    snap.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: AppColors.surfaceSubtle,
                      alignment: Alignment.center,
                      child:
                          Text("Photo unavailable", style: AppText.caption()),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔴 A picture sent to the conversation is just a picture.
                // This footer said "Your day · on the home screen" under
                // every photo in the thread, including ones that had
                // deliberately not been sent there — a caption describing
                // somewhere the photo never went.
                if (message.toWidget) ...[
                  Text(
                    expired
                        ? 'Your day · expired'
                        : 'Your day · on the home screen',
                    style: AppText.label(
                        expired ? AppColors.muted : AppColors.secondary),
                  ),
                  if (message.note != null && message.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('“${message.note}”',
                        style: AppText.note().copyWith(fontSize: 14.5)),
                  ],
                  const SizedBox(height: 2),
                ]
                // ⚠️ Except a card, which is chat-only by design and whose
                // whole message lives in that note. Its first line is the
                // occasion written by the card maker, so only the rest is
                // the person talking.
                else if (message.isCard && (message.note ?? '').isNotEmpty) ...[
                  Text(
                    message.note!.split('\n').skip(1).join('\n').trim(),
                    style: AppText.note().copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 2),
                ],
                _MetaRow(message: message, isMine: isMine, time: _time),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Flower message ────────────────────────────────
  /// A flower arrives as a Polaroid.
  ///
  /// ⚠️ The frame is the *message*, not decoration. A flower here is a thing
  /// somebody chose and sent, and a square picture with its name written
  /// under it is what that has looked like since long before phones. Even
  /// margin at the top and sides, a deep one at the foot, and the name
  /// sitting in that foot the way it would be written on the card.
  ///
  /// ⚠️ White whoever sent it. The bubble around it is pink for yours and
  /// grey for theirs; a Polaroid that changed colour with the sender would
  /// stop reading as a photograph.
  Widget _buildFlower(BuildContext context) {
    final flower = message.flower!;
    final note = message.note;
    final hasNote = note != null && note.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => showMediaViewer(
              context,
              title: flower.name,
              subtitle: flower.meaning,
              asset: flower.asset,
              fileName: 'dayflower-${flower.id}.jpg',
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Image.asset(
                  flower.asset,
                  fit: BoxFit.cover,
                  semanticLabel: flower.name,
                  errorBuilder: (_, __, ___) => Container(
                    color: flower.color.withValues(alpha: .14),
                    alignment: Alignment.center,
                    child: Text(
                      flower.emoji,
                      style: const TextStyle(fontSize: 56),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // The caption band, roomy even with nothing written in it — a
          // Polaroid with a thin foot is just a photo.
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 10, 2, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // TikTok Sans italic — the italic style for personal notes,
                // kept for what a person wrote or chose.
                Text(
                  flower.name,
                  style: AppText.note(AppColors.ink)
                      .copyWith(fontSize: 16, height: 1.2),
                ),
                // ⚠️ The flower's dictionary meaning used to sit here.
                // It went because the sender can write their own line and
                // usually does — and a stock definition printed under
                // somebody's message is the app talking over them.
                if (hasNote) ...[
                  const SizedBox(height: 4),
                  // Plain text, not the TikTok Sans italic the app uses for
                  // quotes. This is a message somebody typed, and setting
                  // it in the quoting face made it read as something the
                  // app had decided to italicise on their behalf.
                  Text(note, style: AppText.body(AppColors.ink)),
                ],
                if (message.toWidget) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(
                        CupertinoIcons.device_phone_portrait,
                        size: 13,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isMine
                              ? 'On their home screen'
                              : 'On your home screen',
                          style: AppText.caption(AppColors.secondary),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 2),
                _MetaRow(message: message, isMine: isMine, time: _time),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Drag a bubble to the right to reply to it.
///
/// ⚠️ **Horizontal drag only, and it must not fight the list.** A bubble that
/// claimed vertical drags would stop the thread scrolling through it, so this
/// uses `onHorizontalDrag*`, which the gesture arena hands over only once the
/// movement is clearly sideways.
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({required this.onReply, required this.child});

  final VoidCallback onReply;
  final Widget child;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  /// How far the bubble has been dragged, in points.
  double _dx = 0;

  /// Past this, letting go replies. Also where the bubble stops moving, so
  /// the resistance itself says "that is far enough" without a label.
  static const _trigger = 56.0;

  /// ⚠️ Fires on *crossing* the threshold, not on release. The buzz is what
  /// tells you it will send while your thumb is still down — a confirmation
  /// that arrives after you have let go is a report, not feedback.
  bool _armed = false;

  void _update(DragUpdateDetails d) {
    setState(() {
      // Right only. Left is where "delete on swipe" lives in other apps, and
      // this app deletes from a menu — an unclaimed direction is better than
      // one that does something surprising.
      _dx = (_dx + d.delta.dx).clamp(0.0, _trigger);
    });
    if (!_armed && _dx >= _trigger) {
      _armed = true;
      HapticFeedback.selectionClick();
    } else if (_armed && _dx < _trigger) {
      _armed = false;
    }
  }

  void _end(DragEndDetails _) {
    final reply = _armed;
    setState(() {
      _dx = 0;
      _armed = false;
    });
    if (reply) widget.onReply();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => setState(() {
        _dx = 0;
        _armed = false;
      }),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // The arrow, revealed by the bubble moving off it. Fades in with
          // the drag so a half-hearted swipe shows a half-drawn hint rather
          // than appearing all at once.
          Opacity(
            opacity: (_dx / _trigger).clamp(0.0, 1.0),
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child:
                  AppIcon(CupertinoIcons.reply, size: 17, color: AppColors.muted),
            ),
          ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Timestamp plus, on your own messages, the delivery ticks.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.message,
    required this.isMine,
    required this.time,
  });

  final FlowerMessage message;
  final bool isMine;
  final DateFormat time;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          time.format(message.sentAt),
          style: AppText.caption().copyWith(fontSize: 10.5),
        ),
        if (isMine) ...[
          const SizedBox(width: 4),
          AppIcon(
            message.isSeen ? Icons.done_all_rounded : Icons.done_rounded,
            size: 14,
            color: message.isSeen ? AppColors.secondary : AppColors.muted,
          ),
        ],
      ],
    );
  }
}

/// "Today" / "Yesterday" / "Mon, 4 Aug" divider between days.
class ChatDateDivider extends StatelessWidget {
  const ChatDateDivider({super.key, required this.date});

  final DateTime date;

  static final _long = DateFormat('EEE, d MMM');

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return _long.format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(_label, style: AppText.label(AppColors.body)),
      ),
    );
  }
}

/* ── Reactions ───────────────────────────────────── */

/// Your own mark on [messageId], or null.
///
/// Pulled out because both halves below need it and they must never
/// disagree — the row highlights what the pill is showing.
String? _myReaction(WidgetRef ref, String messageId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final marks = ref.watch(reactionsProvider).valueOrNull?[messageId];
  if (marks == null) return null;
  for (final mark in marks) {
    if (mark.userId == userId) return mark.emoji;
  }
  return null;
}

/// The marks on one message, under its bubble.
///
/// ⚠️ Renders nothing at all when there are none — not an empty chip, not a
/// reserved gap. A thread where most messages have no reaction would
/// otherwise grow a column of blank space down one side.
class _ReactionPill extends ConsumerWidget {
  const _ReactionPill({required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = ref.watch(reactionsProvider).valueOrNull?[messageId];
    if (marks == null || marks.isEmpty) return const SizedBox.shrink();

    // Two people, so at most two marks — but they can be the same one, and
    // "❤️❤️" reads as a rendering bug. Collapse and count instead.
    final counts = <String, int>{};
    for (final mark in marks) {
      counts.update(mark.emoji, (n) => n + 1, ifAbsent: () => 1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in counts.entries) ...[
            Text(entry.key, style: const TextStyle(fontSize: 13)),
            if (entry.value > 1)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text('${entry.value}', style: AppText.caption()),
              ),
            const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}

/// The bar itself, positioned over the thread.
class _ReactionOverlay extends StatelessWidget {
  const _ReactionOverlay({
    required this.at,
    required this.isMine,
    required this.messageId,
    this.onDelete,
  });

  /// Where the finger went down, in global coordinates.
  final Offset at;
  final bool isMine;
  final String messageId;
  final VoidCallback? onDelete;

  /// Roughly the bar's height plus a gap, so it sits clear of the thumb
  /// that opened it.
  static const _lift = 76.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final ceiling = media.padding.top + AppSpace.xs;
    // Leaves room for the bar and, under it, the Delete card.
    final floor = media.size.height - media.padding.bottom - 170;

    // ⚠️ Above the finger normally, below it when there is no room — a
    // message near the top of the screen would otherwise open a bar that is
    // half off it.
    var top = at.dy - _lift;
    if (top < ceiling) top = at.dy + AppSpace.md;
    top = top.clamp(ceiling, floor > ceiling ? floor : ceiling);

    return Stack(
      children: [
        Positioned(
          top: top,
          left: AppSpace.sm,
          right: AppSpace.sm,
          child: Align(
            // On the speaker's side, so it reads as belonging to that
            // message rather than hovering over the whole thread.
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ReactionBar(messageId: messageId),
                if (onDelete != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  _DeleteCard(onDelete: onDelete!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The six choices.
class _ReactionBar extends ConsumerWidget {
  const _ReactionBar({required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final pair = ref.watch(currentPairProvider).valueOrNull;
    final choices = ref.watch(reactionChoicesProvider);
    if (userId == null || pair == null) return const SizedBox.shrink();
    final mine = _myReaction(ref, messageId);

    Future<void> tap(String emoji) async {
      HapticFeedback.selectionClick();
      Navigator.of(context).pop();
      final reactions = ref.read(reactionRepositoryProvider);
      try {
        if (tapRemoves(mine: mine, tapped: emoji)) {
          await reactions.clear(messageId: messageId, userId: userId);
        } else {
          await reactions.set(
            pairId: pair.id,
            messageId: messageId,
            userId: userId,
            emoji: emoji,
          );
        }
      } catch (_) {
        // The stream is the source of truth and never took the change, so
        // nothing on screen is now lying. An error banner over a failed
        // emoji is worse than the emoji not appearing.
      }
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.border),
          boxShadow: AppElevation.lift,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in choices)
              InkWell(
                onTap: () => tap(emoji),
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // The one already chosen is filled, so the bar says what
                    // tapping it again will do.
                    color: mine == emoji ? AppColors.blush : null,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Yours only. Deleting is taking back something you said; nobody gets to
/// take back what somebody else said.
class _DeleteCard extends StatelessWidget {
  const _DeleteCard({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          Navigator.of(context).pop();
          onDelete();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
            boxShadow: AppElevation.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(CupertinoIcons.delete,
                  size: 18, color: AppColors.danger),
              const SizedBox(width: AppSpace.xs),
              Text('Delete for both', style: AppText.body(AppColors.danger)),
            ],
          ),
        ),
      ),
    );
  }
}

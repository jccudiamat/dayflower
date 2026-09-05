import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/flower_repository.dart';
import 'media_viewer.dart';
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
  });

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

    return Align(
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
          child: message.isPhoto
              ? _buildPhoto(context)
              : message.isText
                  ? _buildText()
                  : _buildFlower(context),
        ),
      ),
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
    final expired = !message.isFreshForWidget;
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
                _MetaRow(message: message, isMine: isMine, time: _time),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Flower message ────────────────────────────────
  Widget _buildFlower(BuildContext context) {
    final flower = message.flower!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The artwork is the message, so it runs edge to edge of the bubble
        // rather than sitting as a thumbnail beside text.
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                flower.name,
                style: AppText.subtitle().copyWith(fontSize: 15),
              ),
              Text(flower.meaning, style: AppText.caption()),
              if (message.note != null && message.note!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '“${message.note}”',
                  style: AppText.note().copyWith(fontSize: 14.5),
                ),
              ],
              if (message.toWidget) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.device_phone_portrait,
                      size: 13,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isMine ? 'On their home screen' : 'On your home screen',
                      style: AppText.caption(AppColors.secondary),
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
          Icon(
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

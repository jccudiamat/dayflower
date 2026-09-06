import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/flower_repository.dart';

/// The message a reply is answering, shown above the reply itself.
///
/// ⚠️ **Replies have carried `reply_to` since migration 0023 and nothing has
/// ever displayed it.** The widget's tulip, the story viewer's reactions and
/// every typed reply all recorded what they were answering; the thread then
/// showed them as loose messages. A 🌷 arriving three hours after the photo
/// it was about read as an unexplained flower — which is precisely the thing
/// the column was added to prevent.
class MessageQuote extends ConsumerWidget {
  const MessageQuote({
    super.key,
    required this.replyTo,
    required this.onDark,
  });

  final String? replyTo;

  /// Quotes sit inside bubbles of two colours and, in the story viewer, over
  /// a photograph.
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (replyTo == null || replyTo!.isEmpty) return const SizedBox.shrink();

    final quoted = ref.watch(quotedMessageProvider(replyTo));
    final tint = onDark ? AppColors.onDark : AppColors.ink;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: (onDark ? AppColors.onDark : AppColors.ink)
            .withValues(alpha: onDark ? .12 : .05),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: const Border(
          left: BorderSide(color: AppColors.brand, width: 3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (quoted != null && quoted.isPhoto) ...[
            Icon(CupertinoIcons.photo,
                size: 13, color: tint.withValues(alpha: .7)),
            const SizedBox(width: 5),
          ] else if (quoted != null && quoted.flower != null) ...[
            Text(quoted.flower!.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              // ⚠️ Null is two things that read the same way: scrolled out
              // of the loaded window, or deleted since. `reply_to` is set
              // null rather than cascaded, so a reply outlives what it
              // answered — and "unavailable" is true of both.
              quoted == null ? 'Message unavailable' : quoted.alertLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(tint.withValues(alpha: .75)),
            ),
          ),
        ],
      ),
    );
  }
}

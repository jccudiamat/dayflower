import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/profile_photo.dart';
import '../../../calls/domain/call.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../presence/data/presence_repository.dart';
import '../../../presence/domain/presence.dart';
import '../../data/flower_repository.dart';

/// Your conversation with them, as one row of the Chats list: their face,
/// their name, the last thing either of you said, when, and how much of it
/// is unread.
///
/// The row opens the conversation; their face, pressed on its own, opens
/// their photo instead, as it does in WhatsApp.
class ConversationRow extends ConsumerWidget {
  const ConversationRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The live row first, as the chat header reads it, so a new name or face
    // lands on the list without leaving it.
    final partner = ref.watch(partnerProfileStreamProvider).valueOrNull ??
        ref.watch(partnerProfileProvider).valueOrNull;
    final messages = ref.watch(flowerMessagesProvider).valueOrNull ?? const [];
    final unread = ref.watch(unreadMessageCountProvider);
    final userId = ref.watch(currentUserIdProvider);
    final online =
        activeLabel(ref.watch(partnerLastActiveProvider).valueOrNull) ==
            'Active now';

    // Newest-first, so the head of the list is the last thing either of you
    // said. (See flowerMessagesProvider: this ordering is load-bearing.)
    final last = messages.isEmpty ? null : messages.first;
    final name = partner?.petName ?? partner?.displayName ?? '…';
    final hasUnread = unread > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Pushed, not gone to: back from the conversation returns here.
        onTap: () => context.push(Routes.chat),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: ChatsStyle.gutter, vertical: ChatsStyle.rowPad),
          child: Row(
            children: [
              Stack(clipBehavior: Clip.none, children: [
                ProfilePhotoButton(
                    profile: partner, name: name, size: ChatsStyle.avatar),
                // Instagram's dot: they are in the app right now.
                if (online)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: IgnorePointer(
                      child: Semantics(
                        label: 'Active now',
                        child: Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: ChatsStyle.online,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.background, width: 2.5),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(width: ChatsStyle.avatarGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ChatsStyle.name()),
                      ),
                      const SizedBox(width: AppSpace.xs),
                      Text(conversationStamp(last?.sentAt),
                          style: ChatsStyle.stamp(unread: hasUnread)),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Expanded(
                        child: Text(
                          conversationPreview(last,
                              isMine: last != null && last.senderId == userId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ChatsStyle.preview(unread: hasUnread),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: AppSpace.xs),
                        _UnreadBadge(unread),
                      ],
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a chat list shows instead of the message itself: text verbatim, a
/// flower or photo named rather than rendered, and "You:" so you can tell
/// whose turn it was without opening it.
String conversationPreview(FlowerMessage? m, {required bool isMine}) {
  if (m == null) return 'Say hello 👋';
  final caption = (m.note != null && m.note!.isNotEmpty) ? ' · ${m.note}' : '';
  final String body;
  if (m.isPhoto) {
    body = '📷 Photo$caption';
  } else if (m.isCall) {
    // Without this branch a call fell through to the last one and read as
    // "🌷 A flower", which is the wrong message about the wrong event.
    final kind = m.call == CallMode.video ? 'Video call' : 'Voice call';
    body = m.isLiveCall ? '📞 $kind · now' : '📞 $kind';
  } else if (m.isText) {
    body = m.note ?? '';
  } else {
    body = '🌷 ${m.flower?.name ?? 'A flower'}$caption';
  }
  return isMine ? 'You: $body' : body;
}

/// Time for today, "Yesterday", weekday inside the last week, then a date:
/// the ladder every messaging app uses.
String conversationStamp(DateTime? sentAt, {DateTime? now}) {
  if (sentAt == null) return '';
  final at = sentAt.toLocal();
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return DateFormat('h:mm a').format(at);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat('EEE').format(at);
  return DateFormat('d MMM').format(at);
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 22),
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(count > 99 ? '99+' : '$count',
            style: AppText.label(Colors.white).copyWith(letterSpacing: 0)),
      );
}

/// A place in the list kept for something that is not built yet.
///
/// Drawn in the list's own shape so it reads as part of what Chats will be,
/// but greyed and inert: no ripple, no tap, and a screen reader hears
/// "coming soon" rather than a button that does nothing.
class ComingSoonRow extends StatelessWidget {
  const ComingSoonRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: '$title, coming soon. $subtitle',
        child: ExcludeSemantics(
          child: Opacity(
            opacity: ChatsStyle.soonOpacity,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ChatsStyle.gutter, vertical: ChatsStyle.rowPad),
              child: Row(children: [
                Container(
                  width: ChatsStyle.avatar,
                  height: ChatsStyle.avatar,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: AppIcon(icon, size: 24, color: AppColors.muted),
                ),
                const SizedBox(width: ChatsStyle.avatarGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ChatsStyle.name()
                              .copyWith(color: AppColors.muted)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ChatsStyle.preview(unread: false)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('Soon', style: AppText.label()),
                ),
              ]),
            ),
          ),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../calls/domain/call.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../data/flower_repository.dart';

/// The conversation as a single tappable row — avatar, last message, time,
/// unread badge.
///
/// Shared by Home and the Flowers inbox so the two can never drift; Home
/// shows it in place of the reunion card, which now lives on Dates.
class ConversationCard extends ConsumerWidget {
  const ConversationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final messages = ref.watch(flowerMessagesProvider).valueOrNull ?? const [];
    final unread = ref.watch(unreadMessageCountProvider);
    final userId = ref.watch(currentUserIdProvider);

    // Newest-first, so the head of the list is the last thing either of you
    // said. (See flowerMessagesProvider — this ordering is load-bearing.)
    final last = messages.isEmpty ? null : messages.first;

    return _Row(
      partner: partner,
      name: partner?.petName ?? partner?.displayName ?? '…',
      last: last,
      isMine: last != null && last.senderId == userId,
      unread: unread,
      onTap: () => context.go(Routes.chat),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.partner,
    required this.name,
    required this.last,
    required this.isMine,
    required this.unread,
    required this.onTap,
  });

  final UserProfile? partner;
  final String name;
  final FlowerMessage? last;
  final bool isMine;
  final int unread;
  final VoidCallback onTap;

  /// What a chat list shows instead of the message itself: text verbatim,
  /// a flower or photo named rather than rendered, and "You:" so you can
  /// tell whose turn it was without opening it.
  String get _preview {
    final m = last;
    if (m == null) return 'Say hello 👋';
    final caption =
        (m.note != null && m.note!.isNotEmpty) ? ' · ${m.note}' : '';
    final String body;
    if (m.isPhoto) {
      body = '📷 Photo$caption';
    } else if (m.isCall) {
      // Before the branch existed a call fell through to the `else` and read
      // as "🌷 A flower", which is the wrong message about the wrong event.
      final kind = m.call == CallMode.video ? 'Video call' : 'Voice call';
      body = m.isLiveCall ? '📞 $kind · now' : '📞 $kind';
    } else if (m.isText) {
      body = m.note ?? '';
    } else {
      body = '🌷 ${m.flower?.name ?? 'A flower'}$caption';
    }
    return isMine ? 'You: $body' : body;
  }

  /// Time for today, "Yesterday", weekday inside the last week, then a date —
  /// the ladder every messaging app uses.
  String get _stamp {
    final m = last;
    if (m == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(m.sentAt.year, m.sentAt.month, m.sentAt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return DateFormat('h:mm a').format(m.sentAt);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEE').format(m.sentAt);
    return DateFormat('d MMM').format(m.sentAt);
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              UserAvatar(partner, size: 52),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.subtitle(),
                          ),
                        ),
                        const SizedBox(width: AppSpace.xs),
                        Text(
                          _stamp,
                          style: AppText.caption(
                            hasUnread ? AppColors.brand : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption(
                              hasUnread ? AppColors.ink : AppColors.muted,
                            ).copyWith(
                              fontWeight:
                                  hasUnread ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: AppSpace.xs),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: AppText.label(Colors.white)
                                  .copyWith(letterSpacing: 0),
                            ),
                          ),
                        ],
                      ],
                    ),
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

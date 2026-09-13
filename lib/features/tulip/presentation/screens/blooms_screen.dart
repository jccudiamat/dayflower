import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../../core/widgets/flower_image.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../data/flower_repository.dart';
import '../../../onboarding/data/user_repository.dart';

/// The Flowers tab.
///
/// The tab used to open the conversation directly, which meant the one place
/// named after the flowers never showed you any — every bloom either of you
/// had ever sent was buried in a thread you had to scroll. This is where
/// they live: the newest one large, the rest as a garden underneath, and the
/// conversation one tap away.
class BloomsScreen extends ConsumerWidget {
  const BloomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final messages = ref.watch(flowerMessagesProvider);
    final unread = ref.watch(unreadMessageCountProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final theirName = partner?.petName ?? partner?.displayName ?? 'them';

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: messages.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          // Empty and failed look identical if a failure falls through to the
          // empty state, and they mean opposite things.
          error: (_, __) => const _Message(
            title: 'The garden could not load',
            body: 'Check your connection and pull to try again.',
          ),
          data: (all) {
            final blooms = [
              for (final m in all)
                if (m.flower != null) m,
            ];
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: AppSpace.screen,
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      const SizedBox(height: AppSpace.sm),
                      FeatureScreenHeader(
                        title: 'Flowers',
                        subtitle: blooms.isEmpty
                            ? 'Every bloom you send each other lands here.'
                            : '${blooms.length} between you and $theirName',
                      ),
                      const SizedBox(height: AppSpace.md),
                      _OpenChat(unread: unread),
                      const SizedBox(height: AppSpace.md),
                      if (blooms.isNotEmpty) ...[
                        _Latest(message: blooms.first, mine: blooms.first.senderId == userId),
                        const SizedBox(height: AppSpace.md),
                        Text('THE GARDEN', style: AppText.label()),
                        const SizedBox(height: AppSpace.xs),
                      ],
                    ]),
                  ),
                ),
                if (blooms.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Message(
                      title: 'Nothing picked yet',
                      body: 'Open the conversation and send $theirName their first one.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: AppSpace.xs,
                        crossAxisSpacing: AppSpace.xs,
                        // Taller than wide: the tile is artwork with a date
                        // under it, and a square crops the stems off.
                        childAspectRatio: .78,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _Bloom(
                          message: blooms[i],
                          mine: blooms[i].senderId == userId,
                        ),
                        childCount: blooms.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ── The way into the conversation ─────────────────── */
class _OpenChat extends StatelessWidget {
  const _OpenChat({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: () => context.go(Routes.chat),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.sm),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  gradient: AppGradients.cta,
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.chat_bubble_2_fill,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Your conversation', style: AppText.title()),
                    Text(
                      unread > 0
                          ? '$unread new ${unread == 1 ? 'message' : 'messages'}'
                          : 'Send a flower, a photo, or just say hello',
                      style: AppText.caption(
                          unread > 0 ? AppColors.brand : AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.only(right: AppSpace.xxs),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('$unread',
                      style: AppText.caption(Colors.white)
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
              const Icon(CupertinoIcons.chevron_forward,
                  size: 16, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/* ── The newest bloom, large ────────────────────────── */
class _Latest extends StatelessWidget {
  const _Latest({required this.message, required this.mine});

  final FlowerMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final flower = message.flower!;
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: FlowerImage(flower: flower, size: 96),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mine ? 'YOU SENT' : 'THEY SENT', style: AppText.label()),
                const SizedBox(height: AppSpace.xxs),
                Text(flower.name, style: AppText.title()),
                Text(flower.meaning, style: AppText.note(AppColors.muted)),
                if ((message.note ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text('“${message.note!.trim()}”',
                      style: AppText.note(AppColors.body),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: AppSpace.xxs),
                Text(DateFormat('d MMM · h:mm a').format(message.sentAt),
                    style: AppText.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ── One tile in the garden ─────────────────────────── */
class _Bloom extends StatelessWidget {
  const _Bloom({required this.message, required this.mine});

  final FlowerMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final flower = message.flower!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: FlowerImage(flower: flower, size: double.infinity),
                ),
              ),
              // Whose it was, without a caption per tile — the garden is
              // mostly a shape you scan, not a list you read.
              if (!mine)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(DateFormat('d MMM').format(message.sentAt),
            style: AppText.caption(), textAlign: TextAlign.center),
      ],
    );
  }
}

/* ── Empty and failed ───────────────────────────────── */
class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title, body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpace.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppText.title(), textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.xxs),
            Text(body,
                style: AppText.body(AppColors.muted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

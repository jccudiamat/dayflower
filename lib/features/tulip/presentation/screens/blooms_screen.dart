import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app_router.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../../core/widgets/flower_image.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/data/mood_prefs.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../data/flower_repository.dart';

/// The Flowers tab.
///
/// The tab used to open the conversation directly, which meant the one place
/// named after the flowers never showed you any — every bloom either of you
/// had ever sent was buried in a thread you had to scroll. This is where
/// they live, with the conversation previewed at the top rather than hidden
/// behind a row that said nothing.
class BloomsScreen extends ConsumerWidget {
  const BloomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final messages = ref.watch(flowerMessagesProvider);
    final unread = ref.watch(unreadMessageCountProvider);
    // The live row: a mood set on their phone should reach this card while
    // it is on screen, which is the whole reason `users` is in the realtime
    // publication. Falls back to the cached read on a cold start.
    final partner = ref.watch(partnerProfileStreamProvider).valueOrNull ??
        ref.watch(partnerProfileProvider).valueOrNull;
    final theirName = partner?.petName ?? partner?.displayName ?? 'them';
    final mood = ref.watch(partnerMoodProvider);
    final chat = ref.watch(chatMessagesProvider).valueOrNull;
    final last = (chat == null || chat.isEmpty) ? null : chat.first;

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
            // A bouquet made on the website arrives as a pasted link, not as
            // a flower row — the site has no idea who anyone's partner is.
            // See FlowerMessage.bouquetGiftId.
            final bouquets = [
              for (final m in all)
                if (m.isBouquet) m,
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
                        subtitle: blooms.isEmpty && bouquets.isEmpty
                            ? 'Every bloom you send each other lands here.'
                            : '${blooms.length + bouquets.length} between you and $theirName',
                      ),
                      const SizedBox(height: AppSpace.md),
                      _Conversation(
                        partner: partner,
                        name: theirName,
                        mood: mood,
                        last: last,
                        mine: last != null && last.senderId == userId,
                        unread: unread,
                      ),
                      if (bouquets.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.md),
                        Text('FROM THE FLOWER SHOP', style: AppText.label()),
                        const SizedBox(height: AppSpace.xs),
                        _Bouquets(messages: bouquets),
                      ],
                      if (blooms.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.md),
                        _Latest(
                          message: blooms.first,
                          mine: blooms.first.senderId == userId,
                        ),
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
                      body:
                          'Open the conversation and send $theirName their first one.',
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

/* ── The conversation, previewed ────────────────────── */
/// Who it is with, what was said last, and — for your own last message —
/// whether they have seen it. The row this replaces said only "Your
/// conversation", so you had to open the thread to learn anything at all.
class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.partner,
    required this.name,
    required this.mood,
    required this.last,
    required this.mine,
    required this.unread,
  });

  final UserProfile? partner;
  final String name;

  /// How they said they are feeling, or null when they have not said or it
  /// has gone stale. Null is shown as **nothing** — see the title below.
  final Mood? mood;

  final FlowerMessage? last;
  final bool mine;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final message = last;
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
              UserAvatar(partner, size: 46),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Their name, and how they are, as one sentence:
                        // "Hubby is feeling loved 🥰". The name stays in the
                        // heavier style so the row is still scannable as a
                        // conversation rather than as a status.
                        //
                        // ⚠️ With no mood this is the bare name, not "is
                        // feeling nothing" and not a placeholder inviting
                        // them to set one. A mood is theirs to volunteer.
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: name,
                              style: AppText.title(),
                              children: mood == null
                                  ? null
                                  : [
                                      TextSpan(
                                        text: ' is feeling '
                                            '${mood!.label.toLowerCase()} '
                                            '${mood!.emoji}',
                                        style: AppText.body(AppColors.muted),
                                      ),
                                    ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (message != null)
                          Text(_when(message.sentAt), style: AppText.caption()),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        // Only your own message carries a receipt. Whether
                        // you have read theirs is a fact about you, not news.
                        if (message != null && mine) ...[
                          AppIcon(
                            message.seenAt != null
                                ? CupertinoIcons.checkmark_alt_circle_fill
                                : CupertinoIcons.checkmark_alt_circle,
                            size: 14,
                            color: message.seenAt != null
                                ? AppColors.secondary
                                : AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            message == null
                                ? 'Say hello — nothing here yet'
                                : message.previewFor(mine: mine),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: unread > 0 && !mine
                                ? AppText.body(AppColors.ink)
                                    .copyWith(fontWeight: FontWeight.w700)
                                : AppText.body(AppColors.muted),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: AppSpace.xxs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              '$unread',
                              style: AppText.caption(Colors.white)
                                  .copyWith(fontWeight: FontWeight.w700),
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

  /// Time today, weekday this week, date beyond it. "2:31 PM" on something
  /// from March tells you nothing.
  static String _when(DateTime at) {
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    if (sameDay) return DateFormat('h:mm a').format(at);
    if (now.difference(at).inDays < 7) return DateFormat('EEE').format(at);
    return DateFormat('d MMM').format(at);
  }
}

/* ── Bouquets made on the website ───────────────────── */
/// Shown as the card the website renders for the gift — the sealed vessel,
/// never the flowers, so opening it is still the moment it was meant to be.
class _Bouquets extends StatelessWidget {
  const _Bouquets({required this.messages});

  final List<FlowerMessage> messages;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: messages.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.xs),
        itemBuilder: (context, i) {
          final message = messages[i];
          return GestureDetector(
            onTap: () {
              final url = message.bouquetUrl;
              if (url == null) return;
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      width: 186,
                      color: AppColors.surfaceSubtle,
                      child: Image.network(
                        message.bouquetCardUrl!,
                        fit: BoxFit.cover,
                        // Fetched from the website, so a dead connection has
                        // to read as a bouquet rather than a broken tile.
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('💐', style: TextStyle(fontSize: 32)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM').format(message.sentAt),
                  style: AppText.caption(),
                ),
              ],
            ),
          );
        },
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
                  Text(
                    '“${message.note!.trim()}”',
                    style: AppText.note(AppColors.body),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpace.xxs),
                Text(
                  DateFormat('d MMM · h:mm a').format(message.sentAt),
                  style: AppText.caption(),
                ),
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
        Text(
          DateFormat('d MMM').format(message.sentAt),
          style: AppText.caption(),
          textAlign: TextAlign.center,
        ),
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
            Text(
              body,
              style: AppText.body(AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

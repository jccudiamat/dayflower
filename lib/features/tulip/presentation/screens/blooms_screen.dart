import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../../core/widgets/feature_cards.dart';
import '../../../../core/widgets/flower_image.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../data/flower_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// The Dayflower center, reusing the existing flowers and bouquet collection.
class BloomsScreen extends ConsumerWidget {
  const BloomsScreen({super.key, this.openBouquet});
  final Future<bool> Function(Uri)? openBouquet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final messages = ref.watch(flowerMessagesProvider);
    // The live row: a mood set on their phone should reach this card while
    // it is on screen, which is the whole reason `users` is in the realtime
    // publication. Falls back to the cached read on a cold start.
    final partner = ref.watch(partnerProfileStreamProvider).valueOrNull ??
        ref.watch(partnerProfileProvider).valueOrNull;
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
                        title: 'Dayflower',
                        subtitle: blooms.isEmpty && bouquets.isEmpty
                            ? 'Every bloom you send each other lands here.'
                            : '${blooms.length + bouquets.length} between you and $theirName',
                      ),
                      const SizedBox(height: AppSpace.md),
                      FeatureRow(
                        emoji: '🌷', color: AppColors.brand,
                        title: 'Send a flower', blurb: 'Pick a bloom and add a note',
                        onTap: () => context.push('${Routes.chat}?compose=flowers')),
                      const SizedBox(height: AppSpace.xs),
                      FeatureRow(
                        emoji: '💐', color: AppColors.secondary,
                        title: 'Create a bouquet', blurb: 'Opens the Dayflower bouquet creator',
                        onTap: () => _createBouquet(context)),
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
                          'Send $theirName a flower. Your blooms will collect here.',
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
  Future<void> _createBouquet(BuildContext context) async {
    try {
      final uri = Uri.parse('https://mydayflower.com/bouquet');
      final opened = await (openBouquet?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened) throw StateError('Could not open bouquet creator');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open the bouquet creator. Please try again.')));
      }
    }
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
                      // A public page's picture, so the plain URL cache is
                      // right - but a disk-backed one, not Image.network.
                      child: CachedNetworkImage(
                        imageUrl: message.bouquetCardUrl!,
                        fit: BoxFit.cover,
                        // Fetched from the website, so a dead connection has
                        // to read as a bouquet rather than a broken tile.
                        errorWidget: (_, __, ___) => const Center(
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

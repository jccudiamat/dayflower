import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../app_router.dart';
import '../../../../core/widgets/app_bottom_nav.dart';

import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/ios_back_button.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../../calls/data/call_usage.dart';
import '../../../calls/domain/call.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../data/flower_repository.dart';
import '../../data/reaction_choices.dart';
import '../widgets/media_viewer.dart';
import '../widgets/share_your_day.dart';
import '../../../../core/widgets/storage_image.dart';
import '../../../../core/widgets/profile_photo.dart';

/// What sits behind the two of you: how much calling is left this month, and
/// everything either of you has sent.
///
/// Reached by tapping their name in the chat header, because that is where
/// people press when they want to know about the person rather than the
/// conversation.
class ChatSettingsScreen extends ConsumerWidget {
  const ChatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final name = partner?.petName ?? partner?.displayName ?? 'Them';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IosBackButton(onTap: () => Navigator.of(context).maybePop()),
        title: Text('Chat settings', style: AppText.title()),
        centerTitle: false,
      ),
      body: ListView(
        padding: AppSpace.screen,
        children: [
          _PartnerHeader(partner: partner, name: name),
          const SizedBox(height: AppSpace.md),
          const _CallUsage(),
          const SizedBox(height: AppSpace.md),
          const _ReactionSettings(),
          const SizedBox(height: AppSpace.md),
          const _SharedMedia(),
          const SizedBox(height: AppSpace.lg),
        ],
      ),
    );
  }
}

/// The same shared-media grid, accessible directly from Memories.
class SharedPhotosScreen extends ConsumerWidget {
  const SharedPhotosScreen({super.key, this.myDaysOnly = false});
  final bool myDaysOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: AppColors.background,
    bottomNavigationBar: const AppBottomNav(),
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      leading: IosBackButton(onTap: () => context.canPop()
          ? context.pop() : context.go(Routes.memories)),
      title: Text(myDaysOnly ? 'My Day photos' : 'Shared photos', style: AppText.title()),
      actions: [if (myDaysOnly) IconButton(
        tooltip: 'Share your day', icon: const Icon(CupertinoIcons.camera),
        onPressed: () {
          ref.read(dayPhotoTargetProvider.notifier).state = DayPhotoTarget.myDay;
          context.push(Routes.flowers);
        })],
    ),
    body: ListView(padding: AppSpace.screen, children: [_SharedMedia(myDaysOnly: myDaysOnly)]),
  );
}

/* ── Who this conversation is with ──────────────────── */
/// Their face, large and centred, with their name under it - the way
/// WhatsApp opens a contact. No card around it: the person is the page's
/// heading, not one more panel among the settings below.
class _PartnerHeader extends StatelessWidget {
  const _PartnerHeader({required this.partner, required this.name});

  final UserProfile? partner;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xs, bottom: AppSpace.xs),
      child: Column(
        children: [
          // Pressed, it opens the picture itself.
          ProfilePhotoButton(profile: partner, name: name, size: 116),
          const SizedBox(height: AppSpace.sm),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.display(),
          ),
          const SizedBox(height: AppSpace.xxs),
          Text('Just the two of you',
              textAlign: TextAlign.center,
              style: AppText.body(AppColors.muted)),
        ],
      ),
    );
  }
}

/* ── Calling ────────────────────────────────────────── */
class _CallUsage extends ConsumerWidget {
  const _CallUsage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(callUsageProvider);

    return _Section(
      label: 'CALLING THIS MONTH',
      child: usage.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: Center(child: CupertinoActivityIndicator()),
        ),
        error: (_, __) => Text('Couldn’t read your calling minutes.',
            style: AppText.body(AppColors.muted)),
        data: (data) {
          // ⚠️ An unmetered build has nothing to run out of, and a ring
          // reading 0% of infinity measures nothing. Show the time spent and
          // stop — see CallUsage.isMetered for why this is not `allowance != null`.
          if (!data.isMetered) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_spent(data.total), style: AppText.stat()),
                Text('together on calls this month',
                    style: AppText.body(AppColors.muted)),
              ],
            );
          }
          final left = data.left(CallMode.voice);
          return Row(
            children: [
              ProgressRing(
                fraction: data.fraction,
                color: AppColors.brand,
                trackColor: AppColors.surfaceSubtle,
                size: 74,
                center: Text(
                  '${(data.fraction * 100).round()}%',
                  style: AppText.caption(AppColors.ink)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_spent(data.total), style: AppText.title()),
                    Text('used of your shared minutes',
                        style: AppText.caption()),
                    if (left != null) ...[
                      const SizedBox(height: AppSpace.xxs),
                      Text('${_spent(left)} left',
                          style: AppText.body(AppColors.body)),
                    ],
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      'Resets ${DateFormat('d MMMM').format(CallUsage.resetsOn)}',
                      style: AppText.caption(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Hours only once there are any — "0h 7m" reads like a broken clock.
  static String _spent(Duration d) {
    final hours = d.inHours, minutes = d.inMinutes % 60;
    if (hours == 0) return '$minutes min';
    return '${hours}h ${minutes}m';
  }
}

/* ── Everything either of you has sent ──────────────── */
class _SharedMedia extends ConsumerWidget {
  const _SharedMedia({this.myDaysOnly = false});
  final bool myDaysOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(flowerMessagesProvider);

    return messages.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => _Section(
        label: 'SHARED',
        child: Text('Couldn’t load your photos.',
            style: AppText.body(AppColors.muted)),
      ),
      data: (all) {
        // Everything ever sent, not just what is still live on the widget:
        // this is the album, and the 24-hour rule belongs to the home screen.
        final photos = [
          for (final m in all)
            if (m.isPhoto && (!myDaysOnly || m.toWidget)) m,
        ];
        return _Section(
          label: 'SHARED · ${photos.length} ${photos.length == 1 ? 'photo' : 'photos'}',
          child: photos.isEmpty
              ? Text(myDaysOnly ? 'Your shared My Day photos will collect here.' : 'Photos you send each other collect here.',
                  style: AppText.body(AppColors.muted))
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, i) => _Thumb(path: photos[i].imagePath!),
                ),
        );
      },
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MediaViewer(title: 'Your photo', imagePath: path,
            fileName: 'dayflower-photo.jpg'),
      )),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        color: AppColors.surfaceSubtle,
        // A dead connection and an object that is gone both draw the empty
        // panel. A third of the screen at most: the grid is three across.
        child: StorageImage.dayPhoto(
          path,
          fit: BoxFit.cover,
          decodeWidth: MediaQuery.sizeOf(context).width / 3,
          placeholder: const SizedBox.expand(),
          error: (_) => const SizedBox.expand(),
        ),
      ),
      ),
    );
  }
}

/* ── Section shell ──────────────────────────────────── */
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label()),
        const SizedBox(height: AppSpace.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: child,
        ),
      ],
    );
  }
}

/* ── Reactions ────────────────────────────────────── */

/// Which six sit on the bar when you press a message.
///
/// ⚠️ Yours, not the pair's. It decides what your own thumb reaches for —
/// the same kind of choice as the theme, and syncing it would mean one
/// person quietly rearranging the other's bar.
class _ReactionSettings extends ConsumerWidget {
  const _ReactionSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choices = ref.watch(reactionChoicesProvider);

    return _Section(
      label: 'REACTIONS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Press and hold any message to use these. Tap one to swap it.',
            style: AppText.caption(),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < choices.length; i++)
                _Slot(
                  emoji: choices[i],
                  onTap: () => _swap(context, ref, i, choices),
                ),
            ],
          ),
          if (!_isDefault(choices)) ...[
            const SizedBox(height: AppSpace.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    ref.read(reactionChoicesProvider.notifier).reset(),
                child: const Text('Reset'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static bool _isDefault(List<String> choices) {
    if (choices.length != defaultReactions.length) return false;
    for (var i = 0; i < choices.length; i++) {
      if (choices[i] != defaultReactions[i]) return false;
    }
    return true;
  }

  Future<void> _swap(
    BuildContext context,
    WidgetRef ref,
    int index,
    List<String> choices,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Replace ${choices[index]}', style: AppText.subtitle()),
              const SizedBox(height: AppSpace.xs),
              Wrap(
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                children: [
                  for (final emoji in reactionPalette)
                    _Candidate(
                      emoji: emoji,
                      // ⚠️ Already on the bar, so it is shown but not
                      // choosable — two identical slots would mean a button
                      // that can never be tapped off. Greyed rather than
                      // hidden, so the palette does not shuffle under the
                      // finger every time a slot changes.
                      taken: choices.contains(emoji) && choices[index] != emoji,
                      selected: choices[index] == emoji,
                      onTap: () => Navigator.pop(sheetContext, emoji),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      await ref.read(reactionChoicesProvider.notifier).replaceAt(index, picked);
    }
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.xs),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceSubtle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}

class _Candidate extends StatelessWidget {
  const _Candidate({
    required this.emoji,
    required this.taken,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool taken;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: taken ? .3 : 1,
      child: InkWell(
        onTap: taken ? null : onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.blush : AppColors.surfaceSubtle,
            border: selected
                ? Border.all(color: AppColors.brand, width: 1.5)
                : null,
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}

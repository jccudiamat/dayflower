import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../tulip/data/flower_repository.dart';
import '../../domain/throwback.dart';

/// A photo from this same day, an earlier year.
///
/// ⚠️ Absent far more often than it is present, and that is the design. It
/// only appears when something really was made on this date before; see
/// [findThrowback] for why the alternative was worse.
class HomeThrowback extends ConsumerWidget {
  const HomeThrowback({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final throwback = ref.watch(throwbackProvider);
    if (throwback == null) return const SizedBox.shrink();

    final message = throwback.message;
    final note = message.note?.trim();

    return Column(
        key: const ValueKey('home-throwback'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(throwback.heading, style: AppText.title()),
          const SizedBox(height: AppSpace.sm),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                side: BorderSide(color: AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(Routes.photos),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.sm),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: SizedBox(
                        width: 78,
                        height: 78,
                        child: _Photo(path: message.imagePath!)),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('This moment', style: AppText.subtitle()),
                        if (note != null && note.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body()),
                        ],
                        const SizedBox(height: AppSpace.xs),
                        Text(
                            DateFormat('d MMM yyyy')
                                .format(message.sentAt.toLocal()),
                            style: AppText.caption()),
                      ])),
                ]),
              ),
            ),
          ),
          // 🔴 The trailing gap belongs to this section, not to the page.
          // With a SizedBox on each side in the list, a day with no throwback
          // stacked both and left 48pt of nothing between the two sections
          // either side of it.
          const SizedBox(height: AppSpace.md),
        ]);
  }
}

/// ⚠️ Same private bucket as everything else: the path is not a URL, so a
/// short-lived signed one is minted at render time.
class _Photo extends ConsumerWidget {
  const _Photo({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget unavailable() => ColoredBox(
          color: AppColors.surfaceSubtle,
          child: const Center(child: AppIcon(CupertinoIcons.photo, size: 20)),
        );

    return ref.watch(dayPhotoUrlProvider(path)).when(
          loading: () => ColoredBox(color: AppColors.surfaceSubtle),
          error: (_, __) => unavailable(),
          data: (url) => url == null
              ? unavailable()
              : Image.network(url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => unavailable()),
        );
  }
}

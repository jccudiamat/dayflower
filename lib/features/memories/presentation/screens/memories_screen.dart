import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/feature_cards.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../chapters/data/chapter_repository.dart';

/// Existing photo and reflection features, using the established hub cards.
class MemoriesScreen extends ConsumerWidget {
  const MemoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unwritten = ref.watch(unwrittenChapterProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
          child: ListView(
        padding: const EdgeInsets.all(AppSpace.sm),
        children: [
          const FeatureScreenHeader(
              title: 'Memories', subtitle: 'The moments you make and keep'),
          const SizedBox(height: AppSpace.sm),
          BoothCard(onTap: () => context.push(Routes.booth)),
          const SizedBox(height: AppSpace.sm),
          FeatureRow(
              emoji: '📷',
              color: AppColors.brand,
              title: 'Shared photos',
              blurb: 'Photos you have sent each other',
              onTap: () => context.push(Routes.photos)),
          const SizedBox(height: AppSpace.xs),
          FeatureRow(
              emoji: '☀️',
              color: AppColors.secondary,
              title: 'My Day photos',
              blurb: 'Your shared daily moments',
              onTap: () => context.push(Routes.myDays)),
          const SizedBox(height: AppSpace.xs),
          FeatureRow(
              emoji: '📖',
              color: AppColors.secondary,
              title: 'Chapters',
              blurb: 'Monthly reflections and shared goals',
              badge: unwritten == null ? null : 'Review due',
              onTap: () => context.push(Routes.chapters)),
        ],
      )),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_icon.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

class BoothCard extends StatelessWidget {
  const BoothCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          gradient: AppGradients.hero,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .15)),
                  ),
                  child: const Text('📸', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Booth & Strip',
                          style: AppText.title(AppColors.onDark)),
                      const SizedBox(height: 2),
                      Text('Photo strips, ten templates',
                          style: AppText.caption(AppColors.onDarkMuted)),
                    ],
                  ),
                ),
                const AppIcon(CupertinoIcons.chevron_forward,
                    size: 15, color: AppColors.onDarkMuted),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text('Pose apart, print together. 🌷',
                style: AppText.note(AppColors.onDarkMuted)),
          ],
        ),
      ),
    );
  }
}

// ── The ones that work ──────────────────────────────

class FeatureRow extends StatelessWidget {
  const FeatureRow({
    super.key,
    required this.emoji,
    required this.color,
    required this.title,
    required this.blurb,
    this.badge,
    required this.onTap,
  });

  final String emoji;
  final Color color;
  final String title;
  final String blurb;

  /// A short status pill — only rendered when there is something the user
  /// should act on, so an empty hub stays quiet.
  final String? badge;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppElevation.card,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.subtitle()),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: AppSpace.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.blush,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(badge!,
                                style: AppText.label(AppColors.brandDark)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(blurb,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption()),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              AppIcon(CupertinoIcons.chevron_forward,
                  size: 14, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

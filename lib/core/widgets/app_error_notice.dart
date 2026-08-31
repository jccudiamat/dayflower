import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// Inline banner for a screen that failed to load part of its data but can
/// still draw the rest of itself.
///
/// Screens built on `valueOrNull ?? const []` render an empty state when a
/// stream errors, which reads as "you have nothing" rather than "this did
/// not load" — the two look identical and mean opposite things. Put this
/// above the content whenever a stream is in an error state.
class AppErrorNotice extends StatelessWidget {
  const AppErrorNotice({
    super.key,
    required this.message,
    this.detail,
  });

  final String message;

  /// The raw exception. Shown small — it is for whoever has to fix it, not
  /// for the person reading the screen.
  final Object? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.dangerSubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.danger.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle,
              size: 16, color: AppColors.danger),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: AppText.body(AppColors.ink)
                        .copyWith(fontWeight: FontWeight.w600)),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text('$detail',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

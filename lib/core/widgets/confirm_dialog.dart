import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';
import 'gradient_button.dart';

/// Confirmation dialog in the house style: title + circled ✕, message,
/// gradient confirm, plain-text escape underneath.
///
/// Resolves true only when the user taps confirm.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Not now',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.sm,
          AppSpace.md,
          AppSpace.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppText.title(),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(
                    CupertinoIcons.xmark,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Text(message, textAlign: TextAlign.center, style: AppText.body()),
            const SizedBox(height: AppSpace.md),
            GradientButton(
              label: confirmLabel,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpace.xxs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel, style: AppText.body(AppColors.muted)),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

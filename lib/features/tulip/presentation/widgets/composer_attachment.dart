import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';

/// One picture waiting on the composer, with a way to take it off again.
class ComposerAttachment extends StatelessWidget {
  const ComposerAttachment({
    super.key,
    required this.bytes,
    required this.index,
    required this.onRemove,
  });

  static const size = 60.0;

  final Uint8List bytes;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: 180,
                semanticLabel: 'Photo ${index + 1}',
                errorBuilder: (_, __, ___) => Container(
                  width: size,
                  height: size,
                  color: AppColors.surface,
                  alignment: Alignment.center,
                  child: AppIcon(CupertinoIcons.photo,
                      size: 18, color: AppColors.muted),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: -4,
            child: Semantics(
              button: true,
              label: 'Remove photo ${index + 1}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceSubtle, width: 2),
                  ),
                  child: AppIcon(CupertinoIcons.xmark,
                      size: 9, color: AppColors.surface),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

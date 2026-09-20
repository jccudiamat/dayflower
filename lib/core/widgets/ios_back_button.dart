import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The one way back, everywhere in the app.
///
/// 🔴 **A bare chevron, with nothing drawn around it.** This used to be a
/// white circle with a border and a card shadow, which made the way out of a
/// screen heavier than anything on it and read as a floating button rather
/// than a back control. Three screens had drifted to Material's
/// `Icons.arrow_back` instead, so the app answered the same question in two
/// different alphabets depending on which corner you were in.
///
/// ⚠️ The white fill and the hardcoded near-black chevron were also a dark
/// mode bug: a white disc survived the theme switch and sat glowing in the
/// corner of every dark screen. Nothing here is a literal colour now.
///
/// ⚠️ The box stays 44×44 even though the mark inside is 18. The chevron is a
/// thin diagonal with almost no area to hit, and shrinking the target to fit
/// the artwork is how a back button becomes something you stab at twice.
class IosBackButton extends StatelessWidget {
  const IosBackButton({super.key, required this.onTap, this.tooltip = 'Back'});

  /// Null disables it: the chevron greys out and stops responding. The
  /// booth needs this while it is mid-save, where leaving would lose photos.
  final VoidCallback? onTap;

  /// Named for screen readers, and for the tests that find it by tooltip.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // The ripple is the only thing that ever appears behind the mark,
          // and only while a finger is down.
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              // ⚠️ Not const: AppColors.ink is a getter that follows the
              // theme, so folding it in at compile time would freeze the
              // chevron on whichever mode happened to build first.
              child: AppIcon(CupertinoIcons.chevron_back,
                  size: 18,
                  color: onTap == null ? AppColors.muted : AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

class IosBackButton extends StatelessWidget {
  const IosBackButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
            boxShadow: AppElevation.card,
          ),
          alignment: Alignment.center,
          child: const Icon(
            CupertinoIcons.chevron_back,
            size: 16,
            color: Color(0xFF1D2333),
          ),
        ),
      ),
    );
  }
}

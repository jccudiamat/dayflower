import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';

/// "Together", and what it is for.
///
/// Title and subtitle only. The bell and the avatar the mockup puts on the
/// right are on Home's top bar already; the tab does without them.
class TogetherHeader extends StatelessWidget {
  const TogetherHeader({super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shrinks rather than truncates: at 200% text on a small phone
          // the one word on the page that must not become "Tog…" is this.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('Together',
                maxLines: 1, softWrap: false, style: TogetherStyle.pageTitle()),
          ),
          const SizedBox(height: AppSpace.xxs),
          Text('Plan, do and look forward together.',
              style: TogetherStyle.pageSubtitle()),
        ],
      );
}

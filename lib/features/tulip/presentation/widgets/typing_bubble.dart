import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/typing_repository.dart';

/// "typing…", at the foot of the conversation.
///
/// Named for where it sits rather than what it reads, because `TypingLine`
/// is already the channel behind it (typing_repository.dart).
///
/// ⚠️ Takes no height when nobody is typing, and animates the gap open
/// rather than shoving the thread up: a line appearing under the last
/// message must not make the message move.
class TypingFooter extends ConsumerWidget {
  const TypingFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typing = ref.watch(partnerTypingProvider).valueOrNull ?? false;
    return AnimatedSize(
      duration: AppMotion.standard,
      curve: AppMotion.easeOut,
      alignment: Alignment.bottomLeft,
      child: typing
          ? const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 16, 8),
              child: Row(children: [_Dots(), SizedBox(width: 8), _Label()]),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label();

  @override
  Widget build(BuildContext context) =>
      Text('typing…', style: AppText.caption(AppColors.muted));
}

/// Three dots that rise in turn. The one part of this that has to move:
/// a still "typing…" reads as a label, and a moving one reads as a person.
class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _run,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Transform.translate(
              // Each a third of a cycle behind the last, so they roll
              // rather than blink together.
              offset: Offset(0, -2.5 * _lift((_run.value + i / 3) % 1)),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One hop: up and down over the first half, still for the second, so
  /// there is a rest between rolls instead of a constant churn.
  static double _lift(double t) =>
      t >= .5 ? 0 : (1 - (4 * t - 1) * (4 * t - 1)).clamp(0.0, 1.0);
}

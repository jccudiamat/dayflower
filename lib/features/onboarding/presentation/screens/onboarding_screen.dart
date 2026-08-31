import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/step_scaffold.dart';
import '../../../../core/widgets/two_tone_heading.dart';
import '../../domain/onboarding_notifier.dart';

/// Profile wizard on the dark canvas: name step → nickname step.
/// One submit at the end (same OnboardingNotifier logic as before).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _petNameController = TextEditingController();
  var _onNicknameStep = false;

  @override
  void dispose() {
    _nameController.dispose();
    _petNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref.read(onboardingNotifierProvider.notifier).submit(
          name: _nameController.text,
          petName: _petNameController.text,
        );
    if (ok && mounted) context.go(Routes.pair);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingNotifierProvider);

    if (!_onNicknameStep) {
      return StepScaffold(
        heading: const TwoToneHeading(
          lead: "What's your First",
          accent: 'Name?',
          dark: true,
        ),
        caption: "This is how it'll appear to your partner.",
        progress: 0.5,
        ctaLabel: 'Next',
        onCta: () {
          if (_nameController.text.trim().isEmpty) return;
          setState(() => _onNicknameStep = true);
        },
        child: DarkField(
          controller: _nameController,
          hint: 'Enter your first name',
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) {
            if (_nameController.text.trim().isNotEmpty) {
              setState(() => _onNicknameStep = true);
            }
          },
        ),
      );
    }

    return StepScaffold(
      heading: const TwoToneHeading(
        lead: 'What should they',
        accent: 'call you?',
        dark: true,
      ),
      caption: 'A nickname, if you have one. Optional.',
      progress: 0.7,
      ctaLabel: 'Continue',
      ctaLoading: state.isLoading,
      onCta: _submit,
      onBack: () => setState(() => _onNicknameStep = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DarkField(
            controller: _petNameController,
            hint: 'e.g. Sunshine',
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _submit(),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              state.errorMessage!,
              style: AppText.caption(AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

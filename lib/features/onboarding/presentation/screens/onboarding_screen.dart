import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/step_scaffold.dart';
import '../../../../core/widgets/two_tone_heading.dart';
import '../../domain/onboarding_notifier.dart';

/// Profile wizard on the dark canvas: name → nickname → birthday.
/// One submit at the end (same OnboardingNotifier logic as before).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _petNameController = TextEditingController();
  var _step = _Step.name;
  DateTime? _birthday;

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
          birthday: _birthday,
        );
    if (ok && mounted) context.go(Routes.pair);
  }

  /// WARNING: opens 25 years back, not on today. A picker starting in 2026
  /// makes somebody born in 1998 scroll through 28 years to answer a
  /// question they were just told was optional - which is how an optional
  /// question becomes a skipped one.
  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Your birthday',
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingNotifierProvider);

    if (_step == _Step.name) {
      return StepScaffold(
        heading: const TwoToneHeading(
          lead: "What's your First",
          accent: 'Name?',
          dark: true,
        ),
        caption: "This is how it'll appear to your partner.",
        progress: 0.4,
        ctaLabel: 'Next',
        onCta: () {
          if (_nameController.text.trim().isEmpty) return;
          setState(() => _step = _Step.nickname);
        },
        child: DarkField(
          controller: _nameController,
          hint: 'Enter your first name',
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) {
            if (_nameController.text.trim().isNotEmpty) {
              setState(() => _step = _Step.nickname);
            }
          },
        ),
      );
    }

    if (_step == _Step.birthday) return _birthdayStep(state);

    return StepScaffold(
      heading: const TwoToneHeading(
        lead: 'What should they',
        accent: 'call you?',
        dark: true,
      ),
      caption: 'A nickname, if you have one. Optional.',
      progress: 0.6,
      ctaLabel: 'Next',
      onCta: () => setState(() => _step = _Step.birthday),
      onBack: () => setState(() => _step = _Step.name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DarkField(
            controller: _petNameController,
            hint: 'e.g. Sunshine',
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => setState(() => _step = _Step.birthday),
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

  /// The birthday step.
  ///
  /// WARNING: optional, and the button says so. With nothing picked the CTA
  /// reads "Skip for now" and goes straight on - no greyed-out button, no
  /// second "skip" link to hunt for. Asked here because a birthday given at
  /// sign-up lands on Events by itself, and because the alternative is
  /// finding out in November that nobody ever filled it in.
  Widget _birthdayStep(OnboardingState state) {
    final chosen = _birthday;
    return StepScaffold(
      heading: const TwoToneHeading(
        lead: 'When is your',
        accent: 'birthday?',
        dark: true,
      ),
      caption: "Optional. If you add it, it'll show up on your Events.",
      progress: 0.8,
      ctaLabel: chosen == null ? 'Skip for now' : 'Continue',
      ctaLoading: state.isLoading,
      onCta: _submit,
      onBack: () => setState(() => _step = _Step.nickname),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shaped like DarkField so the three steps read as one form, even
          // though this one opens a picker rather than a keyboard.
          GestureDetector(
            onTap: _pickBirthday,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: 17,
              ),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: chosen == null
                      ? AppColors.darkBorder
                      : AppColors.secondary,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      chosen == null
                          ? 'Pick a date'
                          : DateFormat('MMMM d, yyyy').format(chosen),
                      style: AppText.body(
                        chosen == null
                            ? AppColors.onDarkMuted
                            : AppColors.onDark,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: AppColors.onDarkMuted,
                  ),
                ],
              ),
            ),
          ),
          if (chosen != null) ...[
            const SizedBox(height: AppSpace.xs),
            GestureDetector(
              onTap: () => setState(() => _birthday = null),
              child: Text(
                'Remove',
                style: AppText.caption(AppColors.onDarkMuted),
              ),
            ),
          ],
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

enum _Step { name, nickname, birthday }

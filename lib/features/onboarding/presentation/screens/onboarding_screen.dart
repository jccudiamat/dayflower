import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/models/avatar_character.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/step_scaffold.dart';
import '../../../../core/widgets/character_avatar.dart';
import '../../../../core/widgets/two_tone_heading.dart';
import '../../domain/onboarding_notifier.dart';

/// Profile wizard on the dark canvas: name → nickname → birthday → which
/// one is you. One submit at the end (same OnboardingNotifier logic).
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
  AvatarCharacter? _character;

  /// Tapped by them, rather than picked for them by their gender: once
  /// they have chosen a picture, their gender no longer changes it.
  bool _characterChosen = false;

  /// What `users.gender` gets. Null for "prefer not to say" and for no
  /// answer, which are the same thing to the app.
  _Gender? _gender;

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
          character: _character,
          gender: _gender?.stored,
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
        progress: 0.3,
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
    if (_step == _Step.avatar) return _avatarStep(state);

    return StepScaffold(
      heading: const TwoToneHeading(
        lead: 'What should they',
        accent: 'call you?',
        dark: true,
      ),
      caption: 'A nickname, if you have one. Optional.',
      progress: 0.5,
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
      progress: 0.7,
      ctaLabel: chosen == null ? 'Skip for now' : 'Continue',
      onCta: () => setState(() => _step = _Step.avatar),
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
                  const AppIcon(
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

  /// "Which one is you?" The drawn boy or girl that stands in for them
  /// until they add a photo, and the last step.
  ///
  /// ⚠️ Asked, never guessed: the app knows nothing about who is which, and
  /// a guess from a name is wrong often enough to sting. One tap, and it
  /// can be changed (or replaced by a photo) in Settings.
  Widget _avatarStep(OnboardingState state) {
    return StepScaffold(
      heading: const TwoToneHeading(
        lead: 'Which one',
        accent: 'is you?',
        dark: true,
      ),
      caption: 'Your picture until you add a photo. '
          'You can change it in Settings anytime.',
      progress: 0.9,
      ctaLabel: 'Continue',
      ctaLoading: state.isLoading,
      // Disabled until one is picked: it is one tap, and it is the picture
      // their partner sees.
      onCta: _character == null ? null : _submit,
      onBack: () => setState(() => _step = _Step.birthday),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final c in AvatarCharacter.values)
                _CharacterChoice(
                  character: c,
                  selected: _character == c,
                  onTap: () => setState(() {
                    _character = c;
                    _characterChosen = true;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Text('YOUR GENDER',
              style: AppText.label(AppColors.onDarkMuted)),
          const SizedBox(height: AppSpace.xs),
          // Optional, like the birthday: it only ever picks defaults. A
          // choice of Man or Woman picks the matching picture too, until
          // they pick one themselves.
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              for (final g in _Gender.values)
                _GenderChip(
                  gender: g,
                  selected: _gender == g,
                  onTap: () => setState(() {
                    _gender = _gender == g ? null : g;
                    final match = _gender?.character;
                    if (!_characterChosen && match != null) {
                      _character = match;
                    }
                  }),
                ),
            ],
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpace.sm),
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

/// One of the two, big, ringed when chosen.
class _CharacterChoice extends StatelessWidget {
  const _CharacterChoice({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  final AvatarCharacter character;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: character.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.micro,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.secondary : AppColors.darkBorder,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: AnimatedOpacity(
            duration: AppMotion.micro,
            opacity: selected ? 1 : .75,
            child: CharacterAvatar(character: character, size: 124),
          ),
        ),
      ),
    );
  }
}

/// One answer to "your gender", as a pill.
class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.gender,
    required this.selected,
    required this.onTap,
  });

  final _Gender gender;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: gender.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.micro,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.secondary.withValues(alpha: .18)
                : AppColors.darkSurface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.secondary : AppColors.darkBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(gender.label,
              style: AppText.body(
                  selected ? AppColors.onDark : AppColors.onDarkMuted)),
        ),
      ),
    );
  }
}

/// The answers to "your gender", and what each stores. The stored words
/// are the ones AvatarFlower.defaultFor already reads.
enum _Gender {
  man('Man', 'male', AvatarCharacter.boy),
  woman('Woman', 'female', AvatarCharacter.girl),
  nonBinary('Non-binary', 'nonbinary', null),
  undisclosed('Prefer not to say', null, null);

  const _Gender(this.label, this.stored, this.character);

  final String label;

  /// What `users.gender` gets.
  final String? stored;

  /// The picture it suggests, if any.
  final AvatarCharacter? character;
}

enum _Step { name, nickname, birthday, avatar }

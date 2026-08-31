import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/step_scaffold.dart';
import '../../../../core/widgets/two_tone_heading.dart';
import '../../data/pair_repository.dart';
import '../../domain/pairing_notifier.dart';

/// Final wizard step on the dark canvas: share your code / enter theirs.
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    final ok = await ref
        .read(pairingNotifierProvider.notifier)
        .submitCode(_codeController.text);
    if (ok && mounted) _goToNest();
  }

  void _goToNest() {
    ref.invalidate(currentPairProvider);
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pairingNotifierProvider);

    ref.listen<PairingState>(pairingNotifierProvider, (_, next) {
      if (next.isLinked) _goToNest();
    });

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.darkCanvas,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StepScaffold(
      heading: const TwoToneHeading(
        lead: 'Connect with your',
        accent: 'person',
        dark: true,
      ),
      caption: 'Share your code with them, or enter theirs below.',
      progress: 0.9,
      ctaLabel: 'Connect',
      ctaLoading: state.isSubmittingCode,
      onCta: _submitCode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MyCodeCard(code: state.myInvite?.inviteCode ?? '——————'),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.darkBorder)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child:
                    Text('or', style: AppText.caption(AppColors.onDarkMuted)),
              ),
              const Expanded(child: Divider(color: AppColors.darkBorder)),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text("PARTNER'S CODE", style: AppText.label(AppColors.onDarkMuted)),
          const SizedBox(height: 6),
          DarkField(
            controller: _codeController,
            hint: 'ABC123',
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(6),
            ],
            style: AppText.subtitle(AppColors.onDark)
                .copyWith(letterSpacing: 4),
            onSubmitted: (_) => _submitCode(),
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

class _MyCodeCard extends StatefulWidget {
  const _MyCodeCard({required this.code});
  final String code;

  @override
  State<_MyCodeCard> createState() => _MyCodeCardState();
}

class _MyCodeCardState extends State<_MyCodeCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpace.md,
        horizontal: AppSpace.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Text('YOUR CODE', style: AppText.label(AppColors.onDarkMuted)),
          const SizedBox(height: 10),
          ShaderMask(
            shaderCallback: (b) => AppGradients.cta.createShader(b),
            child: Text(
              widget.code,
              style: AppText.stat(Colors.white).copyWith(
                fontSize: 38,
                letterSpacing: 8,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          GestureDetector(
            onTap: _copy,
            child: AnimatedContainer(
              duration: AppMotion.micro,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: AppSpace.xs,
              ),
              decoration: BoxDecoration(
                color: _copied
                    ? AppColors.success.withValues(alpha: .22)
                    : AppColors.darkRaised,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Text(
                _copied ? 'Copied' : 'Copy code',
                style: AppText.caption(AppColors.onDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

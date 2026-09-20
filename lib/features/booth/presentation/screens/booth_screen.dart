import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/strip_repository.dart';
import '../../domain/booth_design.dart';
import '../widgets/booth_visuals.dart';
import 'booth_archive_screen.dart';
import 'booth_studio_screen.dart';
import '../../../../core/widgets/ios_back_button.dart';
export 'booth_archive_screen.dart'
    show boothPhotoPickerProvider, normalizeBoothPhoto;

class BoothScreen extends ConsumerWidget {
  const BoothScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(openStripsProvider);
    final user = ref.watch(currentUserIdProvider);
    void enter([PhotoStrip? joining]) =>
        Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => BoothStudioScreen(joining: joining)));
    void archive() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const BoothArchiveScreen()));
    return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
            child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(children: [
              IosBackButton(
                  tooltip: 'Back to Dayflower',
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.dayflower)),
              const Spacer(),
              TextButton(
                  onPressed: archive,
                  child: const Text('Saved & waiting strips'))
            ]),
            const SizedBox(height: 18),
            Text('Booth & Strip',
                style: AppText.hero(), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text('Step in. Strike a pose. Keep the moment.',
                style: AppText.body(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            BoothPortal(onEnter: enter),
            const SizedBox(height: 16),
            Text('Solo or together · 3, 2, 1 · A strip to keep',
                style: AppText.caption(), textAlign: TextAlign.center),
            if (waiting.hasError)
              TextButton(
                  onPressed: () => ref.invalidate(openStripsProvider),
                  child: const Text('Could not load invitations. Retry')),
            for (final invite in waiting.valueOrNull ?? <PhotoStrip>[]) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                  icon: const Icon(Icons.mail_outline),
                  onPressed: invite.aUser != user &&
                          invite.bPath == null &&
                          BoothDesign.parse(invite.template) != null
                      ? () => enter(invite)
                      : archive,
                  label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(invite.isFullButUnposted
                          ? 'Finish your saved strip'
                          : invite.aUser == user
                              ? 'Your strip is waiting for your partner'
                              : 'Your partner left you a place in the booth'))),
            ],
          ],
        )));
  }
}

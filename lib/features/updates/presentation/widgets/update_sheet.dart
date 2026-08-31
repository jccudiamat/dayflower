import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_cta_button.dart';
import '../../data/update_repository.dart';

/// Guards against a second sheet stacking on the first — the launch check and
/// a resume check can both land on `available` while the sheet is already up.
bool _isOpen = false;

/// Shows the update sheet, unless one is already showing.
///
/// A mandatory update can't be swiped away or dismissed with the back button;
/// an optional one behaves like every other sheet in the app.
Future<void> showUpdateSheet(BuildContext context, {required bool mandatory}) {
  if (_isOpen) return Future.value();
  _isOpen = true;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: !mandatory,
    enableDrag: !mandatory,
    backgroundColor: Colors.transparent,
    builder: (_) => PopScope(
      canPop: !mandatory,
      child: const UpdateSheet(),
    ),
  ).whenComplete(() => _isOpen = false);
}

class UpdateSheet extends ConsumerWidget {
  const UpdateSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    final controller = ref.read(updateControllerProvider.notifier);
    final release = state.release;

    // The sheet only ever opens with a release in hand; this is the moment
    // after "Not now" clears it, one frame before the pop lands.
    if (release == null) return const SizedBox.shrink();

    return AppBottomSheet(
      title: state.mandatory ? 'Required update' : 'Update available',
      subtitle: [
        'Version ${release.versionName} · build ${release.buildNumber}',
        if (release.readableSize.isNotEmpty) release.readableSize,
      ].join(' · '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (release.notes.isNotEmpty) ...[
            for (final note in release.notes) _NoteLine(note),
            const SizedBox(height: AppSpace.sm),
          ],

          if (state.stage == UpdateStage.downloading) ...[
            _DownloadProgress(state: state),
            const SizedBox(height: AppSpace.md),
          ],

          if (state.error != null) ...[
            _ErrorNote(state.error!),
            const SizedBox(height: AppSpace.sm),
          ],

          _PrimaryAction(state: state, controller: controller),

          // A mandatory update has no way out on purpose, so it gets no
          // dismissal affordance either.
          if (!state.mandatory && !state.busy) ...[
            const SizedBox(height: AppSpace.xs),
            TextButton(
              onPressed: () {
                // Close first: `skip` clears the release this sheet is built
                // from, and rebuilding on null before the pop lands is what
                // makes the sheet flash empty on its way out.
                Navigator.pop(context);
                controller.skip();
              },
              child: Text(
                'Not now',
                style: AppText.body(AppColors.muted)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],

          if (state.stage == UpdateStage.ready) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              'Android will ask you to confirm. The first time, it also asks '
              'you to allow installs from Dayflower.',
              style: AppText.caption(),
            ),
          ],
        ],
      ),
    );
  }
}

/* ── Pieces ─────────────────────────────────────────────────── */

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.state, required this.controller});

  final UpdateState state;
  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    switch (state.stage) {
      case UpdateStage.downloading:
        final percent = state.progress;
        return AppCtaButton(
          label: percent == null
              ? 'Downloading…'
              : 'Downloading ${(percent * 100).round()}%',
          // Null disables the button, which is also what greys the gradient.
          onPressed: null,
        );

      case UpdateStage.ready:
        return AppCtaButton(
          label: 'Install now',
          icon: CupertinoIcons.checkmark_seal,
          onPressed: controller.install,
        );

      case UpdateStage.failed:
        return AppCtaButton(
          label: 'Try again',
          icon: CupertinoIcons.arrow_clockwise,
          onPressed: () {
            controller.reset();
            controller.download();
          },
        );

      default:
        return AppCtaButton(
          label: 'Update now',
          icon: CupertinoIcons.arrow_down_circle,
          onPressed: controller.download,
        );
    }
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.state});

  final UpdateState state;

  static String _mb(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.surfaceSubtle,
            valueColor: const AlwaysStoppedAnimation(AppColors.brand),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          state.total > 0
              ? '${_mb(state.received)} of ${_mb(state.total)}'
              : _mb(state.received),
          style: AppText.caption(),
        ),
      ],
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: AppSpace.xs),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text, style: AppText.body())),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(
        color: AppColors.dangerSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(message, style: AppText.caption(AppColors.danger)),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/services/pulse_alerts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/models/avatar_flower.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/flower_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/timezone_picker.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../heartbeat/data/pulse_alert_prefs.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../../updates/data/update_repository.dart';
import '../../../updates/presentation/widgets/update_sheet.dart';
import '../../../widget/widget_mode_provider.dart';
import '../../../widget/widget_sync.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final pair = ref.watch(currentPairProvider).valueOrNull;
    final email = ref.watch(supabaseClientProvider).auth.currentUser?.email;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.home),
          icon: const Icon(CupertinoIcons.chevron_back, color: AppColors.muted),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, AppSpace.xs, 20, AppSpace.lg),
          children: [
            _ProfileHeader(
              name: profile?.displayName ?? '—',
              petName: profile?.petName,
              flower: profile?.flower,
              email: email,
            ),
            const SizedBox(height: AppSpace.md),

            // ── Profile ──────────────────────────────
            Text('YOUR PROFILE', style: AppText.label()),
            const SizedBox(height: AppSpace.xs),
            _Card(
              children: [
                _Row(
                  title: 'Name',
                  value: profile?.displayName,
                  onTap: () => _editText(
                    context,
                    ref,
                    title: 'Your name',
                    hint: 'e.g. Jessie',
                    initial: profile?.displayName ?? '',
                    onSave: (v) async {
                      final id = ref.read(currentUserIdProvider);
                      if (id == null) return;
                      await ref
                          .read(userRepositoryProvider)
                          .updateProfile(id, displayName: v);
                      ref.invalidate(userProfileProvider);
                    },
                  ),
                ),
                const _Line(),
                _Row(
                  title: 'Your flower',
                  value: profile == null
                      ? '—'
                      : '${profile.flower.emoji}  ${profile.flower.label}',
                  onTap: () => _pickAvatar(context, ref, profile),
                ),
                const _Line(),
                _Row(
                  title: 'Nickname',
                  value: profile?.petName ?? 'Not set',
                  onTap: () => _editText(
                    context,
                    ref,
                    title: 'Your nickname',
                    hint: 'What should they call you?',
                    initial: profile?.petName ?? '',
                    allowEmpty: true,
                    onSave: (v) async {
                      final id = ref.read(currentUserIdProvider);
                      if (id == null) return;
                      await ref
                          .read(userRepositoryProvider)
                          .updateProfile(id, petName: v);
                      ref.invalidate(userProfileProvider);
                    },
                  ),
                ),
                const _Line(),
                _Row(
                  title: 'Timezone',
                  value: zoneCity(profile?.timezone ?? 'UTC'),
                  onTap: () async {
                    final zone = await showTimezonePicker(context);
                    if (zone == null) return;
                    final id = ref.read(currentUserIdProvider);
                    if (id == null) return;
                    await ref
                        .read(userRepositoryProvider)
                        .updateTimezone(id, zone);
                    ref.invalidate(userProfileProvider);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),

            // ── Pair ─────────────────────────────────
            Text('YOUR PAIR', style: AppText.label()),
            const SizedBox(height: AppSpace.xs),
            _Card(
              children: [
                _Row(
                  title: 'Connected with',
                  value: partner?.petName ?? partner?.displayName ?? '—',
                  chevron: false,
                ),
                const _Line(),
                _Row(
                  title: 'Invite code',
                  value: pair?.inviteCode ?? '—',
                  chevron: false,
                  onTap: pair == null
                      ? null
                      : () {
                          Clipboard.setData(
                            ClipboardData(text: pair.inviteCode),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied')),
                          );
                        },
                ),
                const _Line(),
                _Row(
                  title: 'Disconnect partner',
                  subtitle: 'Unlinks your accounts and erases shared history',
                  danger: true,
                  onTap: pair == null
                      ? null
                      : () => _disconnect(context, ref, pair.id),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),

            // ── Alerts ───────────────────────────────
            Text('ALERTS', style: AppText.label()),
            const SizedBox(height: AppSpace.xs),
            _Card(
              children: [
                _SwitchRow(
                  title: 'Heartbeat alerts',
                  subtitle: PulseAlerts.supported
                      ? 'Vibrate and play a heartbeat when they send a pulse'
                      : 'Only available on the Android and iOS app',
                  value: ref.watch(pulseAlertSettingsProvider).enabled,
                  onChanged: PulseAlerts.supported
                      ? (v) => ref
                          .read(pulseAlertSettingsProvider.notifier)
                          .setEnabled(v)
                      : null,
                ),
                const _Line(),
                _Row(
                  title: 'Interrupt me',
                  subtitle:
                      'Extra pulses inside this window update the notification '
                      'quietly instead of buzzing again',
                  value: ref.watch(pulseAlertSettingsProvider).cadence.label,
                  onTap: ref.watch(pulseAlertSettingsProvider).enabled &&
                          PulseAlerts.supported
                      ? () => _pickCadence(context, ref)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),

            // ── Home screen widget ───────────────────
            Text('HOME SCREEN WIDGET', style: AppText.label()),
            const SizedBox(height: AppSpace.xs),
            Text(
              DayflowerWidgets.isSupported
                  ? 'Long-press your home screen → Widgets → Dayflower. "Today\'s Flower" and "Heartbeat" can be placed on their own; the plain "Dayflower" widget shows whichever you pick here.'
                  : 'Home screen widgets are only available on the Android and iOS app.',
              style: AppText.caption(),
            ),
            const SizedBox(height: AppSpace.xs),
            _Card(
              children: [
                _WidgetModeRow(
                  title: "Today's Flower",
                  subtitle: 'Their flower and note',
                  mode: WidgetMode.flower,
                ),
                const _Line(),
                _WidgetModeRow(
                  title: 'Heartbeat',
                  subtitle: 'Tap it to send a pulse',
                  mode: WidgetMode.heartbeat,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),

            // ── About ────────────────────────────────
            Text('ABOUT', style: AppText.label()),
            const SizedBox(height: AppSpace.xs),
            _Card(
              children: [
                const _VersionRow(),
                if (UpdateRepository.supported) ...[
                  const _Line(),
                  const _CheckForUpdatesRow(),
                ],
                const _Line(),
                _Row(
                  title: 'Terms of Service',
                  onTap: () => _showLegalNote(context),
                ),
                const _Line(),
                _Row(
                  title: 'Privacy Policy',
                  onTap: () => _showLegalNote(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),

            GradientButton(
              label: 'Sign out',
              onPressed: () => _signOut(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: "You'll need your email and password to get back in.",
      confirmLabel: 'Yes, sign out',
    );
    if (!ok) return;
    // Router redirect reacts to the auth stream and returns to Welcome.
    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> _disconnect(
    BuildContext context,
    WidgetRef ref,
    String pairId,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Disconnect?',
      message:
          'Every flower, note, heartbeat and your reunion countdown will be '
          'permanently deleted for both of you. This cannot be undone.',
      confirmLabel: 'Disconnect and delete',
      cancelLabel: 'Keep us connected',
    );
    if (!ok) return;

    await ref.read(pairRepositoryProvider).disconnect(pairId);
    ref.invalidate(currentPairProvider);
    // Gate chain sends the user back to pairing.
  }

  Future<void> _pickCadence(BuildContext context, WidgetRef ref) async {
    final current = ref.read(pulseAlertSettingsProvider).cadence;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                AppSpace.md,
                20,
                AppSpace.xs,
              ),
              child: Text('Interrupt me', style: AppText.title()),
            ),
            for (final cadence in PulseCadence.values)
              _Row(
                title: cadence.label,
                chevron: false,
                value: cadence == current ? '✓' : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref
                      .read(pulseAlertSettingsProvider.notifier)
                      .setCadence(cadence);
                },
              ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }

  void _showLegalNote(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opens at dayflower.app once the site is live'),
      ),
    );
  }

  Future<void> _editText(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String hint,
    required String initial,
    required Future<void> Function(String) onSave,
    bool allowEmpty = false,
  }) async {
    final controller = TextEditingController(text: initial);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: AppSpace.md,
          bottom:
              MediaQuery.of(sheetContext).viewInsets.bottom + AppSpace.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: AppText.title())),
                IconButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(
                    CupertinoIcons.xmark,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: hint),
            ),
            const SizedBox(height: AppSpace.sm),
            GradientButton(
              label: 'Save',
              onPressed: () async {
                final value = controller.text;
                if (!allowEmpty && value.trim().isEmpty) return;
                Navigator.of(sheetContext).pop();
                await onSave(value);
              },
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}

/* ── Profile header ──────────────────────────────── */
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.petName,
    required this.email,
    this.flower,
  });

  final String name;
  final String? petName;
  final String? email;

  /// Your avatar flower. Null only while the profile is still loading.
  final AvatarFlower? flower;

  @override
  Widget build(BuildContext context) {

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              gradient: AppGradients.cta,
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Text(
                (flower ?? AvatarFlower.fallback).emoji,
                style: const TextStyle(fontSize: 32),
                semanticsLabel: (flower ?? AvatarFlower.fallback).label,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            petName == null || petName!.isEmpty ? name : '$name · $petName',
            style: AppText.subtitle(),
          ),
          if (email != null) ...[
            const SizedBox(height: 2),
            Text(email!, style: AppText.caption()),
          ],
        ],
      ),
    );
  }
}

/* ── Grouped card ────────────────────────────────── */
class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpace.sm),
      child: Divider(height: 1),
    );
  }
}

/* ── Adaptive-widget mode picker row ─────────────── */
class _WidgetModeRow extends ConsumerWidget {
  const _WidgetModeRow({
    required this.title,
    required this.subtitle,
    required this.mode,
  });

  final String title;
  final String subtitle;
  final WidgetMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(widgetModeProvider) == mode;
    final enabled = DayflowerWidgets.isSupported;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () => ref.read(widgetModeProvider.notifier).setMode(mode)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: 14,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.body(
                        enabled ? AppColors.ink : AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppText.caption()),
                  ],
                ),
              ),
              // Selection reads as an outline, per design.md.
              AnimatedContainer(
                duration: AppMotion.micro,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected && enabled
                        ? AppColors.secondary
                        : AppColors.border,
                    width: selected && enabled ? 6 : 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ── Settings row with a switch ──────────────────── */
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpace.sm,
        right: AppSpace.xs,
        top: 10,
        bottom: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.body(AppColors.ink)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.caption()),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.brand,
          ),
        ],
      ),
    );
  }
}

/* ── Settings row ────────────────────────────────── */
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.chevron = true,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool chevron;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final titleColor = danger ? AppColors.danger : AppColors.ink;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: 14,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.body(titleColor)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppText.caption()),
                    ],
                  ],
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: AppText.caption(AppColors.body),
                ),
              if (chevron && onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  CupertinoIcons.chevron_forward,
                  size: 20,
                  color: AppColors.muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/* ── About: version + manual update check ────────── */

/// The build actually installed, not a constant in the source. Once the
/// build number is what decides whether an update exists, showing anything
/// else here would be showing a number that can lie.
class _VersionRow extends ConsumerWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Row(
      title: 'Version',
      value: ref.watch(installedVersionProvider).valueOrNull ?? '—',
      chevron: false,
    );
  }
}

/// Forces a check now, ignoring both the resume throttle and any build the
/// user has already said "Not now" to. A found update opens the sheet via
/// the listener in app.dart, so this row only has to speak up when there is
/// nothing to show.
class _CheckForUpdatesRow extends ConsumerWidget {
  const _CheckForUpdatesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);

    return _Row(
      title: 'Check for updates',
      subtitle: switch (state.stage) {
        UpdateStage.checking => 'Checking…',
        UpdateStage.downloading => 'Downloading…',
        UpdateStage.ready => 'Downloaded — tap to install',
        UpdateStage.available =>
          'Build ${state.release?.buildNumber} is available',
        _ => null,
      },
      onTap: state.busy ? null : () => _check(context, ref),
    );
  }

  Future<void> _check(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    // A build already found — or already downloaded and waiting to install —
    // needs the sheet back, not another manifest fetch. `check` deliberately
    // refuses to run over a downloaded APK, so without this the row would
    // look tappable and do nothing.
    final current = ref.read(updateControllerProvider);
    if (current.release != null &&
        (current.stage == UpdateStage.available ||
            current.stage == UpdateStage.ready ||
            current.stage == UpdateStage.failed)) {
      return showUpdateSheet(context, mandatory: current.mandatory);
    }

    await ref.read(updateControllerProvider.notifier).check(manual: true);

    final state = ref.read(updateControllerProvider);
    switch (state.stage) {
      case UpdateStage.upToDate:
        messenger.showSnackBar(
          const SnackBar(content: Text("You're on the latest build 🌷")),
        );
      case UpdateStage.failed:
        messenger.showSnackBar(
          SnackBar(content: Text(state.error ?? 'Update check failed')),
        );
      default:
        // `available` already opened the sheet; nothing to add.
        break;
    }
  }
}

/// Your avatar flower.
///
/// Everyone sees the same eight; the daisy/tulip split only ever decides the
/// *default* for someone who has never picked, so choosing here is free of
/// any of that.
Future<void> _pickAvatar(
  BuildContext context,
  WidgetRef ref,
  UserProfile? profile,
) async {
  final current = profile?.flower ?? AvatarFlower.fallback;
  final chosen = await showModalBottomSheet<AvatarFlower>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md,
          AppSpace.lg + MediaQuery.paddingOf(sheetContext).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text('Your flower', style: AppText.hero()),
          const SizedBox(height: 4),
          Text('It stands in for you everywhere — the chat, their home screen.',
              style: AppText.caption()),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final f in AvatarFlower.values)
                GestureDetector(
                  onTap: () => Navigator.pop(sheetContext, f),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // design.md: selection is a tinted outline.
                          border: Border.all(
                            color: f == current
                                ? AppColors.brand
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: FlowerAvatar(flower: f, size: 52),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 62,
                        child: Text(
                          f.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppText.label(
                            f == current ? AppColors.brand : AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  if (chosen == null) return;
  final id = ref.read(currentUserIdProvider);
  if (id == null) return;
  await ref.read(userRepositoryProvider).updateProfile(id, avatar: chosen);
  ref.invalidate(userProfileProvider);
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/services/pulse_alerts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/models/avatar_flower.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/services/avatar_image.dart';
import '../../../../core/widgets/flower_avatar.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/city_picker.dart';
import '../../../../core/widgets/timezone_picker.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../heartbeat/data/pulse_alert_prefs.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../../updates/data/update_repository.dart';
import '../../../push/data/push_repository.dart';
import '../../../push/data/push_service.dart';
import '../../../updates/presentation/widgets/update_screen.dart';
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
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
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
              profile: profile,
              email: email,
              onTapAvatar: () => _pickAvatar(context, ref, profile),
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
                // ⚠️ No "Your picture" row. The picture is at the top of
                // this screen, at 66px, with a camera badge on it — a text
                // row underneath saying the word "Photo" was describing
                // something already on screen and better tapped directly.
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
                  title: 'Birthday',
                  value: profile?.birthday == null
                      ? 'Not set'
                      : DateFormat('MMMM d').format(profile!.birthday!),
                  onTap: () => _editBirthday(context, ref, profile),
                ),
                const _Line(),
                // Where they are, which is the distance — see migration
                // 0034 for why this is not the timezone.
                _Row(
                  title: 'Where you are',
                  subtitle: 'Sets the distance between you',
                  value: profile?.city?.split(',').first.trim() ?? 'Not set',
                  onTap: () async {
                    final city = await showCityPicker(context);
                    if (city == null) return;
                    final id = ref.read(currentUserIdProvider);
                    if (id == null) return;
                    await ref.read(userRepositoryProvider).updatePlace(
                          id,
                          city: city.label,
                          latitude: city.latitude,
                          longitude: city.longitude,
                          timezone: city.timezone,
                        );
                    ref.invalidate(userProfileProvider);
                  },
                ),
                const _Line(),
                _Row(
                  title: 'Timezone',
                  // Picking a city sets this too. It stays its own row for
                  // the one case where they genuinely differ: someone away
                  // from home, whose clock has moved and whose city has not.
                  subtitle: 'For the clocks. Usually set by your city',
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
                // One switch, and deliberately only one. The row under
                // here used to pick how long a heartbeat had to wait before
                // another was allowed to buzz — a window on a gesture that
                // is already the smallest thing you can send someone.
                _SwitchRow(
                  title: 'Heartbeat alerts',
                  subtitle: PulseAlerts.supported
                      ? 'Vibrate and play a heartbeat every time they send one'
                      : 'Only available on the Android and iOS app',
                  value: ref.watch(pulseAlertsEnabledProvider),
                  onChanged: PulseAlerts.supported
                      ? (v) => ref
                          .read(pulseAlertsEnabledProvider.notifier)
                          .setEnabled(v)
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
                  ? 'Long-press your home screen → Widgets → Dayflower. "Today\'s Flower", "Heartbeat" and "Reunion" can be placed on their own; the plain "Dayflower" widget shows whichever you pick here.'
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
                const _Line(),
                const _WidgetModeRow(
                  title: 'Reunion',
                  subtitle: 'Days until you are in the same place',
                  mode: WidgetMode.reunion,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Text('REUNION WIDGET', style: AppText.label()),
            const SizedBox(height: AppSpace.xs),
            Text(
              'The picture behind the countdown. Somewhere you are going, or '
              'somewhere you have been.',
              style: AppText.caption(),
            ),
            const SizedBox(height: AppSpace.xs),
            const _Card(children: [_ReunionBackgroundRow()]),
            const SizedBox(height: AppSpace.md),
            Text('PHOTO ROTATION', style: AppText.label()),
            const SizedBox(height: AppSpace.xs),
            Text(
              'How often the widget moves to their next day. Only applies '
              'when more than one is live.',
              style: AppText.caption(),
            ),
            const SizedBox(height: AppSpace.xs),
            const _Card(
              children: [
                // ⚠️ "Don't" is first and is the default. A card that moves
                // on its own is the kind of thing that reads as delightful
                // for a week and restless after that, so it is opt-in.
                _WidgetRotationRow(
                  title: "Don't rotate",
                  subtitle: 'Only the newest day',
                  seconds: 0,
                ),
                _Line(),
                _WidgetRotationRow(
                  title: 'Every 3 seconds',
                  subtitle: 'Through their live days',
                  seconds: 3,
                ),
                _Line(),
                _WidgetRotationRow(
                  title: 'Every 5 seconds',
                  subtitle: 'A calmer pace',
                  seconds: 5,
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
    // ⚠️ **Before** the sign-out, not after. Deleting the row needs the
    // session that owns it — device_tokens is RLS'd to auth.uid() — so a
    // token dropped afterwards is a token left behind, still delivering this
    // person's messages to a phone somebody else may sign into next.
    await PushService.forget(ref.read(pushRepositoryProvider));
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
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TextEditSheet(
        title: title,
        hint: hint,
        initial: initial,
        onSave: onSave,
        allowEmpty: allowEmpty,
      ),
    );
  }
}

/// One field, a Save, and a close — the shape every text row in Settings
/// opens into.
///
/// 🔴 **Stateful so it owns its own [TextEditingController].** This used to
/// be a closure with the controller created beside `showModalBottomSheet`
/// and disposed on the line after the `await` — which looks right and is
/// not: that future completes the moment `pop` is *called*, while the sheet
/// is still animating away with this field still mounted and still reading
/// the controller. "A TextEditingController was used after being disposed"
/// followed, and behind it a cascade of layout assertions and the crash
/// screen, every single time somebody saved a name.
///
/// A State's `dispose` runs when the element actually leaves the tree, which
/// is the only moment that is safe.
class _TextEditSheet extends StatefulWidget {
  const _TextEditSheet({
    required this.title,
    required this.hint,
    required this.initial,
    required this.onSave,
    required this.allowEmpty,
  });

  final String title;
  final String hint;
  final String initial;
  final Future<void> Function(String) onSave;
  final bool allowEmpty;

  @override
  State<_TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<_TextEditSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text;
    if (!widget.allowEmpty && value.trim().isEmpty) return;
    // ⚠️ Read before the pop and saved after it, deliberately unawaited
    // here: this widget is on its way out and must not be holding a future
    // that outlives it.
    Navigator.of(context).pop();
    widget.onSave(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: AppSpace.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpace.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title, style: AppText.title())),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  CupertinoIcons.xmark,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: widget.hint),
          ),
          const SizedBox(height: AppSpace.sm),
          GradientButton(label: 'Save', onPressed: _save),
        ],
      ),
    );
  }
}

/* ── Profile header ──────────────────────────────── */
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.petName,
    required this.email,
    required this.onTapAvatar,
    this.profile,
  });

  final String name;
  final String? petName;
  final String? email;

  /// Opens the same sheet the old "Your picture" row did.
  final VoidCallback onTapAvatar;

  /// Null only while the profile is still loading, which draws the fallback
  /// flower — the same thing every other surface does while waiting.
  final UserProfile? profile;

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
          // ⚠️ The picture is the control now. There is no row underneath
          // saying "Your picture ›" any more, so the badge is what tells
          // anyone this can be tapped — a face on a settings screen reads
          // as decoration otherwise.
          GestureDetector(
            onTap: onTapAvatar,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    gradient: AppGradients.cta,
                    shape: BoxShape.circle,
                  ),
                  // The ring is a padded gradient circle *behind* the
                  // avatar rather than a border on it, so a photo sits
                  // inside the ring instead of being clipped by it.
                  child: UserAvatar(profile, size: 66),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                      // Sits half on the photo, so it needs the card's own
                      // colour behind it to read as a separate object
                      // rather than a smudge on the edge of a face.
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: const Icon(
                      CupertinoIcons.camera_fill,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
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

/* ── Reunion widget background ────────────────────── */

/// Picks (or clears) the photo behind the reunion countdown widget.
///
/// ⚠️ **Device-local, and deliberately not shared.** The countdown itself is
/// one row on `reunions` and belongs to both of you; the picture behind it is
/// a decision about one home screen. Syncing it would mean one person's
/// choice of wallpaper overwriting the other's, and an upload, and a bucket,
/// for something neither of them would ever see on the other's phone.
class _ReunionBackgroundRow extends ConsumerStatefulWidget {
  const _ReunionBackgroundRow();

  @override
  ConsumerState<_ReunionBackgroundRow> createState() =>
      _ReunionBackgroundRowState();
}

class _ReunionBackgroundRowState extends ConsumerState<_ReunionBackgroundRow> {
  String _path = '';
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = await DayflowerWidgets.currentReunionBackground();
    if (mounted) setState(() => _path = path);
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Generous: the widget downscales to 1200px on its own, and asking
        // the picker for something small first would throw away detail the
        // crop might have wanted.
        maxWidth: 2400,
        maxHeight: 2400,
      );
      if (picked == null) return;
      final saved =
          await DayflowerWidgets.setReunionBackground(await picked.readAsBytes());
      if (mounted) setState(() => _path = saved ?? '');
    } catch (e) {
      debugPrint('reunion background pick failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    await DayflowerWidgets.setReunionBackground(null);
    if (mounted) {
      setState(() {
        _path = '';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = DayflowerWidgets.isSupported && !_busy;
    final has = _path.isNotEmpty;

    return Column(
      children: [
        _Row(
          title: 'Background image',
          subtitle: has
              ? 'Tap to choose a different one'
              : 'Uses the Dayflower gradient until you pick one',
          value: _busy
              ? 'Saving…'
              : has
                  ? 'Chosen'
                  : 'Not set',
          onTap: enabled ? _pick : null,
        ),
        if (has) ...[
          const _Line(),
          _Row(
            title: 'Remove background',
            danger: true,
            chevron: false,
            onTap: enabled ? _clear : null,
          ),
        ],
      ],
    );
  }
}

/* ── Widget photo-rotation picker row ────────────── */
/// Same shape as [_WidgetModeRow] — one choice out of three, shown as an
/// outline rather than a tick, per design.md.
class _WidgetRotationRow extends ConsumerWidget {
  const _WidgetRotationRow({
    required this.title,
    required this.subtitle,
    required this.seconds,
  });

  final String title;
  final String subtitle;
  final int seconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(widgetRotationProvider) == seconds;
    final enabled = DayflowerWidgets.isSupported;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () => ref.read(widgetRotationProvider.notifier).setSeconds(seconds)
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
    // needs the updater back on screen, not another manifest fetch. `check`
    // deliberately refuses to run over a downloaded APK, so without this the
    // row would look tappable and do nothing.
    final current = ref.read(updateControllerProvider);
    if (current.release != null &&
        (current.stage == UpdateStage.available ||
            current.stage == UpdateStage.ready ||
            current.stage == UpdateStage.failed)) {
      ref.read(updateDismissedProvider.notifier).state = null;
      return;
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

/// Your picture: a photo if you want one, a flower if you don't.
///
/// Both live in one sheet rather than behind a "photo or flower?" fork,
/// because they are the same decision — what stands in for you — and a fork
/// would make the flower feel like the consolation prize. It isn't: it is
/// the default, the fallback, and what the home-screen widget draws.
/// Sets or clears the birthday.
///
/// ⚠️ Opens on the last birthday that has already happened, not on today.
/// A date picker that starts in 2026 makes somebody born in 1998 scroll
/// through 28 years to answer a question they were told was optional. The
/// first year offered is 1920, which is a generous outer bound rather than
/// a guess about anybody.
Future<void> _editBirthday(
  BuildContext context,
  WidgetRef ref,
  UserProfile? profile,
) async {
  final now = DateTime.now();
  final existing = profile?.birthday;
  final picked = await showDatePicker(
    context: context,
    initialDate: existing ?? DateTime(now.year - 25, now.month, now.day),
    firstDate: DateTime(1920),
    lastDate: now,
    helpText: 'Your birthday',
  );
  if (picked == null) return;

  final id = ref.read(currentUserIdProvider);
  if (id == null) return;
  await ref.read(userRepositoryProvider).updateBirthday(id, picked);
  ref.invalidate(userProfileProvider);
}

Future<void> _pickAvatar(
  BuildContext context,
  WidgetRef ref,
  UserProfile? profile,
) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;

  final repository = ref.read(userRepositoryProvider);
  var busy = false;
  String? failure;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // A photo upload is not something to lose by brushing the scrim.
    isDismissible: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Future<void> finish(Future<void> Function() work) async {
          if (busy) return;
          setSheetState(() {
            busy = true;
            failure = null;
          });
          try {
            await work();
            ref.invalidate(userProfileProvider);
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          } catch (_) {
            if (!sheetContext.mounted) return;
            setSheetState(() {
              busy = false;
              failure = "That didn't save. Try again?";
            });
          }
        }

        Future<void> useCamera(ImageSource source) => finish(() async {
              final picked = await ImagePicker().pickImage(
                source: source,
                // Cut down before the bytes ever reach an isolate: a
                // 12-megapixel original costs real time to decode, and
                // every one of those pixels is about to be thrown away.
                maxWidth: 1600,
                maxHeight: 1600,
              );
              // A cancelled picker is not a failure, and must not report as
              // one — it throws nothing and simply returns null.
              if (picked == null) return;
              final raw = await picked.readAsBytes();
              // Off the UI thread: decode, orient, crop and re-encode is
              // hundreds of milliseconds and would freeze this sheet.
              final processed = await compute(squareAvatarJpeg, raw);
              if (processed == null) {
                throw StateError('unreadable image');
              }
              await repository.setAvatarPhoto(
                userId: userId,
                bytes: processed,
              );
            });

        final current = profile?.flower ?? AvatarFlower.fallback;

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          padding: EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md,
              AppSpace.lg + MediaQuery.paddingOf(sheetContext).bottom),
          child: SingleChildScrollView(
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
                Text('Your picture', style: AppText.hero()),
                const SizedBox(height: 4),
                Text(
                  'It stands in for you everywhere — the chat, their home '
                  'screen.',
                  style: AppText.caption(),
                ),
                const SizedBox(height: AppSpace.md),

                // What you look like now, and the two ways to change it.
                Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          UserAvatar(profile, size: 72),
                          if (busy)
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .35),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Column(
                        children: [
                          _AvatarAction(
                            icon: CupertinoIcons.camera_fill,
                            label: 'Take a photo',
                            enabled: !busy,
                            onTap: () => useCamera(ImageSource.camera),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          _AvatarAction(
                            icon: CupertinoIcons.photo_fill,
                            label: 'Choose a photo',
                            enabled: !busy,
                            onTap: () => useCamera(ImageSource.gallery),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (failure != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(failure!, style: AppText.caption(AppColors.danger)),
                ],

                // Only offered when there is something to remove. Removing
                // does not clear your flower — it uncovers it.
                if (profile?.hasPhoto ?? false) ...[
                  const SizedBox(height: AppSpace.xs),
                  GestureDetector(
                    onTap: busy
                        ? null
                        : () => finish(
                              () => repository.removeAvatarPhoto(userId),
                            ),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Remove photo',
                        style: AppText.caption(AppColors.danger)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpace.md),
                Text('OR PICK A FLOWER', style: AppText.label()),
                const SizedBox(height: 4),
                Text(
                  profile?.hasPhoto ?? false
                      ? 'Shown wherever your photo cannot be, including the '
                          'home-screen widget.'
                      : 'Everyone sees the same eight.',
                  style: AppText.caption(),
                ),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final f in AvatarFlower.values)
                      GestureDetector(
                        onTap: busy
                            ? null
                            : () => finish(() => repository.updateProfile(
                                  userId,
                                  avatar: f,
                                )),
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
                                  f == current
                                      ? AppColors.brand
                                      : AppColors.muted,
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
      },
    ),
  );
}

/// One of the two photo buttons.
class _AvatarAction extends StatelessWidget {
  const _AvatarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: Material(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.secondary),
                const SizedBox(width: AppSpace.xs),
                Text(
                  label,
                  style: AppText.caption(AppColors.ink)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🔴 **`const` is a correctness hazard on this screen, not an
// optimisation.** This is the one screen you are looking at while the theme
// changes under you, so its widgets are the only ones whose elements are
// alive across the switch. Flutter skips any subtree whose widget is
// identical to the last one, and a const widget always is — so it never
// rebuilds, and every colour it read from the global AppColors palette
// stays frozen at the mode it was first built in.
//
// Four cards shipped const and stayed white on a black screen. A const
// card also makes everything in its `children:` list const, so the rows
// inside it froze too: their titles inherited fresh colour from the theme
// while their subtitles kept light-mode ink, on a card that was still
// white. Restoring const anywhere here brings all of that back.
//
// The lints below would do exactly that, so they are off for this file.
// See theme_repaint_test.dart, which pins the failure and the fix.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_const_constructors_in_immutables

import 'package:dayflower/core/widgets/app_icon.dart';
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
import '../../../../core/services/legal_links.dart';
import '../../../../core/theme/app_colors.dart';
import 'settings_sections.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/models/avatar_flower.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/theme_mode_prefs.dart';
import '../../../../core/services/avatar_image.dart';
import '../../../../core/widgets/flower_avatar.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/city_picker.dart';
import '../../../../core/widgets/timezone_picker.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../../updates/data/update_repository.dart';
import '../../../push/data/push_repository.dart';
import '../../../push/data/push_service.dart';
import '../../../updates/presentation/widgets/update_screen.dart';

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
          icon: AppIcon(CupertinoIcons.chevron_back,
              color: AppColors.muted),
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
            SettingsCard(
              children: [
                SettingsRow(
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
                const SettingsLine(),
                SettingsRow(
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
                const SettingsLine(),
                SettingsRow(
                  title: 'Birthday',
                  value: profile?.birthday == null
                      ? 'Not set'
                      : DateFormat('MMMM d').format(profile!.birthday!),
                  onTap: () => _editBirthday(context, ref, profile),
                ),
                const SettingsLine(),
                // Where they are, which is the distance — see migration
                // 0034 for why this is not the timezone.
                SettingsRow(
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
                const SettingsLine(),
                SettingsRow(
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
            SettingsCard(
              children: [
                SettingsRow(
                  title: 'Connected with',
                  value: partner?.petName ?? partner?.displayName ?? '—',
                  chevron: false,
                ),
                const SettingsLine(),
                SettingsRow(
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
                const SettingsLine(),
                SettingsRow(
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

            // ── Appearance ───────────────────────────
            Text('APPEARANCE', style: AppText.label()),
            const SizedBox(height: AppSpace.xs),
            SettingsCard(children: [_AppearanceRow()]),
            const SizedBox(height: AppSpace.md),

            // ── Notifications and widgets ────────
            // ⚠️ Both were spelled out here. Alerts moved to the
            // notifications list, where somebody deciding how they want to
            // be interrupted is already standing. The widget options were
            // three headings and three paragraphs for one feature, which
            // pushed the things people actually come to Settings for below
            // the fold.
            Text('MORE', style: AppText.label()),
            const SizedBox(height: AppSpace.xs),
            SettingsCard(
              children: [
                SettingsRow(
                  title: 'Home screen widgets',
                  subtitle: 'What they show, and how they behave',
                  onTap: () => context.push(Routes.widgetSettings),
                ),
                SettingsLine(),
                SettingsRow(
                  title: 'Notifications',
                  subtitle: 'What reaches you, and how',
                  onTap: () => context.push(Routes.notificationSettings),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),

            // ── About ────────────────────────────────
            Text('ABOUT', style: AppText.label()),
            const SizedBox(height: AppSpace.xs),
            SettingsCard(
              children: [
                const _VersionRow(),
                if (UpdateRepository.supported) ...[
                  const SettingsLine(),
                  const _CheckForUpdatesRow(),
                ],
                const SettingsLine(),
                SettingsRow(
                  title: 'Terms of Service',
                  onTap: () => openLegalPage(context, ref, LegalPage.terms),
                ),
                const SettingsLine(),
                SettingsRow(
                  title: 'Privacy Policy',
                  onTap: () => openLegalPage(context, ref, LegalPage.privacy),
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
                icon: AppIcon(
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
                    child: const AppIcon(
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


/* ── Reunion widget background ────────────────────── */


/* ── Widget photo-rotation picker row ────────────── */

/* ── Adaptive-widget mode picker row ─────────────── */

/* ── Settings row with a switch ──────────────────── */

/* ── Settings row ────────────────────────────────── */

/* ── About: version + manual update check ────────── */

/// The build actually installed, not a constant in the source. Once the
/// build number is what decides whether an update exists, showing anything
/// else here would be showing a number that can lie.
class _VersionRow extends ConsumerWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsRow(
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

    return SettingsRow(
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
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                AppIcon(icon, size: 16, color: AppColors.secondary),
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

/* ── Appearance ───────────────────────────────────── */

/// Dark mode, as one switch.
///
/// 🔴 **This was two cards with a sunflower and a jasmine on them.** The
/// idea was that the artwork says what the setting does better than the words
/// "Dark mode" do. In practice it was two large tap targets, neither obviously
/// selected at a glance, for a choice with exactly two states and an obvious
/// default — and it sat in a row of plain switches that all behaved the other
/// way. A switch is what the rest of this screen uses and what the setting
/// actually is.
///
/// ⚠️ The palette is global, so flipping this repaints the whole app from
/// the root. See the key on MaterialApp in app.dart, and the test that pins
/// why it is needed.
class _AppearanceRow extends ConsumerWidget {
  const _AppearanceRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return SettingsSwitchRow(
      title: 'Dark mode',
      subtitle: 'Kinder at night. Only on this phone.',
      value: mode == AppMode.dark,
      onChanged: (on) => ref
          .read(themeModeProvider.notifier)
          .use(on ? AppMode.dark : AppMode.light),
    );
  }
}

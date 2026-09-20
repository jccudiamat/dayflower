// 🔴 `const` is a correctness hazard here, exactly as in
// settings_screen.dart: a const widget is identical to itself, so Flutter
// never calls its build again and any colour it read from the global
// AppColors palette stays frozen at the mode it was first inflated in.
// These are the pieces that shipped white on a black screen.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_const_constructors_in_immutables


import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../widget/widget_mode_provider.dart';
import '../../../widget/widget_sync.dart';

/// The shared furniture of the settings screens.
///
/// ⚠️ Lifted out of settings_screen.dart when the widget options moved to
/// their own screen and the alerts moved onto Notifications. Three screens
/// draw the same card, the same hairline and the same switch row; the
/// alternative was three copies drifting apart.

/// 🔴 **Reads the palette through Theme, never through AppColors.**
/// Four of these are built `const`, and a const widget is identical to
/// itself, so Flutter's updateChild returns the existing element without
/// calling build again. A colour fetched from the global palette is
/// therefore fetched exactly once, and the card goes on painting the mode
/// it was first inflated in — which is how Settings ended up with four
/// white cards on a black screen, white titles on them and, inside the very
/// same cards, dividers that had switched correctly because `Divider` reads
/// the theme.
///
/// ⚠️ The MaterialApp is keyed on the mode to force exactly this rebuild,
/// and it is not enough here: GoRouter's delegate outlives the rekey and
/// keeps the page's elements, so the const subtree under it is never
/// discarded. Depending on an InheritedWidget is what actually works, and
/// it works *because* Theme notifies its dependents regardless of whether
/// the widget that registered the dependency is const.
class SettingsCard extends StatelessWidget {
  SettingsCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(children: children),
    );
  }
}

class SettingsLine extends StatelessWidget {
  const SettingsLine({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpace.sm),
      child: Divider(height: 1),
    );
  }
}

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({super.key, 
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

class WidgetModeRow extends ConsumerWidget {
  const WidgetModeRow({super.key, 
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

/// Same shape as [WidgetModeRow] — one choice out of three, shown as an
/// outline rather than a tick, per design.md.
class WidgetRotationRow extends ConsumerWidget {
  const WidgetRotationRow({super.key, 
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
            ? () =>
                ref.read(widgetRotationProvider.notifier).setSeconds(seconds)
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

/// Picks (or clears) the photo behind the reunion countdown widget.
///
/// ⚠️ **Device-local, and deliberately not shared.** The countdown itself is
/// one row on `reunions` and belongs to both of you; the picture behind it is
/// a decision about one home screen. Syncing it would mean one person's
/// choice of wallpaper overwriting the other's, and an upload, and a bucket,
/// for something neither of them would ever see on the other's phone.
class ReunionBackgroundRow extends ConsumerStatefulWidget {
  const ReunionBackgroundRow({super.key});

  @override
  ConsumerState<ReunionBackgroundRow> createState() =>
      ReunionBackgroundRowState();
}

class ReunionBackgroundRowState extends ConsumerState<ReunionBackgroundRow> {
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
      final saved = await DayflowerWidgets.setReunionBackground(
          await picked.readAsBytes());
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
        SettingsRow(
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
          const SettingsLine(),
          SettingsRow(
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

class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, 
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
                AppIcon(
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

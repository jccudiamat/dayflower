import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/flower_image.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../domain/flower_catalog.dart';

/// The flower catalog, rendered as an inline panel in place of the keyboard —
/// the same gesture as WhatsApp's GIF/sticker drawer.
///
/// It is a plain child of the composer's Column rather than a modal sheet on
/// purpose: a sheet would slide over the conversation, and half the point of
/// picking a flower is seeing the thread you're picking it for.
class FlowerCatalogPanel extends StatefulWidget {
  const FlowerCatalogPanel({
    super.key,
    required this.height,
    required this.onPick,
  });

  /// Matched to the keyboard's height by the chat screen, so opening and
  /// closing the drawer doesn't make the conversation jump.
  final double height;

  final ValueChanged<Flower> onPick;

  @override
  State<FlowerCatalogPanel> createState() => _FlowerCatalogPanelState();
}

class _FlowerCatalogPanelState extends State<FlowerCatalogPanel> {
  FlowerCategory? _category; // null = All

  @override
  Widget build(BuildContext context) {
    final flowers = _category == null
        ? FlowerCatalog.pickable
        : FlowerCatalog.pickable
            .where((f) => f.category == _category)
            .toList();

    return Container(
      height: widget.height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.sm,
              AppSpace.xs,
              AppSpace.sm,
              AppSpace.xs,
            ),
            child: Row(
              children: [
                _CategoryChip(
                  label: 'All',
                  selected: _category == null,
                  onTap: () => setState(() => _category = null),
                ),
                const SizedBox(width: AppSpace.xs),
                _CategoryChip(
                  label: 'Flowers',
                  selected: _category == FlowerCategory.flower,
                  onTap: () =>
                      setState(() => _category = FlowerCategory.flower),
                ),
                const SizedBox(width: AppSpace.xs),
                _CategoryChip(
                  label: 'Scenes',
                  selected: _category == FlowerCategory.scene,
                  onTap: () => setState(() => _category = FlowerCategory.scene),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.sm,
                0,
                AppSpace.sm,
                AppSpace.sm,
              ),
              // Three across: this is a drawer you scan, not the full-screen
              // picker it replaced, so tiles trade size for how many you see.
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: flowers.length,
              itemBuilder: (context, i) => _CatalogTile(
                flower: flowers[i],
                onTap: () => widget.onPick(flowers[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.micro,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppText.caption(
            selected ? AppColors.onDark : AppColors.body,
          ).copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.flower, required this.onTap});

  final Flower flower;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              flower.asset,
              fit: BoxFit.cover,
              semanticLabel: flower.name,
              errorBuilder: (_, __, ___) => Container(
                color: flower.color.withValues(alpha: .12),
                alignment: Alignment.center,
                child: Text(
                  flower.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),
            // Scrim only behind the label so the artwork stays bright.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .78),
                    ],
                  ),
                ),
                child: Text(
                  flower.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(Colors.white)
                      .copyWith(fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ── Send sheet ──────────────────────────────────── */

/// What the sender settled on before hitting Send.
typedef FlowerSend = ({String note, bool toWidget});

/// Confirmation step between picking a flower and it landing in the thread.
///
/// A GIF drawer sends on tap, but a flower carries two decisions a GIF
/// doesn't — the note, and whether it takes over their home screen — so it
/// gets one deliberate step. Returns null if dismissed.
Future<FlowerSend?> showFlowerSendSheet(
  BuildContext context, {
  required Flower flower,
  String initialNote = '',
  required String partnerName,
}) {
  return showModalBottomSheet<FlowerSend>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _FlowerSendSheet(
      flower: flower,
      initialNote: initialNote,
      partnerName: partnerName,
    ),
  );
}

class _FlowerSendSheet extends StatefulWidget {
  const _FlowerSendSheet({
    required this.flower,
    required this.initialNote,
    required this.partnerName,
  });

  final Flower flower;
  final String initialNote;
  final String partnerName;

  @override
  State<_FlowerSendSheet> createState() => _FlowerSendSheetState();
}

class _FlowerSendSheetState extends State<_FlowerSendSheet> {
  late final TextEditingController _note =
      TextEditingController(text: widget.initialNote);

  /// Defaults on: the home-screen widget is the whole point of the app, so
  /// the common case shouldn't cost a tap. Untick for a flower that's just
  /// part of the conversation.
  bool _toWidget = true;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            AppSpace.sm,
            20,
            AppSpace.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  FlowerImage(flower: widget.flower, size: 72),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.flower.name, style: AppText.title()),
                        const SizedBox(height: 2),
                        Text(
                          widget.flower.meaning,
                          style: AppText.note().copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                controller: _note,
                maxLength: 140,
                minLines: 1,
                maxLines: 3,
                autofocus: false,
                style: AppText.note(AppColors.ink),
                decoration: const InputDecoration(
                  hintText: 'Say something with it… (optional)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              // The one thing that makes this different from a chat sticker:
              // it can take over their home screen.
              GestureDetector(
                onTap: () => setState(() => _toWidget = !_toWidget),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _toWidget
                        ? AppColors.blush
                        : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.device_phone_portrait,
                        size: 20,
                        color: _toWidget ? AppColors.brand : AppColors.muted,
                      ),
                      const SizedBox(width: AppSpace.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Put it on their home screen',
                              style: AppText.caption(AppColors.ink)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _toWidget
                                  ? "Replaces what's on ${widget.partnerName}'s widget now"
                                  : 'Stays in the conversation only',
                              style: AppText.caption(),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _toWidget,
                        onChanged: (v) => setState(() => _toWidget = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              GradientButton(
                label: 'Send ${widget.flower.name}',
                onPressed: () => Navigator.of(context).pop(
                  (note: _note.text, toWidget: _toWidget),
                ),
              ),
              const SizedBox(height: AppSpace.xs),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../data/memory_views.dart';

/// All · Photos · Flowers · Cards · Journal · Places.
///
/// Compact pills: the chosen one coral with white text, the rest a pale
/// lavender. The row scrolls on a narrow phone, and fades its trailing edge
/// while there is more to reach, so a clipped pill reads as "more" rather
/// than as a layout fault.
class MemoryCategoryTabs extends StatefulWidget {
  const MemoryCategoryTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final MemoryCategory selected;
  final ValueChanged<MemoryCategory> onSelected;

  @override
  State<MemoryCategoryTabs> createState() => _MemoryCategoryTabsState();
}

class _MemoryCategoryTabsState extends State<MemoryCategoryTabs> {
  final _controller = ScrollController();
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sync);
    // The extent is unknown until the first layout. Opened on one of the
    // last chips, the row starts scrolled to it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (widget.selected.index >= MemoryCategory.values.length - 2) {
        _controller.jumpTo(_controller.position.maxScrollExtent);
      }
      _sync();
    });
  }

  void _sync() {
    if (!mounted || !_controller.hasClients) return;
    final more = _controller.offset < _controller.position.maxScrollExtent - 1;
    if (more != _more) setState(() => _more = more);
  }

  /// A chosen chip is never left half behind the edge's fade: choosing one
  /// of the last few scrolls the row to its end, one of the first few back
  /// to its start. Only the row moves; the page stays where it is.
  @override
  void didUpdateWidget(MemoryCategoryTabs old) {
    super.didUpdateWidget(old);
    if (old.selected == widget.selected || !_controller.hasClients) return;
    const values = MemoryCategory.values;
    final i = widget.selected.index;
    final target = i >= values.length - 2
        ? _controller.position.maxScrollExtent
        : i <= 1
            ? 0.0
            : null;
    if (target == null) return;
    _controller.animateTo(target,
        duration: AppMotion.standard, curve: AppMotion.easeOut);
  }

  @override
  void dispose() {
    _controller.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final category in MemoryCategory.values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _Pill(
              label: category.label,
              selected: category == widget.selected,
              onTap: () => widget.onSelected(category),
            ),
          ),
      ]),
    );
    // ⚠️ Always masked, and only the fade changes. Returning the bare row
    // once the end was reached rebuilt the scroll view under a different
    // parent, which reset its offset: choosing Places scrolled the row to
    // its end, the fade came off, and the row jumped back to the start.
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          Colors.white,
          Colors.white,
          _more ? Colors.transparent : Colors.white,
        ],
        stops: const [0, .9, 1],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: row,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected
              ? MemoriesStyle.chipSelectedFill
              : MemoriesStyle.chipFill,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(label,
                  style: MemoriesStyle.chipLabel(selected: selected)),
            ),
          ),
        ),
      );
}

/// The search field. All has it; no other category does.
class MemorySearchField extends StatelessWidget {
  const MemorySearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppText.body(AppColors.ink),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceSubtle,
          hintText: 'Search memories…',
          hintStyle: AppText.body(AppColors.muted),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: AppIcon(CupertinoIcons.search,
                size: 19, color: AppColors.muted),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: AppIcon(CupertinoIcons.xmark_circle_fill,
                        size: 18, color: AppColors.muted),
                  ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.secondary, width: 1.2),
          ),
        ),
      );
}

/// A category's heading row: its title, a line under it, and a link.
class MemorySectionHeader extends StatelessWidget {
  const MemorySectionHeader({
    super.key,
    required this.title,
    this.meta,
    this.action,
    this.onAction,
  });

  final String title;
  final String? meta;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MemoriesStyle.sectionTitle()),
                if (meta != null) ...[
                  const SizedBox(height: 2),
                  Text(meta!, style: MemoriesStyle.sectionMeta()),
                ],
              ],
            ),
          ),
          if (action != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(action!, style: MemoriesStyle.link()),
                  const SizedBox(width: 2),
                  const AppIcon(CupertinoIcons.chevron_right,
                      size: 13, color: AppColors.secondary),
                ]),
              ),
            ),
        ],
      );
}

/// A category with nothing in it yet: one quiet line, never "no records".
class MemoryEmpty extends StatelessWidget {
  const MemoryEmpty({super.key, required this.title, this.body = ''});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
        child: Column(children: [
          const AppIcon(CupertinoIcons.heart, size: 28, color: AppColors.brand),
          const SizedBox(height: AppSpace.sm),
          Text(title,
              textAlign: TextAlign.center,
              style: AppText.subtitle(AppColors.ink)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xs),
            Text(body,
                textAlign: TextAlign.center,
                style: AppText.body(AppColors.muted)),
          ],
        ]),
      );
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// The standard editing sheet: grab handle, title, optional subtitle, then
/// whatever fields the caller supplies.
///
/// Lifted out of `events_screen.dart` when Reminders, Finance and Chapters
/// all needed the same thing — four private copies of a bottom sheet is how
/// four bottom sheets start looking different from each other.
///
/// Always show it with `isScrollControlled: true` and a transparent
/// `backgroundColor`; this widget paints its own surface and adds the
/// keyboard inset itself.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      // Capped so a long form scrolls inside the sheet instead of pushing
      // its own save button off the bottom of the screen.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            AppSpace.md, 0, AppSpace.md, AppSpace.lg + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Text(title, style: AppText.hero()),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: AppText.caption()),
            ],
            const SizedBox(height: AppSpace.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// Uppercase brand-pink label above a field inside a sheet.
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xxs),
      child: Text(label.toUpperCase(), style: AppText.label(AppColors.brand)),
    );
  }
}

/// A text field styled for a sheet: filled with the canvas colour so it
/// reads as inset against the white surface, which is the reverse of the
/// global [InputDecorationTheme] (white on canvas).
class AppSheetField extends StatelessWidget {
  const AppSheetField({
    super.key,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.serif = false,
    this.prefix,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final TextAlign textAlign;
  final bool autofocus;

  /// Lora italic — for the one field per sheet that is prose rather than
  /// data (a review, a note). design.md keeps the serif rare on purpose.
  final bool serif;

  final Widget? prefix;

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: color),
      );

  @override
  Widget build(BuildContext context) {
    final style = serif ? AppText.note() : AppText.body(AppColors.ink);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      textAlign: textAlign,
      autofocus: autofocus,
      style: style,
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: style.copyWith(color: AppColors.muted),
        prefixIcon: prefix,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: 11,
        ),
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.brand),
      ),
    );
  }
}

/// Pill row of mutually exclusive options — the shared/solo switch, the
/// income/expense switch, the repeat picker.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  /// Value → label, in the order they should appear.
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: options.entries.map((entry) {
          final selected = entry.key == value;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: AppMotion.micro,
                curve: AppMotion.easeOut,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // The selected pill is the only gradient here — the row
                  // itself is a neutral, so this stays one accent.
                  gradient: selected ? AppGradients.cta : null,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(
                    selected ? Colors.white : AppColors.body,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

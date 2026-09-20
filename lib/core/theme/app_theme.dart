import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:dayflower/core/theme/app_typography.dart';

import '../widgets/app_icon.dart';
import 'app_colors.dart';
import 'design_tokens.dart';

class AppTheme {
  /// The theme for whichever palette is loaded.
  ///
  /// ⚠️ Not `light` any more, and the rename is the point: every colour
  /// below already reads through `AppColors`, so this one getter produces
  /// both modes and there is no second `dark` ThemeData to drift from it.
  /// Read *after* `AppColors.use()` — see app.dart.
  static ThemeData get current {
    final dark = AppColors.isDark;
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.family,
      // Tells Material what to assume for everything this file does not
      // name — cursor colours, ripple opacity, the default icon theme.
      brightness: dark ? Brightness.dark : Brightness.light,
    );

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: AppColors.brand,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        // 🔴 Without this, `fromSeed` derives its own on-surface ink from
        // the pink seed and Material widgets that do not take an explicit
        // colour — menu items, date pickers — render near-black text on a
        // plum sheet.
        onSurface: AppColors.ink,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,

      textTheme: base.textTheme.copyWith(
        displayLarge: AppText.display(),
        displayMedium: AppText.hero(),
        displaySmall: AppText.title(),
        headlineLarge: AppText.hero(),
        headlineMedium: AppText.title(),
        headlineSmall: AppText.subtitle(),
        titleLarge: AppText.title(),
        titleMedium: AppText.subtitle(),
        titleSmall: _text(14, FontWeight.w600, AppColors.ink),
        bodyLarge: AppText.body(AppColors.ink),
        bodyMedium: AppText.body(),
        bodySmall: AppText.caption(),
        labelLarge: _text(15, FontWeight.w600, AppColors.ink),
        labelMedium: AppText.label(AppColors.body),
        labelSmall: AppText.label(),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.title(),
        // The *icons* in the status bar, so they are readable against the
        // canvas behind them: dark glyphs on a light app, light on a dark.
        systemOverlayStyle:
            dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      // 🔴 Every automatic back button in the app, in one place.
      // An AppBar with no explicit `leading` draws Material's arrow, which
      // is how two screens ended up with a different way back from the
      // twelve that ask for [IosBackButton] by hand. Setting it here means
      // the next AppBar written without a leading is already right.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => AppIcon(
            CupertinoIcons.chevron_back,
            size: 18,
            color: AppColors.ink),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: 15,
        ),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.secondary, width: 1.5),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.5),
        hintStyle: AppText.body(AppColors.muted),
        errorStyle: AppText.caption(AppColors.danger),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      // Fallback solid button — prefer GradientButton for primary CTAs.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.blushMid,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: 13,
          ),
          textStyle: _text(15, FontWeight.w600, Colors.white),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: BorderSide(
            color: AppColors.secondary.withValues(alpha: .55),
            width: 1.5,
          ),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: _text(15, FontWeight.w600, AppColors.ink),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
          textStyle: _text(14, FontWeight.w600, AppColors.secondary),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: false,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: AppText.title(),
        contentTextStyle: AppText.body(),
      ),

      snackBarTheme: SnackBarThemeData(
        // On light this is the plum slab it has always been. On dark that
        // colour *is* the card surface, so it steps up instead — a snackbar
        // that matches the cards behind it reads as part of the page.
        backgroundColor: dark ? AppColors.darkRaised : AppColors.darkSurface,
        contentTextStyle: _text(14, FontWeight.w500, AppColors.onDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.secondary
              : AppColors.border,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.brand,
        inactiveTrackColor: AppColors.surfaceSubtle,
        thumbColor: Colors.white,
        overlayColor: AppColors.brand.withValues(alpha: .12),
        trackHeight: 3,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.blush,
        labelStyle: _text(13, FontWeight.w500, AppColors.body),
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.secondary,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextStyle _text(double size, FontWeight weight, Color color) =>
      AppTypography.style(fontSize: size, fontWeight: weight, color: color);
}

import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/app/theme/typography.dart';

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final primary = AppColors.primaryFor(brightness);
  final secondary = AppColors.secondaryFor(brightness);
  final surface = AppColors.surfaceFor(brightness);
  final surfaceMuted = AppColors.surfaceMutedFor(brightness);
  final background = AppColors.backgroundFor(brightness);
  final surfaceRaised = AppColors.surfaceRaisedFor(brightness);
  final border = AppColors.borderFor(brightness);
  final textPrimary = AppColors.textPrimaryFor(brightness);
  final textSecondary = AppColors.textSecondaryFor(brightness);

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: secondary,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      outline: border,
    ),
    scaffoldBackgroundColor: background,
    textTheme: buildTypography(brightness: brightness),
    dividerColor: border,
    splashFactory: InkRipple.splashFactory,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimary,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceRaised,
      labelStyle: TextStyle(
        color: isDark ? textPrimary.withValues(alpha: 0.90) : textSecondary,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: TextStyle(
        color: primary,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(
        color: textSecondary.withValues(alpha: isDark ? 0.78 : 0.92),
      ),
      helperStyle: TextStyle(
        color: textSecondary.withValues(alpha: isDark ? 0.90 : 1),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: secondary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: surfaceMuted,
        disabledForegroundColor: textSecondary.withValues(alpha: 0.72),
        minimumSize: const Size.fromHeight(54),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: border),
        foregroundColor: textPrimary,
        backgroundColor: surfaceRaised.withValues(alpha: isDark ? 0.92 : 0.74),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      iconColor: textSecondary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: secondary,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: primary,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surfaceMutedFor(brightness),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      side: BorderSide(color: border),
      labelStyle: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

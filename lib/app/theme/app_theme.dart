import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/app/theme/typography.dart';

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final primary = AppColors.primaryFor(brightness);
  final secondary = AppColors.secondaryFor(brightness);
  final surface = AppColors.surfaceFor(brightness);
  final border = AppColors.borderFor(brightness);
  final textPrimary = AppColors.textPrimaryFor(brightness);
  final textSecondary = AppColors.textSecondaryFor(brightness);
  final glassSurface = AppColors.glassSurfaceFor(brightness);
  final glassStrong = AppColors.glassSurfaceStrongFor(brightness);
  final glassBorder = AppColors.glassBorderFor(brightness);

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
    scaffoldBackgroundColor: Colors.transparent,
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
      color: glassSurface,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: glassBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.dark
          ? AppColors.surfaceRaisedDark.withValues(alpha: 0.86)
          : AppColors.surface.withValues(alpha: 0.96),
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
        borderSide: BorderSide(
          color: glassBorder.withValues(alpha: isDark ? 0.54 : 0.82),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(
          color: glassBorder.withValues(alpha: isDark ? 0.54 : 0.82),
        ),
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
        disabledBackgroundColor: brightness == Brightness.dark
            ? AppColors.surfaceMutedDark.withValues(alpha: 0.92)
            : AppColors.surfaceMuted.withValues(alpha: 0.98),
        disabledForegroundColor: textSecondary.withValues(alpha: 0.82),
        minimumSize: const Size(0, 54),
        elevation: 0,
        side: BorderSide(
          color: brightness == Brightness.dark
              ? AppColors.borderDark.withValues(alpha: 0.56)
              : AppColors.border.withValues(alpha: 0.72),
        ),
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
        minimumSize: const Size(0, 52),
        side: BorderSide(color: glassBorder),
        foregroundColor: textPrimary,
        backgroundColor: glassSurface,
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
      unselectedItemColor: textSecondary.withValues(alpha: 0.76),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary.withValues(alpha: isDark ? 0.68 : 0.54);
        }
        return isDark
            ? AppColors.surfaceRaisedDark.withValues(alpha: 0.92)
            : AppColors.surfaceMuted.withValues(alpha: 0.96);
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return isDark ? AppColors.textPrimaryDark : Colors.white;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary.withValues(alpha: isDark ? 0.42 : 0.28);
        }
        return border.withValues(alpha: isDark ? 0.74 : 0.90);
      }),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: glassStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      side: BorderSide(color: glassBorder),
      labelStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
    ),
  );
}

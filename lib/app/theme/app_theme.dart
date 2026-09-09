import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/app/theme/typography.dart';

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final scaffoldBg = isDark
      ? RootBrandColors.charcoalPine
      : RootBrandColors.warmIvory;
  final surface = isDark
      ? RootBrandColors.nightPine
      : RootBrandColors.pureWhite;
  final border = isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC);
  final textPrimary = isDark
      ? RootBrandColors.warmIvory
      : RootBrandColors.charcoalPine;
  final textSecondary = isDark
      ? RootBrandColors.mutedSage
      : const Color(0xFF5E6F68);

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: RootBrandColors.pineGreen,
      onPrimary: Colors.white,
      secondary: RootBrandColors.amberAccent,
      onSecondary: RootBrandColors.nightPine,
      error: RootBrandColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      outline: border,
    ),
    scaffoldBackgroundColor: scaffoldBg,
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
        side: BorderSide(color: border, width: 1.0),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? RootBrandColors.deepForest : Colors.white,
      labelStyle: TextStyle(
        color: isDark ? textPrimary.withValues(alpha: 0.90) : textSecondary,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: const TextStyle(
        color: RootBrandColors.pineGreen,
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
        borderSide: BorderSide(color: border, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: border, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(
          color: RootBrandColors.pineGreen,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RootBrandColors.pineGreen,
        foregroundColor: Colors.white,
        disabledBackgroundColor: isDark
            ? RootBrandColors.slatePine
            : const Color(0xFFEBECE7),
        disabledForegroundColor: textSecondary,
        minimumSize: const Size(0, 54),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        textStyle: const TextStyle(
          fontSize: 16,
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
        side: BorderSide(color: border, width: 1.0),
        foregroundColor: textPrimary,
        backgroundColor: isDark ? RootBrandColors.nightPine : Colors.white,
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
      backgroundColor: isDark
          ? RootBrandColors.nightPine
          : RootBrandColors.charcoalPine,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: border, width: 1.0),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: isDark
          ? RootBrandColors.nightPine
          : RootBrandColors.pureWhite,
      selectedItemColor: RootBrandColors.pineGreen,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: RootBrandColors.pineGreen,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return RootBrandColors.pineGreen;
        }
        return isDark ? RootBrandColors.slatePine : const Color(0xFFD7E3DC);
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return Colors.white;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return RootBrandColors.pineGreen;
        }
        return border;
      }),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: isDark
          ? RootBrandColors.deepForest
          : RootBrandColors.warmIvory,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      side: BorderSide(color: border, width: 1.0),
      labelStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
    ),
  );
}

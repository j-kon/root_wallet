import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF138A6B);
  static const primaryBright = Color(0xFF26C89A);
  static const primaryDeep = Color(0xFF0D5C48);
  static const secondary = Color(0xFF0E1B18);
  static const secondaryDark = Color(0xFF06110E);
  static const accent = Color(0xFFF7B955);
  static const background = Color(0xFFF4F7F4);
  static const backgroundTint = Color(0xFFE4F0EA);
  static const backgroundDark = Color(0xFF06120F);
  static const backgroundTintDark = Color(0xFF10201B);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEDF4F0);
  static const surfaceRaised = Color(0xFFF9FBFA);
  static const surfaceDark = Color(0xFF10201B);
  static const surfaceMutedDark = Color(0xFF142823);
  static const surfaceRaisedDark = Color(0xFF19312A);
  static const border = Color(0xFFD7E3DC);
  static const borderDark = Color(0xFF2A4A42);
  static const glassWhite = Color(0xFFFFFFFF);
  static const glassNight = Color(0xFF091512);
  static const glassMint = Color(0xFFDCF5EC);
  static const glassMintDark = Color(0xFF17322B);
  static const glassBorderLight = Color(0x99FFFFFF);
  static const glassBorderNight = Color(0x4DDBFFF2);
  static const glassHighlightLight = Color(0xE6FFFFFF);
  static const glassHighlightNight = Color(0x66F4FFF9);
  static const success = Color(0xFF17976F);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFD94A4A);
  static const textPrimary = Color(0xFF10211C);
  static const textSecondary = Color(0xFF5E6F68);
  static const textPrimaryDark = Color(0xFFF3F7F5);
  static const textSecondaryDark = Color(0xFFB4C7C0);
  static const shadow = Color(0x140E1B18);
  static const shadowDark = Color(0x66000000);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? primaryBright : primary;

  static Color secondaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? secondaryDark : secondary;

  static Color backgroundFor(Brightness brightness) =>
      brightness == Brightness.dark ? backgroundDark : background;

  static Color backgroundTintFor(Brightness brightness) =>
      brightness == Brightness.dark ? backgroundTintDark : backgroundTint;

  static Color surfaceFor(Brightness brightness) =>
      brightness == Brightness.dark ? surfaceDark : surface;

  static Color surfaceMutedFor(Brightness brightness) =>
      brightness == Brightness.dark ? surfaceMutedDark : surfaceMuted;

  static Color surfaceRaisedFor(Brightness brightness) =>
      brightness == Brightness.dark ? surfaceRaisedDark : surfaceRaised;

  static Color borderFor(Brightness brightness) =>
      brightness == Brightness.dark ? borderDark : border;

  static Color textPrimaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? textPrimaryDark : textPrimary;

  static Color textSecondaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? textSecondaryDark : textSecondary;

  static Color shadowFor(Brightness brightness) =>
      brightness == Brightness.dark ? shadowDark : shadow;

  static Color glassSurfaceFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? glassNight.withValues(alpha: 0.62)
      : glassWhite.withValues(alpha: 0.66);

  static Color glassSurfaceStrongFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? glassMintDark.withValues(alpha: 0.58)
      : glassMint.withValues(alpha: 0.74);

  static Color glassBorderFor(Brightness brightness) =>
      brightness == Brightness.dark ? glassBorderNight : glassBorderLight;

  static Color glassHighlightFor(Brightness brightness) =>
      brightness == Brightness.dark ? glassHighlightNight : glassHighlightLight;

  static Color glassGlowFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? primaryBright.withValues(alpha: 0.18)
      : primary.withValues(alpha: 0.10);

  static Color primaryOf(BuildContext context) =>
      primaryFor(Theme.of(context).brightness);

  static Color secondaryOf(BuildContext context) =>
      secondaryFor(Theme.of(context).brightness);

  static Color backgroundOf(BuildContext context) =>
      backgroundFor(Theme.of(context).brightness);

  static Color backgroundTintOf(BuildContext context) =>
      backgroundTintFor(Theme.of(context).brightness);

  static Color surfaceOf(BuildContext context) =>
      surfaceFor(Theme.of(context).brightness);

  static Color surfaceMutedOf(BuildContext context) =>
      surfaceMutedFor(Theme.of(context).brightness);

  static Color surfaceRaisedOf(BuildContext context) =>
      surfaceRaisedFor(Theme.of(context).brightness);

  static Color borderOf(BuildContext context) =>
      borderFor(Theme.of(context).brightness);

  static Color textPrimaryOf(BuildContext context) =>
      textPrimaryFor(Theme.of(context).brightness);

  static Color textSecondaryOf(BuildContext context) =>
      textSecondaryFor(Theme.of(context).brightness);

  static Color shadowOf(BuildContext context) =>
      shadowFor(Theme.of(context).brightness);

  static Color glassSurfaceOf(BuildContext context) =>
      glassSurfaceFor(Theme.of(context).brightness);

  static Color glassSurfaceStrongOf(BuildContext context) =>
      glassSurfaceStrongFor(Theme.of(context).brightness);

  static Color glassBorderOf(BuildContext context) =>
      glassBorderFor(Theme.of(context).brightness);

  static Color glassHighlightOf(BuildContext context) =>
      glassHighlightFor(Theme.of(context).brightness);

  static Color glassGlowOf(BuildContext context) =>
      glassGlowFor(Theme.of(context).brightness);
}

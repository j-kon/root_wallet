import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';

/// Legacy color accessor re-wired to the canonical [RootBrandColors] system.
///
/// NOTE: Gradients, glows, and frosted glass effects have been eliminated in
/// favor of solid Root brand colors.
abstract final class AppColors {
  // Core brand anchors
  static const primary = RootBrandColors.pineGreen;
  static const primaryBright = RootBrandColors.pineGreen;
  static const primaryDeep = RootBrandColors.deepForest;
  static const secondary = RootBrandColors.nightPine;
  static const secondaryDark = RootBrandColors.charcoalPine;
  static const accent = RootBrandColors.amberAccent;

  // Backgrounds
  static const background = RootBrandColors.warmIvory;
  static const backgroundTint = RootBrandColors.warmIvory;
  static const backgroundDark = RootBrandColors.charcoalPine;
  static const backgroundTintDark = RootBrandColors.nightPine;

  // Surfaces
  static const surface = RootBrandColors.pureWhite;
  static const surfaceMuted = Color(0xFFEBECE7);
  static const surfaceRaised = RootBrandColors.pureWhite;
  static const surfaceDark = RootBrandColors.nightPine;
  static const surfaceMutedDark = RootBrandColors.slatePine;
  static const surfaceRaisedDark = RootBrandColors.deepForest;

  // Outlines / Borders
  static const border = Color(0xFFD7E3DC);
  static const borderDark = RootBrandColors.borderPine;

  // Neutralized surface tokens (previously glass)
  static const glassWhite = RootBrandColors.pureWhite;
  static const glassNight = RootBrandColors.nightPine;
  static const glassMint = RootBrandColors.warmIvory;
  static const glassMintDark = RootBrandColors.nightPine;
  static const glassBorderLight = Color(0xFFD7E3DC);
  static const glassBorderNight = RootBrandColors.borderPine;
  static const glassHighlightLight = Colors.transparent;
  static const glassHighlightNight = Colors.transparent;

  // Semantic
  static const success = RootBrandColors.pineGreen;
  static const warning = RootBrandColors.amberAccent;
  static const danger = RootBrandColors.error;

  // Typography
  static const textPrimary = RootBrandColors.charcoalPine;
  static const textSecondary = Color(0xFF5E6F68);
  static const textPrimaryDark = RootBrandColors.warmIvory;
  static const textSecondaryDark = RootBrandColors.mutedSage;

  // Shadows
  static const shadow = Color(0x140E1B18);
  static const shadowDark = Color(0x40000000);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primaryFor(Brightness brightness) => RootBrandColors.pineGreen;

  static Color secondaryFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? RootBrandColors.nightPine
      : RootBrandColors.charcoalPine;

  static Color backgroundFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? RootBrandColors.charcoalPine
      : RootBrandColors.warmIvory;

  static Color backgroundTintFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? RootBrandColors.nightPine
      : RootBrandColors.warmIvory;

  static Color surfaceFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? RootBrandColors.nightPine
      : RootBrandColors.pureWhite;

  static Color surfaceMutedFor(Brightness brightness) =>
      brightness == Brightness.dark ? RootBrandColors.slatePine : surfaceMuted;

  static Color surfaceRaisedFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? RootBrandColors.deepForest
      : RootBrandColors.pureWhite;

  static Color borderFor(Brightness brightness) =>
      brightness == Brightness.dark ? RootBrandColors.borderPine : border;

  static Color textPrimaryFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? RootBrandColors.warmIvory
      : RootBrandColors.charcoalPine;

  static Color textSecondaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? RootBrandColors.mutedSage : textSecondary;

  static Color shadowFor(Brightness brightness) =>
      brightness == Brightness.dark ? shadowDark : shadow;

  static Color glassSurfaceFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? RootBrandColors.nightPine
      : RootBrandColors.pureWhite;

  static Color glassSurfaceStrongFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? RootBrandColors.deepForest
      : RootBrandColors.warmIvory;

  static Color glassBorderFor(Brightness brightness) =>
      brightness == Brightness.dark ? RootBrandColors.borderPine : border;

  static Color glassHighlightFor(Brightness brightness) => Colors.transparent;

  static Color glassGlowFor(Brightness brightness) => Colors.transparent;

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

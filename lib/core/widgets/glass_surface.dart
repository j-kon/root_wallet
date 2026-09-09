import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/colors.dart';

/// Canonical solid surface container for Root Wallet.
///
/// In compliance with Root Wallet brand guidelines, surfaces are solid fills
/// with flat 1px borders, without gradients, blurs, or glow effects.
class RootSurface extends StatelessWidget {
  const RootSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(RootRadius.lg);
    final bg = color ?? (isDark ? RootBrandColors.nightPine : Colors.white);
    final outline =
        borderColor ??
        (isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC));

    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(color: outline, width: 1.0),
        ),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

/// Backward-compatibility solid-surface component.
///
/// Formerly provided BackdropFilter and gradient highlights. Now converted to
/// a clean solid brand surface that ignores gradient/glow/blur parameters.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blur = 22,
    this.tint,
    this.borderColor,
    this.shadowColor,
    this.gradientColors,
    this.boxShadow,
    this.highlightOpacity = 0.12,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final BorderRadiusGeometry? borderRadius;
  final Color? tint;
  final Color? borderColor;
  final Color? shadowColor;
  final List<Color>? gradientColors;
  final List<BoxShadow>? boxShadow;
  final double highlightOpacity;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final radius = borderRadius ?? BorderRadius.circular(RootRadius.lg);
    final background =
        tint ?? (isDark ? RootBrandColors.nightPine : Colors.white);
    final outline =
        borderColor ??
        (isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC));

    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: Border.all(color: outline, width: 1.0),
        ),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

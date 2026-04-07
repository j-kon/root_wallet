import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';

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
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg);
    final backgroundTint = tint ?? AppColors.glassSurfaceOf(context);
    final outline = borderColor ?? AppColors.glassBorderOf(context);
    final glow = shadowColor ?? AppColors.glassGlowOf(context);
    final highlight = AppColors.glassHighlightOf(context);
    final softenedHighlight = Color.lerp(
      backgroundTint,
      highlight,
      isDark ? 0.08 : 0.16,
    )!;
    final softenedBase = Color.lerp(
      backgroundTint,
      AppColors.surfaceRaisedOf(context),
      isDark ? 0.04 : 0.10,
    )!;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  gradientColors ??
                  <Color>[
                    softenedHighlight.withValues(alpha: isDark ? 0.90 : 0.97),
                    backgroundTint.withValues(alpha: isDark ? 0.84 : 0.94),
                    softenedBase.withValues(alpha: isDark ? 0.80 : 0.92),
                  ],
            ),
            borderRadius: radius,
            border: Border.all(color: outline),
            boxShadow:
                boxShadow ??
                <BoxShadow>[
                  BoxShadow(
                    color: glow,
                    blurRadius: isDark ? 16 : 14,
                    offset: const Offset(0, 8),
                  ),
                ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -40,
                left: -20,
                right: -20,
                child: IgnorePointer(
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          highlight.withValues(alpha: highlightOpacity + 0.04),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (padding != null)
                Padding(padding: padding!, child: child)
              else
                child,
            ],
          ),
        ),
      ),
    );
  }
}

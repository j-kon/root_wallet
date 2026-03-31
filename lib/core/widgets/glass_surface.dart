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

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg);
    final backgroundTint = tint ?? AppColors.glassSurfaceOf(context);
    final outline = borderColor ?? AppColors.glassBorderOf(context);
    final glow = shadowColor ?? AppColors.glassGlowOf(context);
    final highlight = AppColors.glassHighlightOf(context);

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
                    highlight.withValues(alpha: 0.28),
                    backgroundTint,
                    backgroundTint.withValues(alpha: 0.82),
                  ],
            ),
            borderRadius: radius,
            border: Border.all(color: outline),
            boxShadow:
                boxShadow ??
                <BoxShadow>[
                  BoxShadow(
                    color: glow,
                    blurRadius: 28,
                    offset: const Offset(0, 14),
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
                          highlight.withValues(alpha: 0.22),
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

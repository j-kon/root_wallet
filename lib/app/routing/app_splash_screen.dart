import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';

class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({
    super.key,
    this.statusLabel = 'Preparing secure wallet...',
  });

  final String statusLabel;

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..forward();

  late final Animation<double> _orbDrift = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.82, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _logoReveal = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.10, 0.72, curve: Curves.easeOutBack),
  );

  late final Animation<double> _copyReveal = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.28, 1.0, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final background = AppColors.backgroundOf(context);
    final backgroundTint = Color.lerp(
      background,
      AppColors.backgroundTintOf(context),
      isDark ? 0.52 : 0.68,
    )!;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [background, backgroundTint, background],
                stops: const [0, 0.44, 1],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _orbDrift,
            builder: (context, child) {
              final drift = _orbDrift.value;
              return Stack(
                children: [
                  Positioned(
                    top: -90 + (28 * drift),
                    right: -56 + (12 * drift),
                    child: _SplashOrb(
                      size: 250,
                      color: AppColors.primaryFor(
                        Theme.of(context).brightness,
                      ).withValues(alpha: isDark ? 0.18 : 0.12),
                    ),
                  ),
                  Positioned(
                    top: 110 - (18 * drift),
                    left: -78 + (16 * drift),
                    child: _SplashOrb(
                      size: 230,
                      color: AppColors.accent.withValues(
                        alpha: isDark ? 0.14 : 0.10,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -128 + (20 * drift),
                    right: -34 + (18 * drift),
                    child: _SplashOrb(
                      size: 300,
                      color: AppColors.glassHighlightOf(
                        context,
                      ).withValues(alpha: isDark ? 0.06 : 0.08),
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: FadeTransition(
                  opacity: _copyReveal,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(_copyReveal),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.78,
                              end: 1.0,
                            ).animate(_logoReveal),
                            child: FadeTransition(
                              opacity: _logoReveal,
                              child: _SplashLogo(isDark: isDark),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            AppConstants.appName,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.1,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            AppConstants.appTagline,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: textSecondary, height: 1.5),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          GlassSurface(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            tint: AppColors.glassSurfaceStrongOf(
                              context,
                            ).withValues(alpha: isDark ? 0.56 : 0.90),
                            highlightOpacity: 0.06,
                            shadowColor: AppColors.shadowOf(
                              context,
                            ).withValues(alpha: 0.12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      color: AppColors.primaryOf(context),
                                      size: 18,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Flexible(
                                      child: Text(
                                        widget.statusLabel,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                  child: SizedBox(
                                    width: 220,
                                    child: LinearProgressIndicator(
                                      minHeight: 5,
                                      value: 0.22 + (_copyReveal.value * 0.66),
                                      backgroundColor: AppColors.borderOf(
                                        context,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primaryOf(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryOf(
                    context,
                  ).withValues(alpha: isDark ? 0.22 : 0.18),
                  AppColors.accent.withValues(alpha: isDark ? 0.20 : 0.14),
                ],
              ),
            ),
          ),
          Transform.rotate(
            angle: math.pi / 7,
            child: Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.glassBorderOf(
                    context,
                  ).withValues(alpha: isDark ? 0.40 : 0.80),
                  width: 1.4,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 106,
            height: 106,
            child: GlassSurface(
              borderRadius: BorderRadius.circular(53),
              tint: AppColors.glassSurfaceStrongOf(
                context,
              ).withValues(alpha: isDark ? 0.68 : 0.96),
              shadowColor: AppColors.shadowOf(context).withValues(alpha: 0.18),
              highlightOpacity: 0.07,
              child: Center(
                child: Text(
                  '₿',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.primaryOf(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashOrb extends StatelessWidget {
  const _SplashOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.16),
              blurRadius: size * 0.22,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

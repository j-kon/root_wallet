import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/brand/root_brand_assets.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/brand/root_brand_typography.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/constants/app_constants.dart';

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
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final Animation<double> _logoReveal = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.05, 0.65, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _copyReveal = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final background = isDark
        ? RootBrandColors.charcoalPine
        : RootBrandColors.warmIvory;
    final textPrimary = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final textSecondary = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);
    final cardBg = isDark ? RootBrandColors.nightPine : Colors.white;
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: RootSpacing.xl),
            child: FadeTransition(
              opacity: _copyReveal,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(_copyReveal),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.85,
                          end: 1.0,
                        ).animate(_logoReveal),
                        child: FadeTransition(
                          opacity: _logoReveal,
                          child: _SplashLogo(isDark: isDark),
                        ),
                      ),
                      Text(
                        AppConstants.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                            ),
                      ),
                      const SizedBox(height: RootSpacing.sm),
                      Text(
                        'Own Bitcoin from the root.',
                        textAlign: TextAlign.center,
                        style: RootBrandTypography.h3.copyWith(
                          color: textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: RootSpacing.xxl),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: RootSpacing.lg,
                          vertical: RootSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(RootRadius.lg),
                          border: Border.all(color: cardBorder, width: 1.0),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.shield_outlined,
                                  color: RootBrandColors.pineGreen,
                                  size: 18,
                                ),
                                const SizedBox(width: RootSpacing.xs),
                                Flexible(
                                  child: Text(
                                    widget.statusLabel,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: RootSpacing.sm),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                RootRadius.pill,
                              ),
                              child: SizedBox(
                                width: 200,
                                child: LinearProgressIndicator(
                                  minHeight: 4,
                                  value: 0.30 + (_copyReveal.value * 0.70),
                                  backgroundColor: cardBorder,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        RootBrandColors.pineGreen,
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
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: isDark ? RootBrandColors.nightPine : Colors.white,
        borderRadius: BorderRadius.circular(RootRadius.xl),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(22),
      child: Image.asset(
        RootBrandAssets.rootMarkPineGreen256,
        fit: BoxFit.contain,
      ),
    );
  }
}

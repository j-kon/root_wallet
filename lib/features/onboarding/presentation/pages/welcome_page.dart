import 'package:flutter/material.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_assets.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/brand/root_brand_typography.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final textPrimary = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final textSecondary = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);
    final cardBg = isDark ? RootBrandColors.nightPine : Colors.white;
    final border = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);

    return AppScaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          RootSpacing.lg,
          context.pageHorizontalPadding,
          context.contentBottomSpacing,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card with approved Root Mark and brand narrative
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(
                context.isCompactWidth ? RootSpacing.lg : RootSpacing.xl,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(RootRadius.xl),
                border: Border.all(color: border, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Approved Root Mark
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? RootBrandColors.deepForest
                          : RootBrandColors.warmIvory,
                      borderRadius: BorderRadius.circular(RootRadius.lg),
                      border: Border.all(color: border, width: 1.0),
                    ),
                    child: Image.asset(
                      RootBrandAssets.rootMarkPineGreen256,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: RootSpacing.xl),
                  Text(
                    'ROOT WALLET',
                    style: RootBrandTypography.wordmark.copyWith(
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: RootSpacing.sm),
                  Text(
                    'Own Bitcoin from the root.',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: context.isCompactWidth ? 32 : 36,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -1.0,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: RootSpacing.lg),
                  // Narrative pillars
                  _NarrativePillar(
                    title: 'Self custody.',
                    description:
                        'Your keys, on your device, always under your direct control.',
                    textColor: textPrimary,
                    subColor: textSecondary,
                    isDark: isDark,
                  ),
                  const SizedBox(height: RootSpacing.md),
                  _NarrativePillar(
                    title: 'Higher ground.',
                    description:
                        'No noise, no speculation. Pure sovereign Bitcoin infrastructure.',
                    textColor: textPrimary,
                    subColor: textSecondary,
                    isDark: isDark,
                  ),
                  const SizedBox(height: RootSpacing.md),
                  _NarrativePillar(
                    title: 'A more open tomorrow.',
                    description:
                        'Open protocols and verifiable security for the next century.',
                    textColor: textPrimary,
                    subColor: textSecondary,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: RootSpacing.xl),
            PrimaryButton(
              label: 'Create wallet',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.createWallet),
            ),
            const SizedBox(height: RootSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.restoreWallet),
                child: const Text('Restore wallet'),
              ),
            ),
            const SizedBox(height: RootSpacing.xs),
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.importWatchOnly),
                child: Text(
                  'Import watch-only wallet',
                  style: TextStyle(
                    color: isDark
                        ? RootBrandColors.mutedSage
                        : const Color(0xFF5E6F68),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: RootSpacing.sm),
            Center(
              child: Text(
                'You stay in control of your keys and recovery phrase from day one.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NarrativePillar extends StatelessWidget {
  const _NarrativePillar({
    required this.title,
    required this.description,
    required this.textColor,
    required this.subColor,
    required this.isDark,
  });

  final String title;
  final String description;
  final Color textColor;
  final Color subColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 8, right: RootSpacing.sm),
          decoration: const BoxDecoration(
            color: RootBrandColors.pineGreen,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: subColor, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

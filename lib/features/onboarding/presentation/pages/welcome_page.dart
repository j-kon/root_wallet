import 'package:flutter/material.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          AppSpacing.lg,
          context.pageHorizontalPadding,
          context.contentBottomSpacing,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassSurface(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              tint: AppColors.glassSurfaceStrongOf(
                context,
              ).withValues(alpha: AppColors.isDark(context) ? 0.62 : 0.95),
              highlightOpacity: 0.05,
              padding: EdgeInsets.all(
                context.isCompactWidth ? AppSpacing.md : AppSpacing.lg,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -36,
                    right: -18,
                    child: _WelcomeOrb(
                      size: 150,
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  Positioned(
                    bottom: -44,
                    left: -34,
                    child: _WelcomeOrb(
                      size: 120,
                      color: AppColors.accent.withValues(alpha: 0.12),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.glassSurfaceOf(context).withValues(
                            alpha: AppColors.isDark(context) ? 0.64 : 0.92,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.glassBorderOf(context),
                          ),
                        ),
                        child: const Icon(
                          Icons.currency_bitcoin_rounded,
                          color: AppColors.accent,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: const [
                          _WelcomePill(label: 'Self-custody first'),
                          _WelcomePill(label: 'Biometric lock'),
                          _WelcomePill(label: 'Recovery phrase backup'),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Own your bitcoin with calm confidence.',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.4,
                              height: 1.02,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Create a wallet in minutes, restore from your recovery phrase, and manage funds in a cleaner, more trustworthy interface.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondaryOf(context),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _WelcomeBenefitCard(
              icon: Icons.shield_outlined,
              title: 'Security that feels deliberate',
              description:
                  'PIN protection, biometrics, and backup reminders are surfaced early instead of hidden in settings.',
            ),
            const SizedBox(height: AppSpacing.sm),
            const _WelcomeBenefitCard(
              icon: Icons.bolt_rounded,
              title: 'A wallet built for action',
              description:
                  'Move from receiving, to sending, to reviewing activity without digging through cluttered flows.',
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Create wallet',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.createWallet),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.restoreWallet),
              child: const Text('Restore wallet'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'You stay in control of your keys and recovery phrase from day one.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBenefitCard extends StatelessWidget {
  const _WelcomeBenefitCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      tint: AppColors.glassSurfaceOf(
        context,
      ).withValues(alpha: AppColors.isDark(context) ? 0.58 : 0.95),
      highlightOpacity: 0.05,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePill extends StatelessWidget {
  const _WelcomePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      tint: AppColors.glassSurfaceOf(
        context,
      ).withValues(alpha: AppColors.isDark(context) ? 0.52 : 0.88),
      borderColor: AppColors.glassBorderOf(context).withValues(alpha: 0.72),
      shadowColor: Colors.transparent,
      highlightOpacity: 0.03,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimaryOf(context),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WelcomeOrb extends StatelessWidget {
  const _WelcomeOrb({required this.size, required this.color});

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
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

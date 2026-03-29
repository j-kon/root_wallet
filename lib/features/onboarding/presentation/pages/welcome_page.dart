import 'package:flutter/material.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.secondary, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 20,
                    offset: Offset(0, 12),
                  ),
                ],
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
                Chip(label: Text('Self-custody first')),
                Chip(label: Text('Biometric lock')),
                Chip(label: Text('Recovery phrase backup')),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Own your bitcoin with calm confidence.',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
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
                color: AppColors.textSecondary,
                height: 1.45,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
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
                    color: AppColors.textSecondary,
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

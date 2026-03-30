import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class CreateWalletPage extends ConsumerWidget {
  const CreateWalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final shadow = AppColors.shadowOf(context);

    return AppScaffold(
      title: 'Create Wallet',
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          AppSpacing.md,
          context.pageHorizontalPadding,
          AppSpacing.sm,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      context.isCompactWidth ? AppSpacing.md : AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.secondary,
                          AppColors.primaryDeep,
                          AppColors.primary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: shadow,
                          blurRadius: 24,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FlowBadge(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Fresh wallet setup',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Create a new wallet identity with a safer first-run flow.',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'We will generate a new recovery phrase locally, then guide you through backup before first receive.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _CreateRestorePanel(
                    title: 'What happens next',
                    subtitle:
                        'A short, security-first flow keeps the setup intentional.',
                    child: const Column(
                      children: [
                        _FlowStep(
                          icon: Icons.vpn_key_outlined,
                          title: 'Generate phrase',
                          message:
                              'A new recovery phrase is created on-device for this wallet.',
                        ),
                        SizedBox(height: AppSpacing.sm),
                        _FlowStep(
                          icon: Icons.visibility_outlined,
                          title: 'Review backup',
                          message:
                              'You will immediately verify and store the phrase offline.',
                        ),
                        SizedBox(height: AppSpacing.sm),
                        _FlowStep(
                          icon: Icons.shield_outlined,
                          title: 'Secure before use',
                          message:
                              'The backup step happens before regular wallet activity resumes.',
                        ),
                      ],
                    ),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    InfoBanner(
                      type: InfoBannerType.error,
                      message: state.errorMessage!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: state.isBusy ? 'Creating...' : 'Create wallet',
              onPressed: () async {
                final created = await controller.createWallet();
                if (!context.mounted) {
                  return;
                }

                if (!created) {
                  return;
                }
                Navigator.of(context).pushReplacementNamed(
                  AppRoutes.backupSeed,
                  arguments: const BackupSeedPageArgs(
                    requireReauth: false,
                    isOnboardingFlow: true,
                  ),
                );
              },
            ),
            SizedBox(height: context.navBarBottomSpacing),
          ],
        ),
      ),
    );
  }
}

class _CreateRestorePanel extends StatelessWidget {
  const _CreateRestorePanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surfaceOf(context);
    final border = AppColors.borderOf(context);
    final shadow = AppColors.shadowOf(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
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
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(message, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _FlowBadge extends StatelessWidget {
  const _FlowBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

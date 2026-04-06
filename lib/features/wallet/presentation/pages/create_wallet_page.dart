import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
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

    return AppScaffold(
      title: 'Create wallet',
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
                  GlassSurface(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    tint: AppColors.glassSurfaceStrongOf(context).withValues(
                      alpha: AppColors.isDark(context) ? 0.62 : 0.95,
                    ),
                    highlightOpacity: 0.05,
                    padding: EdgeInsets.all(
                      context.isCompactWidth ? AppSpacing.md : AppSpacing.lg,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -34,
                          right: -20,
                          child: _FlowOrb(
                            size: 140,
                            color: AppColors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        Positioned(
                          bottom: -40,
                          left: -34,
                          child: _FlowOrb(
                            size: 110,
                            color: AppColors.accent.withValues(alpha: 0.12),
                          ),
                        ),
                        Column(
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
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'We will generate a new recovery phrase locally, then guide you through backup before first receive.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
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
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      tint: AppColors.glassSurfaceOf(
        context,
      ).withValues(alpha: AppColors.isDark(context) ? 0.58 : 0.95),
      highlightOpacity: 0.05,
      padding: const EdgeInsets.all(AppSpacing.md),
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
    final maxWidth = context.isVeryCompactWidth
        ? 184.0
        : context.isCompactWidth
        ? 224.0
        : 260.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GlassSurface(
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryOf(context)),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w700,
                  fontSize: context.isVeryCompactWidth ? 11.5 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowOrb extends StatelessWidget {
  const _FlowOrb({required this.size, required this.color});

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

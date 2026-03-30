import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class RestoreWalletPage extends ConsumerStatefulWidget {
  const RestoreWalletPage({super.key});

  @override
  ConsumerState<RestoreWalletPage> createState() => _RestoreWalletPageState();
}

class _RestoreWalletPageState extends ConsumerState<RestoreWalletPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final shadow = AppColors.shadowOf(context);

    return AppScaffold(
      title: 'Restore Wallet',
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
                          icon: Icons.restore_rounded,
                          label: 'Recovery flow',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Restore an existing wallet with a careful import flow.',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Paste your recovery phrase exactly as written. This app will validate it locally before resuming wallet access.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _RestorePanel(
                    title: 'Recovery phrase',
                    subtitle:
                        'Use spaces between words and keep the original word order.',
                    child: TextField(
                      controller: _controller,
                      minLines: 4,
                      maxLines: 6,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Recovery phrase',
                        hintText: 'abandon ability able about above ...',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const InfoBanner(
                    type: InfoBannerType.warning,
                    message:
                        'Only restore a phrase you trust and never share it with anyone. The phrase controls wallet access.',
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
              label: state.isBusy ? 'Restoring...' : 'Restore wallet',
              onPressed: () async {
                final phrase = _controller.text.trim();
                if (phrase.isEmpty) {
                  return;
                }

                final restored = await controller.restoreWallet(phrase);
                if (!context.mounted) {
                  return;
                }
                if (!restored) {
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

class _RestorePanel extends StatelessWidget {
  const _RestorePanel({
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

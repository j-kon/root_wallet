import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class ConfirmSeedPage extends ConsumerStatefulWidget {
  const ConfirmSeedPage({super.key});

  @override
  ConsumerState<ConfirmSeedPage> createState() => _ConfirmSeedPageState();
}

class _ConfirmSeedPageState extends ConsumerState<ConfirmSeedPage> {
  final Map<int, String> _answers = <int, String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onboardingControllerProvider.notifier).prepareSeedChallenge();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return AppScaffold(
      title: 'Confirm recovery phrase',
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          AppSpacing.md,
          context.pageHorizontalPadding,
          AppSpacing.sm,
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
                    top: -34,
                    right: -20,
                    child: _SeedOrb(
                      size: 136,
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    left: -34,
                    child: _SeedOrb(
                      size: 108,
                      color: AppColors.accent.withValues(alpha: 0.12),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SeedBadge(
                        icon: Icons.fact_check_outlined,
                        label: 'Backup verification',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Enter the requested words to confirm you backed up your phrase.',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'This confirmation step helps prevent incomplete backups before you enter the wallet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.errorMessage != null) ...[
              InfoBanner(
                type: InfoBannerType.error,
                message: state.errorMessage!,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (state.challengeIndices.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: ListView(
                  children: [
                    for (final index in state.challengeIndices) ...[
                      GlassSurface(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        tint: AppColors.glassSurfaceOf(context).withValues(
                          alpha: AppColors.isDark(context) ? 0.58 : 0.95,
                        ),
                        highlightOpacity: 0.05,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Word #$index',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Type the exact word from your recovery phrase.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              autocorrect: false,
                              textCapitalization: TextCapitalization.none,
                              decoration: InputDecoration(
                                labelText: 'Seed word #$index',
                              ),
                              onChanged: (value) {
                                _answers[index] = value.trim();
                                controller.clearError();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: state.isBusy ? 'Confirming...' : 'Confirm backup',
              onPressed: state.isBusy || state.challengeIndices.isEmpty
                  ? null
                  : () async {
                      final confirmed = await controller.confirmBackup(
                        _answers,
                      );
                      if (!confirmed || !context.mounted) {
                        return;
                      }

                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.walletHome,
                        (route) => false,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _SeedBadge extends StatelessWidget {
  const _SeedBadge({required this.icon, required this.label});

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

class _SeedOrb extends StatelessWidget {
  const _SeedOrb({required this.size, required this.color});

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

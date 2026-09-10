import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
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
    final isDark = AppColors.isDark(context);

    return AppScaffold(
      title: 'Confirm recovery phrase',
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          RootSpacing.md,
          context.pageHorizontalPadding,
          RootSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Solid Header Verification Card
            Container(
              decoration: BoxDecoration(
                color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
                borderRadius: BorderRadius.circular(RootRadius.lg),
                border: Border.all(
                  color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                  width: 1.0,
                ),
              ),
              padding: EdgeInsets.all(
                context.isCompactWidth ? RootSpacing.md : RootSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: RootBrandColors.pineGreen.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(RootRadius.md),
                          border: Border.all(
                            color: RootBrandColors.pineGreen.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        child: const Icon(
                          Icons.fact_check_outlined,
                          size: 22,
                          color: RootBrandColors.pineGreen,
                        ),
                      ),
                      const SizedBox(width: RootSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Backup verification',
                              style: TextStyle(
                                color: RootBrandColors.pineGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter the requested words to confirm you backed up your phrase.',
                              style: TextStyle(
                                color: isDark
                                    ? RootBrandColors.warmIvory
                                    : RootBrandColors.charcoalPine,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'This confirmation step helps prevent incomplete backups before you enter the wallet.',
                              style: TextStyle(
                                color: isDark
                                    ? RootBrandColors.mutedSage
                                    : const Color(0xFF5E6F68),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: RootSpacing.md),

            if (state.errorMessage != null) ...[
              InfoBanner(
                type: InfoBannerType.error,
                message: state.errorMessage!,
              ),
              const SizedBox(height: RootSpacing.md),
            ],

            if (state.challengeIndices.isEmpty)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    for (final index in state.challengeIndices) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? RootBrandColors.nightPine
                              : RootBrandColors.pureWhite,
                          borderRadius: BorderRadius.circular(RootRadius.lg),
                          border: Border.all(
                            color: isDark
                                ? RootBrandColors.borderPine
                                : const Color(0xFFD7E3DC),
                            width: 1.0,
                          ),
                        ),
                        padding: const EdgeInsets.all(RootSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RootBrandColors.pineGreen
                                        .withValues(alpha: 0.14),
                                    borderRadius:
                                        BorderRadius.circular(RootRadius.sm),
                                  ),
                                  child: Text(
                                    '#$index',
                                    style: const TextStyle(
                                      color: RootBrandColors.pineGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Word #$index',
                                  style: TextStyle(
                                    color: isDark
                                        ? RootBrandColors.warmIvory
                                        : RootBrandColors.charcoalPine,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Type the exact word from your recovery phrase.',
                              style: TextStyle(
                                color: isDark
                                    ? RootBrandColors.mutedSage
                                    : const Color(0xFF5E6F68),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: RootSpacing.md),
                            TextField(
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.none,
                              style: TextStyle(
                                color: isDark
                                    ? RootBrandColors.warmIvory
                                    : RootBrandColors.charcoalPine,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Seed word #$index',
                                hintText: 'Enter word',
                                filled: true,
                                fillColor: isDark
                                    ? RootBrandColors.slatePine
                                    : const Color(0xFFF6F8F7),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(RootRadius.md),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? RootBrandColors.borderPine
                                        : const Color(0xFFD7E3DC),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(RootRadius.md),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? RootBrandColors.borderPine
                                        : const Color(0xFFD7E3DC),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(RootRadius.md),
                                  borderSide: const BorderSide(
                                    color: RootBrandColors.pineGreen,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                _answers[index] = value.trim();
                                controller.clearError();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: RootSpacing.md),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: RootSpacing.md),

            MagneticPressable(
              onTap: state.isBusy || state.challengeIndices.isEmpty
                  ? null
                  : () async {
                      HapticFeedback.mediumImpact();
                      final confirmed = await controller.confirmBackup(
                        _answers,
                      );
                      if (!confirmed || !context.mounted) return;

                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.walletHome,
                        (route) => false,
                      );
                    },
              child: PrimaryButton(
                label: state.isBusy ? 'Confirming...' : 'Confirm backup',
                onPressed: state.isBusy || state.challengeIndices.isEmpty
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        final confirmed = await controller.confirmBackup(
                          _answers,
                        );
                        if (!confirmed || !context.mounted) return;

                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.walletHome,
                          (route) => false,
                        );
                      },
              ),
            ),
            SizedBox(height: context.navBarBottomSpacing),
          ],
        ),
      ),
    );
  }
}

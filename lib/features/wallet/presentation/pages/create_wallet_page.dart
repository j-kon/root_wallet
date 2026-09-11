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
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page_args.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/script_type_option.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class CreateWalletPage extends ConsumerStatefulWidget {
  const CreateWalletPage({super.key, this.isAddWallet = false});

  final bool isAddWallet;

  @override
  ConsumerState<CreateWalletPage> createState() => _CreateWalletPageState();
}

class _CreateWalletPageState extends ConsumerState<CreateWalletPage> {
  WalletScriptType _scriptType = WalletScriptType.nativeSegwit;
  bool _isBusy = false;
  String? _errorMessage;

  Future<void> _handleCreateWallet() async {
    HapticFeedback.mediumImpact();
    final registry = await ref.read(walletRegistryProvider.future);
    final hasExisting = registry.getWallets().isNotEmpty;
    final isAdding = widget.isAddWallet || hasExisting;

    if (isAdding) {
      setState(() {
        _isBusy = true;
        _errorMessage = null;
      });
      try {
        final addWalletService = await ref.read(addWalletServiceProvider.future);
        final result = await addWalletService.createWallet(scriptType: _scriptType);
        ref.invalidate(walletCapabilityProvider);
        ref.invalidate(walletHomeControllerProvider);
        await ref.read(walletsListProvider.notifier).refresh();

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.backupSeed,
          arguments: BackupSeedPageArgs(
            requireReauth: false,
            isOnboardingFlow: false,
            recoveryPhrase: result.recoveryPhrase,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isBusy = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } else {
      final controller = ref.read(onboardingControllerProvider.notifier);
      final created = await controller.createWallet(
        scriptType: _scriptType,
      );
      if (!mounted) return;
      if (!created) return;

      final recoveryPhrase = ref
          .read(onboardingControllerProvider)
          .recoveryPhrase;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.backupSeed,
        arguments: BackupSeedPageArgs(
          requireReauth: false,
          isOnboardingFlow: true,
          recoveryPhrase: recoveryPhrase,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final isDark = AppColors.isDark(context);
    final isBusy = state.isBusy || _isBusy;
    final errorMessage = _errorMessage ?? state.errorMessage;

    return AppScaffold(
      title: 'Create wallet',
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          RootSpacing.md,
          context.pageHorizontalPadding,
          RootSpacing.sm,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // 1. Fresh Wallet Setup Hero Card
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
                                color: RootBrandColors.pineGreen
                                    .withValues(alpha: 0.14),
                                borderRadius:
                                    BorderRadius.circular(RootRadius.md),
                                border: Border.all(
                                  color: RootBrandColors.pineGreen
                                      .withValues(alpha: 0.35),
                                  width: 1.0,
                                ),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
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
                                    'Fresh wallet setup',
                                    style: TextStyle(
                                      color: RootBrandColors.pineGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Create a new wallet identity with a safer first-run flow.',
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
                                    'We will generate a new recovery phrase locally, then guide you through backup before first receive.',
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

                  // 2. What Happens Next Step Flow Panel
                  _CreateRestorePanel(
                    title: 'What happens next',
                    subtitle:
                        'A short, security-first flow keeps the setup intentional.',
                    child: Column(
                      children: const [
                        _FlowStep(
                          icon: Icons.vpn_key_outlined,
                          title: 'Generate phrase',
                          message:
                              'A new recovery phrase is created on-device for this wallet.',
                        ),
                        SizedBox(height: RootSpacing.sm),
                        _FlowStep(
                          icon: Icons.visibility_outlined,
                          title: 'Review backup',
                          message:
                              'You will immediately verify and store the phrase offline.',
                        ),
                        SizedBox(height: RootSpacing.sm),
                        _FlowStep(
                          icon: Icons.shield_outlined,
                          title: 'Secure before use',
                          message:
                              'The backup step happens before regular wallet activity resumes.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: RootSpacing.md),

                  // 3. Address Type Selection Panel
                  _CreateRestorePanel(
                    title: 'Address type',
                    subtitle:
                        'Pick the address family you want to use. Taproot is recommended for modern features.',
                    child: Column(
                      children: WalletScriptType.values
                          .map(
                            (type) => ScriptTypeOption(
                              type: type,
                              isSelected: _scriptType == type,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _scriptType = type);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),

                  if (errorMessage != null) ...[
                    const SizedBox(height: RootSpacing.md),
                    InfoBanner(
                      type: InfoBannerType.error,
                      message: errorMessage,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: RootSpacing.md),

            MagneticPressable(
              onTap: isBusy ? null : _handleCreateWallet,
              child: PrimaryButton(
                label: isBusy ? 'Creating...' : 'Create wallet',
                onPressed: isBusy ? null : _handleCreateWallet,
              ),
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
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(RootSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: RootSpacing.md),
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
    final isDark = AppColors.isDark(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? RootBrandColors.slatePine : const Color(0xFFE8EFEA),
            borderRadius: BorderRadius.circular(RootRadius.md),
            border: Border.all(
              color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
              width: 1.0,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
          ),
        ),
        const SizedBox(width: RootSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark
                      ? RootBrandColors.warmIvory
                      : RootBrandColors.charcoalPine,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: TextStyle(
                  color: isDark
                      ? RootBrandColors.mutedSage
                      : const Color(0xFF5E6F68),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

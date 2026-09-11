import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';

class AddWalletPage extends ConsumerWidget {
  const AddWalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppColors.isDark(context);
    final textPrimary = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final textSecondary = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);
    final cardBg = isDark ? RootBrandColors.slatePine : Colors.white;
    final borderColor = isDark
        ? RootBrandColors.borderPine
        : RootBrandColors.charcoalPine.withValues(alpha: 0.12);

    return AppScaffold(
      title: 'Add Wallet',
      body: ListView(
        padding: const EdgeInsets.all(RootSpacing.lg),
        children: [
          Text(
            'Choose how you want to add a wallet to Root Wallet.',
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: RootSpacing.lg),
          _buildOptionCard(
            context: context,
            key: const ValueKey('add_wallet_create_btn'),
            icon: Icons.add_circle_outline_rounded,
            title: 'Create New Wallet',
            description:
                'Generate a fresh 12-word seed phrase and start with a brand new on-chain wallet.',
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () {
              Navigator.of(context).pushNamed(
                AppRoutes.createWallet,
                arguments: true,
              );
            },
          ),
          const SizedBox(height: RootSpacing.md),
          _buildOptionCard(
            context: context,
            key: const ValueKey('add_wallet_restore_btn'),
            icon: Icons.restore_rounded,
            title: 'Restore Wallet',
            description:
                'Import an existing Bitcoin wallet using your 12 or 24-word recovery phrase.',
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () {
              Navigator.of(context).pushNamed(
                AppRoutes.restoreWallet,
                arguments: true,
              );
            },
          ),
          const SizedBox(height: RootSpacing.md),
          _buildOptionCard(
            context: context,
            key: const ValueKey('add_wallet_watch_only_btn'),
            icon: Icons.visibility_outlined,
            title: 'Import Watch-Only Wallet',
            description:
                'Track balances, view transactions, and construct PSBTs safely using public descriptors without private keys.',
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            badge: 'PUBLIC KEYS ONLY',
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.importWatchOnly);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required Key key,
    required IconData icon,
    required String title,
    required String description,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(RootRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(RootSpacing.lg),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(RootRadius.lg),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: RootBrandColors.pineGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(RootRadius.md),
              ),
              child: Icon(
                icon,
                color: RootBrandColors.pineGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: RootSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: RootBrandColors.amberAccent
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(RootRadius.xs),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: RootBrandColors.amberAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: RootSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              color: textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

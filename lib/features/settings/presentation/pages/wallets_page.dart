import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/features/settings/presentation/pages/wallet_details_page.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

class WalletsPage extends ConsumerWidget {
  const WalletsPage({super.key});

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

    final walletsAsync = ref.watch(walletsListProvider);

    return AppScaffold(
      title: 'Wallets',
      actions: [
        IconButton(
          key: const ValueKey('wallets_page_add_btn'),
          icon: const Icon(Icons.add_rounded),
          tooltip: 'Add Wallet',
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.addWallet),
        ),
      ],
      body: walletsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(RootSpacing.xl),
            child: Text(
              'Failed to load wallets: $e',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
        data: (wallets) {
          if (wallets.isEmpty) {
            return Center(
              child: Text(
                'No wallets registered.',
                style: TextStyle(color: textSecondary),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(RootSpacing.lg),
            itemCount: wallets.length,
            separatorBuilder: (_, __) => const SizedBox(height: RootSpacing.md),
            itemBuilder: (context, index) {
              final wallet = wallets[index];
              final isSelected = wallet.isActive;

              return InkWell(
                key: ValueKey('manage_wallet_tile_${wallet.id}'),
                borderRadius: BorderRadius.circular(RootRadius.lg),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.walletDetails,
                    arguments: WalletDetailsArgs(wallet: wallet),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(RootSpacing.md),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? RootBrandColors.pineGreen.withValues(alpha: 0.15)
                            : RootBrandColors.pineGreen.withValues(alpha: 0.08))
                        : cardBg,
                    borderRadius: BorderRadius.circular(RootRadius.lg),
                    border: Border.all(
                      color: isSelected
                          ? RootBrandColors.pineGreen
                          : borderColor,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? RootBrandColors.pineGreen
                              : (isDark
                                  ? RootBrandColors.borderPine
                                  : RootBrandColors.charcoalPine.withValues(alpha: 0.06)),
                          borderRadius: BorderRadius.circular(RootRadius.md),
                        ),
                        child: Icon(
                          wallet.isWatchOnly
                              ? Icons.visibility_outlined
                              : Icons.account_balance_wallet_outlined,
                          color: isSelected ? Colors.white : textSecondary,
                          size: 22,
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
                                    wallet.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: RootBrandColors.pineGreen
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(
                                        RootRadius.xs,
                                      ),
                                    ),
                                    child: const Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: RootBrandColors.pineGreen,
                                      ),
                                    ),
                                  ),
                                ],
                                if (wallet.isWatchOnly) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: RootBrandColors.amberAccent
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(
                                        RootRadius.xs,
                                      ),
                                    ),
                                    child: const Text(
                                      'WATCH ONLY',
                                      style: TextStyle(
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
                            const SizedBox(height: 4),
                            Text(
                              '${wallet.scriptType.displayName}${wallet.fingerprint != null ? ' • ${wallet.fingerprint}' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: textSecondary,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

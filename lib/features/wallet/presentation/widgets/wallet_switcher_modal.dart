import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

class WalletSwitcherModal extends ConsumerWidget {
  const WalletSwitcherModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WalletSwitcherModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppColors.isDark(context);
    final bg = isDark ? RootBrandColors.nightPine : RootBrandColors.warmIvory;
    final cardBg = isDark ? RootBrandColors.slatePine : Colors.white;
    final textPrimary = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final textSecondary = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);
    final borderColor = isDark
        ? RootBrandColors.borderPine
        : RootBrandColors.charcoalPine.withValues(alpha: 0.12);

    final walletsAsync = ref.watch(walletsListProvider);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      padding: EdgeInsets.only(
        top: RootSpacing.md,
        left: RootSpacing.lg,
        right: RootSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + RootSpacing.xl,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: RootSpacing.md),
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(RootRadius.pill),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Wallets',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: RootSpacing.sm),
            walletsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(RootSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(RootSpacing.md),
                child: Text(
                  'Error loading wallets: $e',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              data: (wallets) {
                if (wallets.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(RootSpacing.lg),
                    child: Center(
                      child: Text(
                        'No wallets registered.',
                        style: TextStyle(color: textSecondary),
                      ),
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: wallets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: RootSpacing.sm),
                    itemBuilder: (context, index) {
                      final wallet = wallets[index];
                      final isSelected = wallet.isActive;

                      return InkWell(
                        key: ValueKey('wallet_tile_${wallet.id}'),
                        borderRadius: BorderRadius.circular(RootRadius.lg),
                        onTap: isSelected
                            ? null
                            : () async {
                                await ref
                                    .read(activeWalletIdProvider.notifier)
                                    .setActiveWallet(wallet.id);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
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
                                width: 40,
                                height: 40,
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
                                  color: isSelected
                                      ? Colors.white
                                      : textSecondary,
                                  size: 20,
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
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
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
                                              border: Border.all(
                                                color: RootBrandColors.amberAccent
                                                    .withValues(alpha: 0.4),
                                                width: 0.5,
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
                                    Row(
                                      children: [
                                        Text(
                                          wallet.scriptType.displayName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textSecondary,
                                          ),
                                        ),
                                        if (wallet.fingerprint != null && wallet.fingerprint!.isNotEmpty) ...[
                                          Text(
                                            ' • ',
                                            style: TextStyle(color: textSecondary),
                                          ),
                                          Text(
                                            wallet.fingerprint!,
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                              letterSpacing: 0.5,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: RootBrandColors.pineGreen,
                                  size: 22,
                                )
                              else
                                Icon(
                                  Icons.radio_button_unchecked_rounded,
                                  color: textSecondary.withValues(alpha: 0.4),
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: RootSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('wallet_switcher_manage_btn'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(AppRoutes.wallets);
                    },
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Manage'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RootRadius.lg),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: RootSpacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const ValueKey('wallet_switcher_add_btn'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(AppRoutes.addWallet);
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Wallet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RootBrandColors.pineGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RootRadius.lg),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

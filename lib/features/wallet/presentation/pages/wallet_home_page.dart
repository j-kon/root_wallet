import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/features/rates/presentation/providers/rates_providers.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/balance_card.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/tx_list.dart';
import 'package:root_wallet/shared/widgets/primary_action_button.dart';
import 'package:root_wallet/shared/widgets/section_header.dart';

class WalletHomePage extends ConsumerWidget {
  const WalletHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletControllerProvider);
    final env = ref.watch(appEnvProvider);
    final btcNgnRate = ref.watch(btcNgnRateProvider);
    final networkLabel = env.isProduction ? 'Mainnet' : 'Testnet';

    return AppScaffold(
      title: 'Wallet',
      actions: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              networkLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
          icon: const Icon(Icons.settings),
        ),
      ],
      body: walletState.when(
        loading: () => const Loading(label: 'Loading wallet...'),
        error: (error, _) {
          return EmptyState(
            title: 'Could not load wallet',
            message: 'Could not load wallet: $error',
            actionLabel: 'Retry',
            onAction: () =>
                ref.read(walletControllerProvider.notifier).refresh(),
            icon: Icons.wallet_outlined,
          );
        },
        data: (data) {
          final fiatLabel = btcNgnRate.when(
            data: (rate) =>
                '≈ ${AppFormatters.ngn(data.balance.btc * rate.value)}',
            loading: () => '≈ NGN -- (TODO: rate)',
            error: (_, _) => '≈ NGN -- (TODO: rate)',
          );

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BalanceCard(balance: data.balance, fiatAmountLabel: fiatLabel),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryActionButton(
                        icon: Icons.call_received_rounded,
                        label: 'Receive',
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRoutes.receive),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: PrimaryActionButton(
                        icon: Icons.send_rounded,
                        label: 'Send',
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRoutes.send),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: 'Activity',
                  trailing: IconButton(
                    onPressed: () =>
                        ref.read(walletControllerProvider.notifier).refresh(),
                    tooltip: 'Refresh activity',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Expanded(child: TxList(items: data.transactions)),
              ],
            ),
          );
        },
      ),
    );
  }
}

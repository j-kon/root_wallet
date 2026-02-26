import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/errors/error_mapper.dart';
import 'package:root_wallet/core/utils/date_time.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/features/rates/presentation/providers/rates_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/balance_card.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/tx_list.dart';
import 'package:root_wallet/shared/widgets/primary_action_button.dart';
import 'package:root_wallet/shared/widgets/section_header.dart';

class WalletHomePage extends ConsumerWidget {
  const WalletHomePage({
    super.key,
    this.onReceiveRequested,
    this.onSendRequested,
    this.onSettingsRequested,
  });

  final VoidCallback? onReceiveRequested;
  final VoidCallback? onSendRequested;
  final VoidCallback? onSettingsRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletHomeControllerProvider);
    final walletController = ref.read(walletHomeControllerProvider.notifier);
    final backupConfirmed = ref.watch(backupReminderProvider);
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
          onPressed:
              onSettingsRequested ??
              () => Navigator.of(context).pushNamed(AppRoutes.settings),
          icon: const Icon(Icons.settings),
        ),
      ],
      body: walletState.when(
        loading: () => const Loading(label: 'Loading wallet...'),
        error: (error, _) {
          final message = mapErrorToMessage(
            error,
            context: ErrorContext.sync,
            includeDebugDetails: !env.isProduction,
          );
          return EmptyState(
            title: 'Could not load wallet',
            message: message,
            actionLabel: 'Retry',
            onAction: walletController.refresh,
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

          return RefreshIndicator(
            onRefresh: () => walletController.sync(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sync_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            AppDateTime.updatedAgo(data.lastSyncedAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Sync now',
                          onPressed: () => walletController.sync(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                  if (backupConfirmed.valueOrNull == false) ...[
                    const SizedBox(height: AppSpacing.md),
                    InfoBanner(
                      type: InfoBannerType.warning,
                      message:
                          'Back up your recovery phrase to secure your funds.',
                      icon: Icons.shield_outlined,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pushNamed(
                          AppRoutes.backupSeed,
                          arguments: const BackupSeedPageArgs(
                            requireReauth: true,
                            isOnboardingFlow: false,
                          ),
                        ),
                        child: const Text('Back up now'),
                      ),
                    ),
                  ],
                  if (data.isOffline) ...[
                    const SizedBox(height: AppSpacing.md),
                    InfoBanner(
                      type: InfoBannerType.warning,
                      message:
                          'Offline. Showing last updated data from ${AppDateTime.ymdHm(data.lastSyncedAt)}.',
                      icon: Icons.wifi_off_rounded,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  BalanceCard(
                    balance: data.balance,
                    fiatAmountLabel: fiatLabel,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryActionButton(
                          icon: Icons.call_received_rounded,
                          label: 'Receive',
                          onTap:
                              onReceiveRequested ??
                              () => Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.receive),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PrimaryActionButton(
                          icon: Icons.send_rounded,
                          label: 'Send',
                          onTap:
                              onSendRequested ??
                              () => Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.send),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(title: 'Activity'),
                  const SizedBox(height: AppSpacing.xs),
                  TxList(
                    items: data.transactions,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onItemTap: (tx) {
                      Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.transactionDetails, arguments: tx);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

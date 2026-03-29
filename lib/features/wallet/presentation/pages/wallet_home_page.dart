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
    final isBackupConfirmed = backupConfirmed.valueOrNull ?? false;
    const networkLabel = 'Testnet';

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
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              networkLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.brown.shade800,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed:
              onSettingsRequested ??
              () => Navigator.of(context).pushNamed(AppRoutes.settings),
          icon: const Icon(Icons.settings_outlined),
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
            loading: () => 'FX rate syncing...',
            error: (_, _) => 'FX rate unavailable',
          );
          final marketLabel = btcNgnRate.when(
            data: (rate) => '1 BTC ${AppFormatters.ngn(rate.value)}',
            loading: () => 'Market data loading',
            error: (_, _) => 'Market data unavailable',
          );
          final activitySummary = data.transactions.isEmpty
              ? 'Ready for your first transaction'
              : '${data.transactions.length} transaction${data.transactions.length == 1 ? '' : 's'} tracked';

          return RefreshIndicator(
            onRefresh: () => walletController.sync(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  'Self-custody dashboard',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your bitcoin, clear and in control.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _WalletStatusChip(
                      icon: Icons.sync_rounded,
                      label: AppDateTime.updatedAgo(data.lastSyncedAt),
                    ),
                    const _WalletStatusChip(
                      icon: Icons.language_rounded,
                      label: networkLabel,
                    ),
                    _WalletStatusChip(
                      icon: Icons.currency_exchange_rounded,
                      label: marketLabel,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                BalanceCard(
                  balance: data.balance,
                  fiatAmountLabel: fiatLabel,
                  subtitle: data.isOffline
                      ? 'Cached portfolio balance'
                      : 'Available portfolio balance',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryActionButton(
                        icon: Icons.call_received_rounded,
                        label: 'Receive',
                        subtitle: 'Share an address',
                        accentColor: AppColors.success,
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
                        subtitle: 'Move funds out',
                        accentColor: AppColors.warning,
                        onTap:
                            onSendRequested ??
                            () =>
                                Navigator.of(context).pushNamed(AppRoutes.send),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _WalletAttentionCard(
                  icon: isBackupConfirmed
                      ? Icons.verified_user_outlined
                      : Icons.shield_outlined,
                  title: isBackupConfirmed
                      ? 'Recovery phrase secured'
                      : 'Secure your recovery phrase',
                  message: isBackupConfirmed
                      ? 'Your backup reminder is complete. Keep your phrase stored offline and private.'
                      : 'A backup is still outstanding. Completing it now is the single best way to protect access to your wallet.',
                  actionLabel: isBackupConfirmed
                      ? 'Review phrase'
                      : 'Back up now',
                  action: () => Navigator.of(context).pushNamed(
                    AppRoutes.backupSeed,
                    arguments: const BackupSeedPageArgs(
                      requireReauth: true,
                      isOnboardingFlow: false,
                    ),
                  ),
                  tone: isBackupConfirmed
                      ? AppColors.success
                      : AppColors.warning,
                ),
                if (data.isOffline) ...[
                  const SizedBox(height: AppSpacing.md),
                  InfoBanner(
                    type: InfoBannerType.warning,
                    message:
                        'Offline mode. Showing cached wallet data from ${AppDateTime.ymdHm(data.lastSyncedAt)}.',
                    icon: Icons.wifi_off_rounded,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: 'Recent activity',
                  trailing: Text(
                    activitySummary,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
          );
        },
      ),
    );
  }
}

class _WalletStatusChip extends StatelessWidget {
  const _WalletStatusChip({required this.icon, required this.label});

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
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletAttentionCard extends StatelessWidget {
  const _WalletAttentionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.action,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback action;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tone.withValues(alpha: 0.20)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: tone),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(onPressed: action, child: Text(actionLabel)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

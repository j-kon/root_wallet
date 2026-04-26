import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/errors/error_mapper.dart';
import 'package:root_wallet/core/utils/date_time.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/features/rates/presentation/providers/rates_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/balance_card.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/tx_list.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';
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
    final isDark = AppColors.isDark(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final walletState = ref.watch(walletHomeControllerProvider);
    final walletController = ref.read(walletHomeControllerProvider.notifier);
    final backupConfirmed = ref.watch(backupReminderProvider);
    final hideBalances = ref.watch(balancePrivacyProvider).valueOrNull ?? false;
    final env = ref.watch(appEnvProvider);
    final now = ref.watch(dateTimeNowProvider)();
    final btcNgnRate = ref.watch(btcNgnRateProvider);
    final walletLabels = ref.watch(walletLabelsControllerProvider);
    final isBackupConfirmed = backupConfirmed.valueOrNull ?? false;
    const networkLabel = AppConstants.networkDisplayName;

    return AppScaffold(
      title: 'Wallet',
      actions: [
        IconButton(
          onPressed: walletState.valueOrNull?.isSyncing == true
              ? null
              : walletController.refresh,
          tooltip: 'Refresh wallet',
          icon: Icon(
            walletState.valueOrNull?.isSyncing == true
                ? Icons.sync_rounded
                : Icons.refresh_rounded,
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              tint: AppColors.warning.withValues(alpha: isDark ? 0.10 : 0.08),
              borderColor: AppColors.warning.withValues(
                alpha: isDark ? 0.26 : 0.18,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              child: Text(
                networkLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? const Color(0xFFFFD48B)
                      : Colors.brown.shade800,
                  fontWeight: FontWeight.w700,
                ),
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
            error: (error, stackTrace) => 'FX rate unavailable',
          );
          final marketLabel = btcNgnRate.when(
            data: (rate) => '1 BTC ${AppFormatters.ngnCompact(rate.value)}',
            loading: () => 'Market data loading',
            error: (error, stackTrace) => 'Market data unavailable',
          );
          final activitySummary = data.transactions.isEmpty
              ? 'Ready for your first transaction'
              : '${data.transactions.length} transaction${data.transactions.length == 1 ? '' : 's'} tracked';
          final syncChipLabel = data.isSyncing
              ? 'Syncing testnet...'
              : data.isOffline
              ? 'Cached ${AppDateTime.updatedAgo(data.lastSyncedAt, now: now).replaceFirst('Updated ', '').toLowerCase()}'
              : AppDateTime.updatedAgo(data.lastSyncedAt, now: now);
          final liveSyncMessage =
              'Live wallet data refreshed ${AppDateTime.updatedAgo(data.lastSyncedAt, now: now).replaceFirst('Updated ', '').toLowerCase()}.';

          return RefreshIndicator(
            onRefresh: walletController.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                context.pageHorizontalPadding,
                AppSpacing.sm,
                context.pageHorizontalPadding,
                context.contentBottomSpacing,
              ),
              children: [
                Text(
                  'Self-custody dashboard',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your bitcoin, clear and in control.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                    height: 1.05,
                    fontSize: context.isCompactWidth ? 26 : 30,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _WalletStatusChip(
                      icon: Icons.sync_rounded,
                      label: syncChipLabel,
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
                  obscureValues: hideBalances,
                ),
                const SizedBox(height: AppSpacing.md),
                if (context.isVeryCompactWidth) ...[
                  PrimaryActionButton(
                    icon: Icons.call_received_rounded,
                    label: 'Receive',
                    subtitle: 'Share an address',
                    accentColor: AppColors.success,
                    onTap:
                        onReceiveRequested ??
                        () =>
                            Navigator.of(context).pushNamed(AppRoutes.receive),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryActionButton(
                    icon: Icons.send_rounded,
                    label: 'Send',
                    subtitle: 'Move funds out',
                    accentColor: AppColors.warning,
                    onTap:
                        onSendRequested ??
                        () => Navigator.of(context).pushNamed(AppRoutes.send),
                  ),
                ] else
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
                              () => Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.send),
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
                ] else if (data.isSyncing) ...[
                  const SizedBox(height: AppSpacing.md),
                  const InfoBanner(
                    type: InfoBannerType.info,
                    message:
                        'Refreshing wallet data from the public testnet network.',
                    icon: Icons.sync_rounded,
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.md),
                  InfoBanner(
                    type: InfoBannerType.success,
                    message: liveSyncMessage,
                    icon: Icons.cloud_done_rounded,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: 'Recent activity',
                  trailing: Text(
                    activitySummary,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TxList(
                  items: data.transactions,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  obscureAmounts: hideBalances,
                  labelForItem: (tx) {
                    return walletLabels.valueOrNull
                        ?.transactionMeta(tx.txId)
                        .label;
                  },
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
    final textPrimary = AppColors.textPrimaryOf(context);
    final maxWidth = context.isCompactWidth
        ? context.screenWidth * 0.72
        : 260.0;

    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      tint: AppColors.glassSurfaceOf(
        context,
      ).withValues(alpha: AppColors.isDark(context) ? 0.54 : 0.82),
      shadowColor: Colors.transparent,
      highlightOpacity: 0.05,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
    final textSecondary = AppColors.textSecondaryOf(context);

    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      tint: AppColors.glassSurfaceOf(
        context,
      ).withValues(alpha: AppColors.isDark(context) ? 0.64 : 0.90),
      borderColor: tone.withValues(alpha: 0.22),
      shadowColor: tone.withValues(alpha: 0.05),
      highlightOpacity: 0.06,
      padding: const EdgeInsets.all(AppSpacing.md),
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
                    color: textSecondary,
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

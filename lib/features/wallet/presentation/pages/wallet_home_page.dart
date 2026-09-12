import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
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
import 'package:flutter/services.dart';
import 'package:root_wallet/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/wallet_switcher_modal.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';
import 'package:root_wallet/shared/widgets/primary_action_button.dart';
import 'package:root_wallet/shared/widgets/section_header.dart';

class WalletHomePage extends ConsumerWidget {
  const WalletHomePage({
    super.key,
    this.onReceiveRequested,
    this.onSendRequested,
    this.onSettingsRequested,
    this.onActivityRequested,
    this.onNotificationsRequested,
  });

  final VoidCallback? onReceiveRequested;
  final VoidCallback? onSendRequested;
  final VoidCallback? onSettingsRequested;
  final VoidCallback? onActivityRequested;
  final VoidCallback? onNotificationsRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppColors.isDark(context);
    final textPrimary = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final textSecondary = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);
    final walletState = ref.watch(walletHomeControllerProvider);
    final walletController = ref.read(walletHomeControllerProvider.notifier);
    final backupConfirmed = ref.watch(backupReminderProvider);
    final hideBalances = ref.watch(balancePrivacyProvider).valueOrNull ?? false;
    final env = ref.watch(appEnvProvider);
    final now = ref.watch(dateTimeNowProvider)();
    final btcNgnRate = ref.watch(btcNgnRateProvider);
    final walletLabels = ref.watch(walletLabelsControllerProvider);
    final scriptTypeAsync = ref.watch(walletScriptTypeProvider);
    final capabilityAsync = ref.watch(walletCapabilityProvider);
    final activeWallet = ref.watch(activeWalletRecordProvider);
    final isWatchOnly = (activeWallet?.isWatchOnly ?? false) ||
        (capabilityAsync.valueOrNull?.isWatchOnly ?? false);
    final isBackupConfirmed = backupConfirmed.valueOrNull ?? false;
    final unreadNotificationsCount =
        ref.watch(unreadNotificationCountProvider);
    const networkLabel = AppConstants.networkDisplayName;

    return AppScaffold(
      titleWidget: Semantics(
        label: 'Active wallet switcher, currently ${activeWallet?.name ?? "Wallet"}',
        button: true,
        child: InkWell(
          key: const ValueKey('wallet_switcher_trigger'),
          borderRadius: BorderRadius.circular(RootRadius.lg),
          onTap: () {
            HapticFeedback.selectionClick();
            WalletSwitcherModal.show(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  isDark
                      ? 'assets/branding/logo/root-mark-warm-ivory-64.png'
                      : 'assets/branding/logo/root-mark-pine-green-64.png',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: RootSpacing.xs),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVE WALLET',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: isDark
                              ? RootBrandColors.mutedSage
                              : const Color(0xFF5E6F68),
                          height: 1.1,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              activeWallet?.name ?? 'Wallet',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isWatchOnly) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: RootBrandColors.amberAccent
                                    .withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(RootRadius.xs),
                                border: Border.all(
                                  color: RootBrandColors.amberAccent
                                      .withValues(alpha: 0.4),
                                  width: 0.5,
                                ),
                              ),
                              child: const Text(
                                'WATCH ONLY',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.4,
                                  color: RootBrandColors.amberAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: RootSpacing.xs),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
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
            padding: const EdgeInsets.only(right: RootSpacing.xs),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RootSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? RootBrandColors.deepForest
                    : RootBrandColors.warmIvory,
                borderRadius: BorderRadius.circular(RootRadius.pill),
                border: Border.all(
                  color: isDark
                      ? RootBrandColors.borderPine
                      : const Color(0xFFD7E3DC),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: RootBrandColors.amberAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: RootSpacing.xs),
                  Text(
                    networkLabel,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('home_notifications_button'),
          onPressed: onNotificationsRequested ??
              () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pushNamed(AppRoutes.notifications);
              },
          tooltip: 'Notifications',
          icon: Semantics(
            label: unreadNotificationsCount > 0
                ? 'Notifications, $unreadNotificationsCount unread'
                : 'Notifications',
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (unreadNotificationsCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: RootBrandColors.amberAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
                RootSpacing.xs,
                context.pageHorizontalPadding,
                130.0,
              ),
              children: [
                // Quiet secondary metadata header
                Padding(
                  padding: const EdgeInsets.only(
                    top: RootSpacing.xs,
                    bottom: RootSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        data.isSyncing
                            ? Icons.sync_rounded
                            : (data.isOffline
                                  ? Icons.wifi_off_rounded
                                  : Icons.check_circle_outline_rounded),
                        size: 14,
                        color: RootBrandColors.pineGreen,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          syncChipLabel,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: RootSpacing.sm),
                      scriptTypeAsync.maybeWhen(
                        data: (type) => Text(
                          '·  ${type.displayName}',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                // Total Balance Card
                BalanceCard(
                  balance: data.balance,
                  fiatAmountLabel: fiatLabel,
                  subtitle: data.isOffline
                      ? 'Cached portfolio balance'
                      : 'Available portfolio balance',
                  obscureValues: hideBalances,
                ),
                const SizedBox(height: RootSpacing.md),
                // Quick actions [ RECEIVE ] [ SEND ]
                if (context.isVeryCompactWidth) ...[
                  PrimaryActionButton(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Receive',
                    subtitle: 'Share an address',
                    accentColor: RootBrandColors.pineGreen,
                    onTap:
                        onReceiveRequested ??
                        () =>
                            Navigator.of(context).pushNamed(AppRoutes.receive),
                  ),
                  const SizedBox(height: RootSpacing.sm),
                  PrimaryActionButton(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Send',
                    subtitle: 'Move funds out',
                    accentColor: RootBrandColors.amberAccent,
                    onTap:
                        onSendRequested ??
                        () => Navigator.of(context).pushNamed(AppRoutes.send),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryActionButton(
                          icon: Icons.arrow_downward_rounded,
                          label: 'Receive',
                          subtitle: 'Share an address',
                          accentColor: RootBrandColors.pineGreen,
                          onTap:
                              onReceiveRequested ??
                              () => Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.receive),
                        ),
                      ),
                      const SizedBox(width: RootSpacing.sm),
                      Expanded(
                        child: PrimaryActionButton(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Send',
                          subtitle: 'Move funds out',
                          accentColor: RootBrandColors.amberAccent,
                          onTap:
                              onSendRequested ??
                              () => Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.send),
                        ),
                      ),
                    ],
                  ),
                // Security / Backup status card or Watch-only explanation card
                if (isWatchOnly) ...[
                  const SizedBox(height: RootSpacing.md),
                  _WalletAttentionCard(
                    icon: Icons.visibility_outlined,
                    title: 'Watch-only wallet',
                    message:
                        'This wallet can monitor funds and create unsigned transactions, but it cannot sign or spend Bitcoin on this device.',
                    actionLabel: 'PSBT Operations',
                    action: () =>
                        Navigator.of(context).pushNamed(AppRoutes.psbtImport),
                    tone: RootBrandColors.pineGreen,
                  ),
                ] else if (!isBackupConfirmed) ...[
                  const SizedBox(height: RootSpacing.md),
                  _WalletAttentionCard(
                    icon: Icons.shield_outlined,
                    title: 'Secure your recovery phrase',
                    message:
                        'A backup is still outstanding. Completing it now protects your sovereignty.',
                    actionLabel: 'Back up now',
                    action: () => Navigator.of(context).pushNamed(
                      AppRoutes.backupSeed,
                      arguments: BackupSeedPageArgs(
                        walletId: activeWallet?.id,
                        requireReauth: true,
                        isOnboardingFlow: false,
                      ),
                    ),
                    tone: RootBrandColors.amberAccent,
                  ),
                ],
                if (data.isOffline) ...[
                  const SizedBox(height: RootSpacing.md),
                  InfoBanner(
                    type: InfoBannerType.warning,
                    message:
                        'Offline mode. Showing cached wallet data from ${AppDateTime.ymdHm(data.lastSyncedAt)}.',
                    icon: Icons.wifi_off_rounded,
                  ),
                ] else if (data.isSyncing) ...[
                  const SizedBox(height: RootSpacing.md),
                  const InfoBanner(
                    type: InfoBannerType.info,
                    message:
                        'Refreshing wallet data from the public testnet network.',
                    icon: Icons.sync_rounded,
                  ),
                ] else ...[
                  const SizedBox(height: RootSpacing.md),
                  InfoBanner(
                    type: InfoBannerType.success,
                    message: liveSyncMessage,
                    icon: Icons.cloud_done_rounded,
                  ),
                ],
                const SizedBox(height: RootSpacing.lg),
                // Recent Activity
                SectionHeader(
                  title: 'Recent activity',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!context.isVeryCompactWidth) ...[
                        Text(
                          activitySummary,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (data.transactions.isNotEmpty)
                          const SizedBox(width: RootSpacing.sm),
                      ],
                      if (data.transactions.isNotEmpty)
                        InkWell(
                          onTap:
                              onActivityRequested ??
                              () => Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.transactions),
                          borderRadius: BorderRadius.circular(RootRadius.sm),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: RootSpacing.xs,
                              vertical: 2,
                            ),
                            child: Text(
                              'View all',
                              style: TextStyle(
                                color: RootBrandColors.pineGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: RootSpacing.xs),
                TxList(
                  items: data.transactions.take(5).toList(),
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
    final isDark = AppColors.isDark(context);
    final textPrimary = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final textSecondary = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);
    final cardBg = isDark ? RootBrandColors.nightPine : Colors.white;
    final border = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);

    return Container(
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? RootBrandColors.deepForest
                  : RootBrandColors.warmIvory,
              borderRadius: BorderRadius.circular(RootRadius.md),
              border: Border.all(color: border, width: 1.0),
            ),
            child: Icon(icon, color: tone, size: 20),
          ),
          const SizedBox(width: RootSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: RootSpacing.xs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: RootSpacing.md),
                OutlinedButton(onPressed: action, child: Text(actionLabel)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

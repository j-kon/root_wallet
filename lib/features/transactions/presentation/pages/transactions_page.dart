import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/errors/error_mapper.dart';
import 'package:root_wallet/core/utils/date_time.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/transactions/presentation/widgets/transaction_filter_bar.dart';
import 'package:root_wallet/features/transactions/presentation/widgets/transaction_summary.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/tx_list.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  TransactionFilter _selectedFilter = TransactionFilter.all;

  List<TxItem> _filterItems(List<TxItem> items) {
    return switch (_selectedFilter) {
      TransactionFilter.all => items,
      TransactionFilter.received => items.where((tx) => tx.isIncoming).toList(),
      TransactionFilter.sent => items.where((tx) => !tx.isIncoming).toList(),
      TransactionFilter.pending => items.where((tx) => tx.isPending).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletHomeControllerProvider);
    final walletController = ref.read(walletHomeControllerProvider.notifier);
    final walletLabels = ref.watch(walletLabelsControllerProvider);
    final hideBalances = ref.watch(balancePrivacyProvider).valueOrNull ?? false;

    return AppScaffold(
      title: 'Transactions',
      actions: [
        IconButton(
          onPressed: walletState.valueOrNull?.isSyncing == true
              ? null
              : walletController.refresh,
          tooltip: 'Refresh activity',
          icon: Icon(
            walletState.valueOrNull?.isSyncing == true
                ? Icons.sync_rounded
                : Icons.refresh_rounded,
          ),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: walletController.refresh,
        color: RootBrandColors.pineGreen,
        backgroundColor: AppColors.isDark(context)
            ? RootBrandColors.nightPine
            : RootBrandColors.pureWhite,
        child: walletState.when(
          loading: () =>
              const Center(child: Loading(label: 'Loading transactions...')),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(RootSpacing.md),
            children: [
              const SizedBox(height: RootSpacing.xl),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 44,
                      color: RootBrandColors.error,
                    ),
                    const SizedBox(height: RootSpacing.sm),
                    Text(
                      'Failed to load transactions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: RootSpacing.xs),
                    Text(
                      mapErrorToMessage(error, context: ErrorContext.sync),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(height: RootSpacing.md),
                    ElevatedButton(
                      onPressed: walletController.refresh,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RootBrandColors.pineGreen,
                        foregroundColor: RootBrandColors.charcoalPine,
                      ),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          data: (data) {
            final filteredItems = _filterItems(data.transactions);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: context.isCompactWidth
                    ? RootSpacing.sm
                    : RootSpacing.md,
                vertical: RootSpacing.xs,
              ),
              children: [
                // Filter control bar
                TransactionFilterBar(
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (filter) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                ),
                const SizedBox(height: RootSpacing.xs),

                // Summary of count & net volume
                TransactionSummary(
                  items: filteredItems,
                  filter: _selectedFilter,
                  obscureAmounts: hideBalances,
                ),
                const SizedBox(height: RootSpacing.xs),

                // Offline cached warning banner if applicable
                if (data.isOffline) ...[
                  InfoBanner(
                    type: InfoBannerType.warning,
                    message:
                        'Offline mode. Showing cached transactions from ${AppDateTime.ymdHm(data.lastSyncedAt)}.',
                    icon: Icons.wifi_off_rounded,
                  ),
                  const SizedBox(height: RootSpacing.sm),
                ],

                // Transaction list with empty state handling
                TxList(
                  items: filteredItems,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  obscureAmounts: hideBalances,
                  emptyTitle: _selectedFilter == TransactionFilter.all
                      ? 'No transactions yet'
                      : 'No ${_selectedFilter.label.toLowerCase()} activity',
                  emptyMessage: _selectedFilter == TransactionFilter.all
                      ? 'Your Bitcoin activity will appear here.'
                      : 'No transactions match the ${_selectedFilter.label.toLowerCase()} filter.',
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

                // Bottom padding to ensure bottom navigation capsule does not overlap list
                const SizedBox(height: 100),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/balance_card.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/tx_list.dart';
import 'package:root_wallet/shared/widgets/section_header.dart';

class WalletHomePage extends ConsumerWidget {
  const WalletHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletControllerProvider);

    return AppScaffold(
      title: 'Wallet',
      actions: [
        IconButton(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
          icon: const Icon(Icons.settings),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.send),
        icon: const Icon(Icons.arrow_upward),
        label: const Text('Send'),
      ),
      body: walletState.when(
        loading: () => const Loading(label: 'Syncing wallet...'),
        error: (error, _) {
          return EmptyState(
            message: 'Could not load wallet: $error',
            actionLabel: 'Retry',
            onAction: () =>
                ref.read(walletControllerProvider.notifier).refresh(),
          );
        },
        data: (data) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BalanceCard(
                  balance: data.balance,
                  onReceiveTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.receive),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Transactions'),
                const SizedBox(height: 8),
                Expanded(child: TxList(items: data.transactions)),
              ],
            ),
          );
        },
      ),
    );
  }
}

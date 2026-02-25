import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/features/wallet/data/datasources/bdk_sync_datasource.dart';
import 'package:root_wallet/features/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:root_wallet/features/wallet/data/mappers/tx_mapper.dart';
import 'package:root_wallet/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:root_wallet/features/wallet/domain/usecases/create_wallet.dart';
import 'package:root_wallet/features/wallet/domain/usecases/get_address.dart';
import 'package:root_wallet/features/wallet/domain/usecases/get_balance.dart';
import 'package:root_wallet/features/wallet/domain/usecases/get_transactions.dart';
import 'package:root_wallet/features/wallet/domain/usecases/restore_wallet.dart';

final bdkWalletDatasourceProvider = Provider<BdkWalletDatasource>(
  (ref) => BdkWalletDatasource(),
);

final bdkSyncDatasourceProvider = Provider<BdkSyncDatasource>(
  (ref) => BdkSyncDatasource(),
);

final txMapperProvider = Provider<TxMapper>((ref) => const TxMapper());

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepositoryImpl(
    walletDatasource: ref.watch(bdkWalletDatasourceProvider),
    syncDatasource: ref.watch(bdkSyncDatasourceProvider),
    txMapper: ref.watch(txMapperProvider),
  );
});

final createWalletUsecaseProvider = Provider<CreateWallet>(
  (ref) => CreateWallet(ref.watch(walletRepositoryProvider)),
);

final restoreWalletUsecaseProvider = Provider<RestoreWallet>(
  (ref) => RestoreWallet(ref.watch(walletRepositoryProvider)),
);

final getAddressUsecaseProvider = Provider<GetAddress>(
  (ref) => GetAddress(ref.watch(walletRepositoryProvider)),
);

final getBalanceUsecaseProvider = Provider<GetBalance>(
  (ref) => GetBalance(ref.watch(walletRepositoryProvider)),
);

final getTransactionsUsecaseProvider = Provider<GetTransactions>(
  (ref) => GetTransactions(ref.watch(walletRepositoryProvider)),
);

class WalletHomeState {
  const WalletHomeState({
    required this.balance,
    required this.transactions,
    required this.receiveAddress,
    required this.lastSyncedAt,
  });

  final Balance balance;
  final List<TxItem> transactions;
  final String receiveAddress;
  final DateTime lastSyncedAt;
}

class WalletHomeController extends AsyncNotifier<WalletHomeState> {
  @override
  Future<WalletHomeState> build() {
    return _load();
  }

  Future<void> refresh() {
    return sync(showLoading: true);
  }

  Future<void> sync({bool showLoading = false}) async {
    if (showLoading || !state.hasValue) {
      state = const AsyncLoading();
    }
    state = await AsyncValue.guard(_load);
  }

  Future<WalletHomeState> _load() async {
    final balance = await ref.read(getBalanceUsecaseProvider).call();
    final transactions = await ref.read(getTransactionsUsecaseProvider).call();
    final receiveAddress = await ref.read(getAddressUsecaseProvider).call();

    return WalletHomeState(
      balance: balance,
      transactions: transactions,
      receiveAddress: receiveAddress,
      lastSyncedAt: DateTime.now(),
    );
  }
}

final walletHomeControllerProvider =
    AsyncNotifierProvider<WalletHomeController, WalletHomeState>(
      WalletHomeController.new,
    );

final walletControllerProvider = walletHomeControllerProvider;

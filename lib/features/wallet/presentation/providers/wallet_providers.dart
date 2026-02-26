import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/bdk_sync_datasource.dart';
import 'package:root_wallet/features/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_snapshot_cache.dart';
import 'package:root_wallet/features/wallet/data/mappers/tx_mapper.dart';
import 'package:root_wallet/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:root_wallet/features/wallet/domain/usecases/create_wallet.dart';
import 'package:root_wallet/features/wallet/domain/usecases/get_address.dart';
import 'package:root_wallet/features/wallet/domain/usecases/get_balance.dart';
import 'package:root_wallet/features/wallet/domain/usecases/get_recovery_phrase.dart';
import 'package:root_wallet/features/wallet/domain/usecases/get_transactions.dart';
import 'package:root_wallet/features/wallet/domain/usecases/has_wallet.dart';
import 'package:root_wallet/features/wallet/domain/usecases/restore_wallet.dart';
import 'package:root_wallet/shared/models/wallet_snapshot.dart';

final bdkWalletDatasourceProvider = Provider<BdkWalletDatasource>(
  (ref) => BdkWalletDatasource(
    secureStorage: ref.watch(secureStorageProvider),
  ),
);

final bdkSyncDatasourceProvider = Provider<BdkSyncDatasource>(
  (ref) => BdkSyncDatasource(
    walletDatasource: ref.watch(bdkWalletDatasourceProvider),
  ),
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

final hasWalletUsecaseProvider = Provider<HasWallet>(
  (ref) => HasWallet(ref.watch(walletRepositoryProvider)),
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

final getRecoveryPhraseUsecaseProvider = Provider<GetRecoveryPhrase>(
  (ref) => GetRecoveryPhrase(ref.watch(walletRepositoryProvider)),
);

final recoveryPhraseProvider = FutureProvider<String>((ref) {
  return ref.watch(getRecoveryPhraseUsecaseProvider).call();
});

final walletSnapshotCacheProvider = FutureProvider<WalletSnapshotCache>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return WalletSnapshotCache(prefs);
});

class WalletHomeState {
  const WalletHomeState({
    required this.balance,
    required this.transactions,
    required this.receiveAddress,
    required this.lastSyncedAt,
    required this.isOffline,
  });

  final Balance balance;
  final List<TxItem> transactions;
  final String receiveAddress;
  final DateTime lastSyncedAt;
  final bool isOffline;

  WalletHomeState copyWith({
    Balance? balance,
    List<TxItem>? transactions,
    String? receiveAddress,
    DateTime? lastSyncedAt,
    bool? isOffline,
  }) {
    return WalletHomeState(
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      receiveAddress: receiveAddress ?? this.receiveAddress,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class WalletHomeController extends AsyncNotifier<WalletHomeState> {
  @override
  Future<WalletHomeState> build() async {
    final cached = await _readCachedState();
    if (cached != null) {
      unawaited(sync());
      return cached.copyWith(isOffline: true);
    }

    final fresh = await _loadRemoteState();
    await _writeCache(fresh);
    return fresh;
  }

  Future<void> refresh() {
    return sync(showLoading: true);
  }

  Future<void> sync({bool showLoading = false}) async {
    final previous = state.valueOrNull;
    if (showLoading || previous == null) {
      state = const AsyncLoading();
    }

    try {
      final fresh = await _loadRemoteState();
      await _writeCache(fresh);
      state = AsyncData(fresh);
      return;
    } catch (error, stackTrace) {
      final cached = await _readCachedState();
      if (cached != null) {
        state = AsyncData(cached.copyWith(isOffline: true));
        return;
      }

      if (previous != null) {
        state = AsyncData(previous.copyWith(isOffline: true));
        return;
      }

      state = AsyncError(error, stackTrace);
    }
  }

  Future<WalletHomeState> _loadRemoteState() async {
    final balance = await ref.read(getBalanceUsecaseProvider).call();
    final transactions = await ref.read(getTransactionsUsecaseProvider).call();
    final receiveAddress = await ref.read(getAddressUsecaseProvider).call();

    return WalletHomeState(
      balance: balance,
      transactions: transactions,
      receiveAddress: receiveAddress,
      lastSyncedAt: DateTime.now(),
      isOffline: false,
    );
  }

  Future<WalletHomeState?> _readCachedState() async {
    final cache = await ref.read(walletSnapshotCacheProvider.future);
    final snapshot = await cache.read();
    if (snapshot == null) {
      return null;
    }

    return WalletHomeState(
      balance: Balance(
        confirmedSats: snapshot.confirmedSats,
        pendingSats: snapshot.pendingSats,
      ),
      transactions: snapshot.transactions
          .map(
            (tx) => TxItem(
              txId: tx.txId,
              amountSats: tx.amountSats,
              timestamp: DateTime.fromMillisecondsSinceEpoch(tx.timestampMs),
              isIncoming: tx.isIncoming,
              status: tx.status == 'pending'
                  ? TxItemStatus.pending
                  : TxItemStatus.confirmed,
              feeSats: tx.feeSats,
              confirmations: tx.confirmations,
            ),
          )
          .toList(growable: false),
      receiveAddress: snapshot.receiveAddress,
      lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(
        snapshot.lastSyncedAtMs,
      ),
      isOffline: true,
    );
  }

  Future<void> _writeCache(WalletHomeState state) async {
    final cache = await ref.read(walletSnapshotCacheProvider.future);
    final snapshot = WalletSnapshot(
      confirmedSats: state.balance.confirmedSats,
      pendingSats: state.balance.pendingSats,
      receiveAddress: state.receiveAddress,
      lastSyncedAtMs: state.lastSyncedAt.millisecondsSinceEpoch,
      transactions: state.transactions
          .take(20)
          .map(
            (tx) => WalletSnapshotTx(
              txId: tx.txId,
              amountSats: tx.amountSats,
              timestampMs: tx.timestamp.millisecondsSinceEpoch,
              isIncoming: tx.isIncoming,
              status: tx.status == TxItemStatus.pending
                  ? 'pending'
                  : 'confirmed',
              feeSats: tx.feeSats,
              confirmations: tx.confirmations,
            ),
          )
          .toList(growable: false),
    );

    await cache.write(snapshot);
  }
}

final walletHomeControllerProvider =
    AsyncNotifierProvider<WalletHomeController, WalletHomeState>(
      WalletHomeController.new,
    );

final walletControllerProvider = walletHomeControllerProvider;

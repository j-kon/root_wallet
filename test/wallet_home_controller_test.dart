import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_snapshot_cache.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_overview.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:root_wallet/features/wallet/domain/usecases/get_wallet_overview.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/models/wallet_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WalletHomeController', () {
    test('loads cached snapshot immediately when available', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await WalletSnapshotCache(prefs).write(
        WalletSnapshot(
          schemaVersion: AppConstants.walletSnapshotSchemaVersion,
          confirmedSats: 12345,
          pendingSats: 200,
          receiveAddress: 'tb1qcachedaddress',
          lastSyncedAtMs: DateTime(2026, 1, 1, 12).millisecondsSinceEpoch,
          transactions: const <WalletSnapshotTx>[
            WalletSnapshotTx(
              txId: 'cached_tx',
              amountSats: 5000,
              timestampMs: 1704110400000,
              isIncoming: true,
              status: 'confirmed',
              feeSats: 100,
              confirmations: 3,
            ),
          ],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          getWalletOverviewUsecaseProvider.overrideWithValue(
            GetWalletOverview(_ThrowingWalletRepository()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(walletHomeControllerProvider.future);

      expect(state.isOffline, isTrue);
      expect(state.balance.confirmedSats, 12345);
      expect(state.receiveAddress, 'tb1qcachedaddress');
      expect(state.transactions, hasLength(1));
      expect(state.transactions.single.txId, 'cached_tx');
    });

    test('uses remote overview when cache is empty', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer(
        overrides: [
          getWalletOverviewUsecaseProvider.overrideWithValue(
            GetWalletOverview(
              _StaticWalletRepository(
                overview: WalletOverview(
                  balance: const Balance(
                    confirmedSats: 21000,
                    pendingSats: 500,
                  ),
                  transactions: <TxItem>[
                    TxItem(
                      txId: 'fresh_tx',
                      amountSats: 7500,
                      timestamp: DateTime(2026, 1, 2),
                      isIncoming: true,
                      status: TxItemStatus.pending,
                    ),
                  ],
                  receiveAddress: 'tb1qfreshaddress',
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(walletHomeControllerProvider.future);

      expect(state.isOffline, isFalse);
      expect(state.balance.confirmedSats, 21000);
      expect(state.receiveAddress, 'tb1qfreshaddress');
      expect(state.transactions.single.txId, 'fresh_tx');
      expect(state.isSyncing, isFalse);
    });
  });
}

class _StaticWalletRepository implements WalletRepository {
  _StaticWalletRepository({required this.overview});

  final WalletOverview overview;

  @override
  Future<WalletIdentity> createWallet() {
    throw UnimplementedError();
  }

  @override
  Future<String> getAddress() async => overview.receiveAddress;

  @override
  Future<Balance> getBalance() async => overview.balance;

  @override
  Future<WalletOverview> getOverview() async => overview;

  @override
  Future<String> getRecoveryPhrase() {
    throw UnimplementedError();
  }

  @override
  Future<List<TxItem>> getTransactions() async => overview.transactions;

  @override
  Future<bool> hasWallet() async => true;

  @override
  Future<WalletIdentity> restoreWallet({required String mnemonic}) {
    throw UnimplementedError();
  }
}

class _ThrowingWalletRepository extends _StaticWalletRepository {
  _ThrowingWalletRepository()
    : super(
        overview: const WalletOverview(
          balance: Balance(confirmedSats: 0),
          transactions: <TxItem>[],
          receiveAddress: '',
        ),
      );

  @override
  Future<WalletOverview> getOverview() {
    throw Exception('network unavailable');
  }
}

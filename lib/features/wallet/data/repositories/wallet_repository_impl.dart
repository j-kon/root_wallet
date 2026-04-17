import 'package:root_wallet/features/wallet/data/datasources/bdk_sync_datasource.dart';
import 'package:root_wallet/features/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:root_wallet/features/wallet/data/mappers/tx_mapper.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_diagnostics.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_overview.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl({
    required BdkWalletDatasource walletDatasource,
    required BdkSyncDatasource syncDatasource,
    required TxMapper txMapper,
  }) : _walletDatasource = walletDatasource,
       _syncDatasource = syncDatasource,
       _txMapper = txMapper;

  final BdkWalletDatasource _walletDatasource;
  final BdkSyncDatasource _syncDatasource;
  final TxMapper _txMapper;

  @override
  Future<bool> hasWallet() {
    return _walletDatasource.hasWallet();
  }

  @override
  Future<WalletIdentity> createWallet() {
    return _walletDatasource.createWallet();
  }

  @override
  Future<String> getAddress() {
    return _walletDatasource.getAddress();
  }

  @override
  Future<String> getRecoveryPhrase() async {
    final phrase = await _walletDatasource.getMnemonic();
    if (phrase == null || phrase.trim().isEmpty) {
      throw StateError('No wallet recovery phrase found.');
    }
    return phrase;
  }

  @override
  Future<Balance> getBalance() async {
    try {
      await _syncDatasource.sync();
    } catch (_) {
      // Keep the wallet usable offline by falling back to local state.
    }
    final confirmed = await _syncDatasource.confirmedBalance();
    final pending = await _syncDatasource.pendingBalance();
    return Balance(confirmedSats: confirmed, pendingSats: pending);
  }

  @override
  Future<List<TxItem>> getTransactions() async {
    try {
      await _syncDatasource.sync();
    } catch (_) {
      // Local transactions can still be read even when sync fails.
    }
    final txs = await _syncDatasource.transactions();
    return txs.map(_txMapper.fromDto).toList(growable: false);
  }

  @override
  Future<WalletOverview> getOverview() async {
    try {
      await _syncDatasource.sync();
    } catch (_) {
      // Keep the wallet usable offline by falling back to local state.
    }

    final confirmed = await _syncDatasource.confirmedBalance();
    final pending = await _syncDatasource.pendingBalance();
    final txs = await _syncDatasource.transactions();
    final receiveAddress = await _walletDatasource.getAddress();

    return WalletOverview(
      balance: Balance(confirmedSats: confirmed, pendingSats: pending),
      transactions: txs.map(_txMapper.fromDto).toList(growable: false),
      receiveAddress: receiveAddress,
    );
  }

  @override
  Future<WalletDiagnostics> getDiagnostics() {
    return _walletDatasource.diagnostics();
  }

  @override
  Future<void> rotateBackend() {
    return _walletDatasource.rotateBackend();
  }

  @override
  Future<WalletIdentity> restoreWallet({required String mnemonic}) {
    return _walletDatasource.restoreWallet(mnemonic: mnemonic);
  }
}

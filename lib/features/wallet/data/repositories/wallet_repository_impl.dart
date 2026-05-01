import 'package:root_wallet/features/wallet/data/datasources/bdk_sync_datasource.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/mappers/tx_mapper.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_diagnostics.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_overview.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl({
    required BdkWalletService walletService,
    required BdkSyncDatasource syncDatasource,
    required TxMapper txMapper,
  }) : _walletService = walletService,
       _syncDatasource = syncDatasource,
       _txMapper = txMapper;

  final BdkWalletService _walletService;
  final BdkSyncDatasource _syncDatasource;
  final TxMapper _txMapper;

  @override
  Future<bool> hasWallet() {
    return _walletService.hasWallet();
  }

  @override
  Future<WalletIdentity> createWallet() {
    return _walletService.createWallet();
  }

  @override
  Future<void> resetWallet() {
    return _walletService.resetWallet();
  }

  @override
  Future<String> getAddress() {
    return _walletService.getAddress();
  }

  @override
  Future<String> getRecoveryPhrase() async {
    final phrase = await _walletService.getMnemonic();
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
    Object? syncError;
    try {
      await _syncDatasource.sync();
    } catch (error) {
      syncError = error;
      // Keep the wallet usable offline by falling back to local state.
    }

    final confirmed = await _syncDatasource.confirmedBalance();
    final pending = await _syncDatasource.pendingBalance();
    final txs = await _syncDatasource.transactions();
    final receiveAddress = await _walletService.getAddress();

    return WalletOverview(
      balance: Balance(confirmedSats: confirmed, pendingSats: pending),
      transactions: txs.map(_txMapper.fromDto).toList(growable: false),
      receiveAddress: receiveAddress,
      syncSucceeded: syncError == null,
      syncError: syncError,
    );
  }

  @override
  Future<WalletDiagnostics> getDiagnostics() {
    return _walletService.diagnostics();
  }

  @override
  Future<void> rotateBackend() {
    return _walletService.rotateBackend();
  }

  @override
  Future<void> setCustomBackend(String? endpoint) {
    return _walletService.setCustomBackend(endpoint);
  }

  @override
  Future<WalletIdentity> restoreWallet({
    required String mnemonic,
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
  }) {
    return _walletService.restoreWallet(
      mnemonic: mnemonic,
      scriptType: scriptType,
    );
  }
}

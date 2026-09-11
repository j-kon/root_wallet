import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_creation_result.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_diagnostics.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_overview.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl({required BdkWalletService walletService})
    : _walletService = walletService;

  final BdkWalletService _walletService;

  @override
  Future<bool> hasWallet() {
    return _walletService.hasWallet();
  }

  @override
  Future<WalletCapability> getCapability() {
    return _walletService.getCapability();
  }

  @override
  Future<WalletIdentity> importWatchOnlyWallet({
    required String externalDescriptor,
    String? internalDescriptor,
    String? walletId,
    String? walletName,
  }) {
    return _walletService.importWatchOnlyWallet(
      externalDescriptor: externalDescriptor,
      internalDescriptor: internalDescriptor,
      walletId: walletId,
      walletName: walletName,
    );
  }

  @override
  Future<WalletCreationResult> createWallet({
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
    String? walletId,
    String? walletName,
  }) {
    return _walletService.createWallet(
      scriptType: scriptType,
      walletId: walletId,
      walletName: walletName,
    );
  }

  @override
  Future<void> deleteWalletData(String walletId) {
    return _walletService.deleteWalletData(walletId);
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
    final overview = await getOverview();
    return overview.balance;
  }

  @override
  Future<List<TxItem>> getTransactions() async {
    final overview = await getOverview();
    return overview.transactions;
  }

  @override
  Future<WalletOverview> getOverview() async {
    try {
      final data = await _walletService.loadWalletOverviewInBackground();

      final txs = data.transactions.map((tx) {
        return TxItem(
          txId: tx.txId,
          amountSats: tx.amountSats,
          timestamp: DateTime.fromMillisecondsSinceEpoch(tx.timestampMs),
          isIncoming: tx.isIncoming,
          status: tx.status == 'confirmed'
              ? TxItemStatus.confirmed
              : TxItemStatus.pending,
          feeSats: tx.feeSats,
          confirmations: tx.confirmations,
        );
      }).toList();

      var address = data.receiveAddress;
      if (address.isEmpty) {
        try {
          address = await _walletService.getAddress();
        } catch (_) {
          // Fallback failed; receiveAddress remains empty string
        }
      }

      return WalletOverview(
        balance: Balance(
          confirmedSats: data.confirmedSats,
          pendingSats: data.pendingSats,
        ),
        transactions: txs,
        receiveAddress: address,
        syncSucceeded: data.syncSucceeded,
        syncError: data.syncError != null ? Exception(data.syncError) : null,
      );
    } catch (error) {
      String fallbackAddress = '';
      try {
        fallbackAddress = await _walletService.getAddress();
      } catch (_) {
      }
      return WalletOverview(
        balance: const Balance(confirmedSats: 0, pendingSats: 0),
        transactions: const [],
        receiveAddress: fallbackAddress,
        syncSucceeded: false,
        syncError: error,
      );
    }
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
    String? walletId,
    String? walletName,
  }) {
    return _walletService.restoreWallet(
      mnemonic: mnemonic,
      scriptType: scriptType,
      walletId: walletId,
      walletName: walletName,
    );
  }
}

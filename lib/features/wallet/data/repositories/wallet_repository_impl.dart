import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
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
  }) : _walletService = walletService;

  final BdkWalletService _walletService;

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
        } catch (e) {
          print('DEBUG: getAddress fallback failed: $e');
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
    } catch (error, stackTrace) {
      print('DEBUG: getOverview failed: $error');
      print(stackTrace);
      String fallbackAddress = '';
      try {
        fallbackAddress = await _walletService.getAddress();
      } catch (e) {
        print('DEBUG: getAddress fallback failed: $e');
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
  }) {
    return _walletService.restoreWallet(
      mnemonic: mnemonic,
      scriptType: scriptType,
    );
  }
}

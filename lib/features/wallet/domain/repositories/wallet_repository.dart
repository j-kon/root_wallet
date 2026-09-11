import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_creation_result.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_diagnostics.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_overview.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';

abstract class WalletRepository {
  Future<bool> hasWallet();
  Future<WalletCapability> getCapability();
  Future<WalletCreationResult> createWallet({
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
    String? walletId,
    String? walletName,
  });
  Future<WalletIdentity> restoreWallet({
    required String mnemonic,
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
    String? walletId,
    String? walletName,
  });
  Future<WalletIdentity> importWatchOnlyWallet({
    required String externalDescriptor,
    String? internalDescriptor,
    String? walletId,
    String? walletName,
  });
  Future<void> deleteWalletData(String walletId);
  Future<void> resetWallet();
  Future<String> getRecoveryPhrase();
  Future<String> getAddress();
  Future<Balance> getBalance();
  Future<List<TxItem>> getTransactions();
  Future<WalletOverview> getOverview();
  Future<WalletDiagnostics> getDiagnostics();
  Future<void> rotateBackend();
  Future<void> setCustomBackend(String? endpoint);
}


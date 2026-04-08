import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_overview.dart';

abstract class WalletRepository {
  Future<bool> hasWallet();
  Future<WalletIdentity> createWallet();
  Future<WalletIdentity> restoreWallet({required String mnemonic});
  Future<String> getRecoveryPhrase();
  Future<String> getAddress();
  Future<Balance> getBalance();
  Future<List<TxItem>> getTransactions();
  Future<WalletOverview> getOverview();
}

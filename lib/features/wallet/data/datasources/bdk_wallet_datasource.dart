import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';

class BdkWalletDatasource {
  Future<WalletIdentity> createWallet() async {
    return const WalletIdentity(
      id: 'wallet_local_001',
      fingerprint: 'F1A2B3C4',
      network: 'bitcoin',
    );
  }

  Future<String> getAddress() async {
    return 'bc1qexampleaddress0000000000000000000000000';
  }

  Future<WalletIdentity> restoreWallet({required String mnemonic}) async {
    return const WalletIdentity(
      id: 'wallet_restored_001',
      fingerprint: 'R5D6E7F8',
      network: 'bitcoin',
    );
  }
}

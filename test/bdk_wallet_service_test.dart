import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'createWallet stores seed without eagerly opening native wallet DB',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secureStorage = InMemorySecureStorage();
      final service = BdkWalletService(
        secureStorage: secureStorage,
        walletStoragePathLoader: () async =>
            '/tmp/root_wallet_missing_native_db_parent/wallet',
        preferencesLoader: SharedPreferences.getInstance,
        allowCustomEsploraEndpoint: false,
      );

      final identity = await service.createWallet();
      final mnemonic = await service.getMnemonic();

      expect(identity.network, 'testnet');
      expect(mnemonic, isNotNull);
      expect(() => bdk.Mnemonic.fromString(mnemonic: mnemonic!), returnsNormally);
      expect(mnemonic!.split(' '), hasLength(12));
    },
  );
}

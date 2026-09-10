import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_seed_service.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';

void main() {
  group('Wallet Reset & Data Purge Security Verification', () {
    late Directory tempDir;
    late InMemorySecureStorage secureStorage;
    late WalletSeedService seedService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('root_wallet_reset_test_');
      secureStorage = InMemorySecureStorage();
      seedService = WalletSeedService(
        secureStorage: secureStorage,
        walletStoragePathLoader: () async => tempDir.path,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Wallet creation wipes residual database and decoy artifacts', () async {
      // Pre-seed storage with primary AND decoy keys
      await secureStorage.write(
        key: WalletStorageKeys.mnemonic,
        value: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      );
      await secureStorage.write(
        key: WalletStorageKeys.decoyMnemonic,
        value: 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong',
      );

      // Create fake residual files on disk
      final staleFiles = <File>[
        File('${tempDir.path}/root_wallet_testnet.sqlite'),
        File('${tempDir.path}/root_wallet_testnet.sqlite-wal'),
        File('${tempDir.path}/root_wallet_testnet.sqlite-shm'),
        File('${tempDir.path}/decoy_root_wallet_testnet.sqlite'),
        File('${tempDir.path}/decoy_root_wallet_testnet.sqlite-wal'),
        File('${tempDir.path}/decoy_root_wallet_testnet.sqlite-shm'),
        File('${tempDir.path}/decoy_root_wallet_testnet_p2wpkh_v2.sqlite'),
      ];

      for (final f in staleFiles) {
        await f.writeAsString('residual sensitive test data');
      }

      // Re-create wallet
      final result = await seedService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
      );

      // Verify mnemonic was updated
      expect(result.recoveryPhrase, isNotEmpty);
      expect(
        await secureStorage.read(key: WalletStorageKeys.mnemonic),
        equals(result.recoveryPhrase),
      );

      // Verify all stale files including decoy files were destroyed
      for (final f in staleFiles) {
        expect(
          await f.exists(),
          isFalse,
          reason: 'Residual file ${f.path} must be deleted',
        );
      }
    });

    test('Restore wallet purges old decoy databases upon replacing seed', () async {
      final decoyFile = File('${tempDir.path}/decoy_root_wallet_testnet.sqlite');
      await decoyFile.writeAsString('decoy db');
      expect(await decoyFile.exists(), isTrue);

      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

      await seedService.restoreWallet(
        mnemonic: phrase,
        scriptType: WalletScriptType.nativeSegwit,
      );

      expect(await decoyFile.exists(), isFalse);
    });
  });
}

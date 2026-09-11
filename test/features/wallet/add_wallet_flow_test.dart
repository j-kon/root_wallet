import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/services/add_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Add Wallet Flow Integration Tests (Items 2, 3, 4)', () {
    late InMemorySecureStorage storage;
    late SharedPreferences prefs;
    late Directory tempDir;
    late WalletRegistry registry;
    late AddWalletService addWalletService;

    const phraseA =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const phraseB =
        'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';
    const validTpub =
        'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = InMemorySecureStorage();
      tempDir = Directory.systemTemp.createTempSync('add_wallet_flow_test_');
      registry = WalletRegistry(prefs);

      addWalletService = AddWalletService(
        secureStorage: storage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    Future<String> setupWalletA() async {
      const walletAId = 'w_wallet_a';
      await storage.write(
        key: WalletStorageKeys.mnemonicFor(walletAId),
        value: phraseA,
      );
      await storage.write(
        key: WalletStorageKeys.scriptTypeFor(walletAId),
        value: WalletScriptType.nativeSegwit.storageValue,
      );
      await storage.write(
        key: WalletStorageKeys.capabilityFor(walletAId),
        value: WalletCapability.signing.storageValue,
      );
      final dirA = Directory('${tempDir.path}/wallets/$walletAId');
      await dirA.create(recursive: true);
      final dummyDbA = File('${dirA.path}/db.sqlite');
      await dummyDbA.writeAsString('wallet_a_database_content');

      final recordA = WalletRecord(
        id: walletAId,
        name: 'Wallet A',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '73C5DA0A',
        isActive: true,
      );
      await registry.registerWallet(recordA, makeActive: true);
      return walletAId;
    }

    test('Item 2: Create-Wallet integration test preserves wallet A and isolates wallet B', () async {
      final walletAId = await setupWalletA();

      // Write decoy mnemonic to ensure it is protected
      await storage.write(
        key: WalletStorageKeys.decoyMnemonic,
        value: 'decoy phrase test only',
      );

      // Create new Wallet B via AddWalletService
      final resultB = await addWalletService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Wallet B',
      );

      final walletBId = resultB.walletRecord!.id;
      expect(walletBId, isNot(equals(walletAId)));

      // 1. Wallet A remains 100% UNTOUCHED
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletAId)),
        equals(phraseA),
      );
      expect(
        await storage.read(key: WalletStorageKeys.capabilityFor(walletAId)),
        equals(WalletCapability.signing.storageValue),
      );
      final dummyDbA = File('${tempDir.path}/wallets/$walletAId/db.sqlite');
      expect(await dummyDbA.exists(), isTrue);
      expect(await dummyDbA.readAsString(), equals('wallet_a_database_content'));

      // 2. Wallet B has isolated scoped keys
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletBId)),
        equals(resultB.recoveryPhrase),
      );
      expect(
        await storage.read(key: WalletStorageKeys.capabilityFor(walletBId)),
        equals(WalletCapability.signing.storageValue),
      );
      expect(
        await storage.read(key: WalletStorageKeys.scriptTypeFor(walletBId)),
        equals(WalletScriptType.nativeSegwit.storageValue),
      );

      // 3. Isolated directory created for Wallet B
      final dirB = Directory('${tempDir.path}/wallets/$walletBId');
      expect(await dirB.exists(), isTrue);

      // 4. Decoy mnemonic and global keys untouched
      expect(
        await storage.read(key: WalletStorageKeys.decoyMnemonic),
        equals('decoy phrase test only'),
      );
      expect(await storage.read(key: WalletStorageKeys.mnemonic), isNull);

      // 5. Registry contains both wallets with Wallet B active
      final wallets = registry.getWallets();
      expect(wallets.length, equals(2));
      expect(wallets.map((w) => w.id), containsAll([walletAId, walletBId]));
      expect(registry.getActiveWalletId(), equals(walletBId));
      expect(resultB.walletRecord!.fingerprint, isNotNull);
      expect(resultB.walletRecord!.fingerprint!.length, equals(8));
    });

    test('Item 3: Restore-Wallet integration test restores B without overwriting A and detects duplicates', () async {
      final walletAId = await setupWalletA();

      // Restore Wallet B
      final identityB = await addWalletService.restoreWallet(
        mnemonic: phraseB,
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Restored Wallet B',
      );

      final walletBId = identityB.id;
      expect(walletBId, isNot(equals(walletAId)));

      // 1. Wallet A remains untouched
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletAId)),
        equals(phraseA),
      );
      final dummyDbA = File('${tempDir.path}/wallets/$walletAId/db.sqlite');
      expect(await dummyDbA.exists(), isTrue);

      // 2. Wallet B is restored and active
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletBId)),
        equals(phraseB),
      );
      final dirB = Directory('${tempDir.path}/wallets/$walletBId');
      expect(await dirB.exists(), isTrue);

      final wallets = registry.getWallets();
      expect(wallets.length, equals(2));
      expect(registry.getActiveWalletId(), equals(walletBId));

      // 3. Duplicate detection: restoring Wallet A's phrase with same scriptType throws AddWalletDuplicateException
      expect(
        () => addWalletService.restoreWallet(
          mnemonic: phraseA,
          scriptType: WalletScriptType.nativeSegwit,
        ),
        throwsA(
          isA<AddWalletDuplicateException>().having(
            (e) => e.message,
            'message',
            contains('already exists'),
          ),
        ),
      );

      // 4. Invalid checksum phrase throws FormatException
      expect(
        () => addWalletService.restoreWallet(
          mnemonic: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('Item 4: Watch-Only Add Flow creates new ID, isolated DB, and protects signing A and decoy', () async {
      final walletAId = await setupWalletA();

      // Setup decoy mnemonic
      await storage.write(
        key: WalletStorageKeys.decoyMnemonic,
        value: 'decoy secret private material',
      );

      // Import watch-only wallet C
      final recordC = await addWalletService.importWatchOnlyWallet(
        externalDescriptor: validTpub,
        walletName: 'Watch-Only Vault',
      );

      final walletCId = recordC.id;
      expect(walletCId, isNot(equals(walletAId)));

      // 1. Wallet C is watch-only, has no private keys
      expect(recordC.type, equals(WalletType.watchOnly));
      expect(
        await storage.read(key: WalletStorageKeys.capabilityFor(walletCId)),
        equals(WalletCapability.watchOnly.storageValue),
      );
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletCId)),
        isNull,
      );
      expect(
        await storage.read(key: WalletStorageKeys.externalDescriptorFor(walletCId)),
        isNotNull,
      );

      // 2. Isolated directory exists for Wallet C
      final dirC = Directory('${tempDir.path}/wallets/$walletCId');
      expect(await dirC.exists(), isTrue);

      // 3. Wallet A is completely untouched
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletAId)),
        equals(phraseA),
      );
      final dummyDbA = File('${tempDir.path}/wallets/$walletAId/db.sqlite');
      expect(await dummyDbA.exists(), isTrue);

      // 4. Decoy mnemonic is 100% untouched
      expect(
        await storage.read(key: WalletStorageKeys.decoyMnemonic),
        equals('decoy secret private material'),
      );

      // 5. Duplicate detection: importing same descriptor throws AddWalletDuplicateException
      expect(
        () => addWalletService.importWatchOnlyWallet(
          externalDescriptor: validTpub,
        ),
        throwsA(
          isA<AddWalletDuplicateException>().having(
            (e) => e.message,
            'message',
            contains('already imported'),
          ),
        ),
      );
    });
  });
}

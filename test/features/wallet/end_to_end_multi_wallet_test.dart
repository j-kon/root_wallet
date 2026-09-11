import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/services/add_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_migration_service.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_storage_cleaner.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Item 18: Actual End-To-End Multi-Wallet 18-Step Test Sequence', () {
    late InMemorySecureStorage storage;
    late SharedPreferences prefs;
    late Directory tempDir;

    const phraseA =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const validTpubC =
        'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = InMemorySecureStorage();
      tempDir = Directory.systemTemp.createTempSync('e2e_multi_wallet_test_');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('executes complete 18-step multi-wallet lifecycle without data loss or isolation failure', () async {
      // -----------------------------------------------------------------------
      // Step 1: Start with legacy single wallet state
      // -----------------------------------------------------------------------
      await storage.write(
        key: WalletStorageKeys.legacyMnemonic,
        value: phraseA,
      );
      await storage.write(
        key: WalletStorageKeys.legacyScriptType,
        value: WalletScriptType.nativeSegwit.storageValue,
      );
      await storage.write(
        key: WalletStorageKeys.walletCapability,
        value: WalletCapability.signing.storageValue,
      );
      await storage.write(
        key: WalletStorageKeys.decoyMnemonic,
        value: 'decoy phrase canary 123',
      );

      final legacyDb = File(
        '${tempDir.path}/root_wallet_testnet_v${AppConstants.walletDatabaseSchemaVersion}.sqlite',
      );
      await legacyDb.writeAsString('legacy_wallet_a_database_content');

      // -----------------------------------------------------------------------
      // Step 2: Initialize app -> verify migration runs, record created, DB copied
      // -----------------------------------------------------------------------
      final migrationService = WalletMigrationService(
        secureStorage: storage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      final migratedRecord = await migrationService.migrateIfNeeded();
      expect(migratedRecord, isNotNull);
      final walletAId = migratedRecord!.id;
      expect(walletAId, equals(WalletMigrationService.defaultMigratedWalletId));

      // Verify completion marker is set
      expect(
        prefs.getBool(WalletStorageKeys.legacyMigrationCompleted),
        isTrue,
      );

      // Verify DB was copied to isolated directory
      final copiedDbA = File(
        '${tempDir.path}/wallets/$walletAId/bdk_wallet.sqlite',
      );
      expect(await copiedDbA.exists(), isTrue);
      expect(await copiedDbA.readAsString(), equals('legacy_wallet_a_database_content'));

      // Verify active wallet points to migrated wallet
      final registry = WalletRegistry(prefs);
      expect(registry.getActiveWalletId(), equals(walletAId));

      // -----------------------------------------------------------------------
      // Step 3: Verify migrated wallet A state and BIP32 master fingerprint
      // -----------------------------------------------------------------------
      expect(migratedRecord.type, equals(WalletType.signing));
      expect(migratedRecord.fingerprint, equals('73C5DA0A'));
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletAId)),
        equals(phraseA),
      );
      expect(
        await storage.read(key: WalletStorageKeys.capabilityFor(walletAId)),
        equals(WalletCapability.signing.storageValue),
      );

      // -----------------------------------------------------------------------
      // Step 4: Create Wallet B via AddWallet flow (Native Segwit)
      // -----------------------------------------------------------------------
      final addWalletService = AddWalletService(
        secureStorage: storage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      final resultB = await addWalletService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Wallet B',
      );
      final walletBId = resultB.walletRecord!.id;
      final phraseB = resultB.recoveryPhrase;

      // -----------------------------------------------------------------------
      // Step 5: Verify Wallet A's scoped keys and DB are UNTOUCHED
      // -----------------------------------------------------------------------
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletAId)),
        equals(phraseA),
      );
      expect(await copiedDbA.exists(), isTrue);
      expect(await copiedDbA.readAsString(), equals('legacy_wallet_a_database_content'));

      // -----------------------------------------------------------------------
      // Step 6: Verify Wallet B has unique ID, scoped keys, isolated DB directory
      // -----------------------------------------------------------------------
      expect(walletBId, isNot(equals(walletAId)));
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletBId)),
        equals(phraseB),
      );
      expect(
        await storage.read(key: WalletStorageKeys.capabilityFor(walletBId)),
        equals(WalletCapability.signing.storageValue),
      );
      final dirB = Directory('${tempDir.path}/wallets/$walletBId');
      expect(await dirB.exists(), isTrue);

      // -----------------------------------------------------------------------
      // Step 7: Verify registry contains both wallets with correct metadata
      // -----------------------------------------------------------------------
      final walletsAfterB = registry.getWallets();
      expect(walletsAfterB.length, equals(2));
      expect(walletsAfterB.map((w) => w.id), containsAll([walletAId, walletBId]));
      expect(resultB.walletRecord!.fingerprint, isNotNull);
      expect(resultB.walletRecord!.fingerprint!.length, equals(8));

      // -----------------------------------------------------------------------
      // Step 8: Switch active wallet to B -> verify active pointer
      // -----------------------------------------------------------------------
      await registry.setActiveWalletId(walletBId);
      expect(registry.getActiveWalletId(), equals(walletBId));
      expect(registry.getActiveWallet()?.id, equals(walletBId));

      // -----------------------------------------------------------------------
      // Step 9: Add label to transaction in B -> verify stored in B's namespace, not A's
      // -----------------------------------------------------------------------
      final labelStoreB = WalletLabelStore(prefs, scope: walletBId);
      final labelStoreA = WalletLabelStore(prefs, scope: walletAId);

      await labelStoreB.setTransactionMetadata(
        txId: 'txid_1234567890abcdef',
        label: 'Payment from Alice',
        note: '',
      );

      expect(
        labelStoreB.read().transactionMeta('txid_1234567890abcdef').label,
        equals('Payment from Alice'),
      );
      expect(
        labelStoreA.read().transactionMeta('txid_1234567890abcdef').label,
        isEmpty,
      );
      expect(labelStoreA.read().transactionMetadata, isEmpty);

      // -----------------------------------------------------------------------
      // Step 10: Import Watch-Only Wallet C via AddWallet flow
      // -----------------------------------------------------------------------
      final recordC = await addWalletService.importWatchOnlyWallet(
        externalDescriptor: validTpubC,
        walletName: 'Watch-Only C',
      );
      final walletCId = recordC.id;

      // -----------------------------------------------------------------------
      // Step 11: Verify C is watch-only, has no private keys, has isolated DB
      // -----------------------------------------------------------------------
      expect(recordC.type, equals(WalletType.watchOnly));
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletCId)),
        isNull,
      );
      expect(
        await storage.read(key: WalletStorageKeys.capabilityFor(walletCId)),
        equals(WalletCapability.watchOnly.storageValue),
      );
      final dirC = Directory('${tempDir.path}/wallets/$walletCId');
      expect(await dirC.exists(), isTrue);

      // -----------------------------------------------------------------------
      // Step 12: Verify Decoy wallet mnemonic is untouched
      // -----------------------------------------------------------------------
      expect(
        await storage.read(key: WalletStorageKeys.decoyMnemonic),
        equals('decoy phrase canary 123'),
      );

      // -----------------------------------------------------------------------
      // Step 13: Attempt to sign transaction from C -> verify fails closed
      // -----------------------------------------------------------------------
      final serviceC = BdkWalletService(
        secureStorage: storage,
        walletStoragePathLoader: () async => tempDir.path,
        preferencesLoader: () async => prefs,
        allowCustomEsploraEndpoint: false,
        walletId: walletCId,
      );
      final capC = await serviceC.getCapability();
      expect(capC.isWatchOnly, isTrue);
      expect(await serviceC.getMnemonic(), isNull);
      expect(
        () => serviceC.bumpFee(
          txidHex: '0000000000000000000000000000000000000000000000000000000000000000',
          newFeeRateSatVb: 5,
        ),
        throwsA(
          isA<BdkWalletServiceException>().having(
            (e) => e.toString(),
            'toString()',
            contains('Watch-only wallets cannot sign'),
          ),
        ),
      );

      // -----------------------------------------------------------------------
      // Step 14: Switch between all three wallets (A, B, C) -> verify state
      // -----------------------------------------------------------------------
      await registry.setActiveWalletId(walletAId);
      expect(registry.getActiveWalletId(), equals(walletAId));
      expect(registry.getActiveWallet()?.type, equals(WalletType.signing));

      await registry.setActiveWalletId(walletBId);
      expect(registry.getActiveWalletId(), equals(walletBId));
      expect(registry.getActiveWallet()?.type, equals(WalletType.signing));

      await registry.setActiveWalletId(walletCId);
      expect(registry.getActiveWalletId(), equals(walletCId));
      expect(registry.getActiveWallet()?.type, equals(WalletType.watchOnly));

      // -----------------------------------------------------------------------
      // Step 15: Restart app (simulate restart) -> verify persistence & no re-migration
      // -----------------------------------------------------------------------
      final restartedPrefs = await SharedPreferences.getInstance();
      final restartedRegistry = WalletRegistry(restartedPrefs);
      final restartedMigration = WalletMigrationService(
        secureStorage: storage,
        preferences: restartedPrefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      // No re-migration occurs
      final reMigrate = await restartedMigration.migrateIfNeeded();
      expect(reMigrate, isNull);

      // All three wallets present in registry with C still active
      final restartedWallets = restartedRegistry.getWallets();
      expect(restartedWallets.length, equals(3));
      expect(restartedRegistry.getActiveWalletId(), equals(walletCId));

      // -----------------------------------------------------------------------
      // Step 16: Delete Wallet B -> verify keys/DB deleted, registry has only A and C
      // -----------------------------------------------------------------------
      // Switch active to B first to test deleting active wallet safely
      await restartedRegistry.setActiveWalletId(walletBId);
      expect(restartedRegistry.getActiveWalletId(), equals(walletBId));

      // Switch active safely before delete
      final remainingBeforeDelete = restartedRegistry
          .getWallets()
          .where((w) => w.id != walletBId)
          .toList();
      await restartedRegistry.setActiveWalletId(remainingBeforeDelete.first.id);

      final cleaner = WalletStorageCleaner(
        secureStorage: storage,
        preferences: restartedPrefs,
        walletStoragePathLoader: () async => tempDir.path,
      );
      await cleaner.deleteWalletData(walletBId);
      await restartedRegistry.deleteWallet(walletBId);

      // B's scoped keys and directory are completely deleted
      expect(await storage.read(key: WalletStorageKeys.mnemonicFor(walletBId)), isNull);
      expect(await storage.read(key: WalletStorageKeys.capabilityFor(walletBId)), isNull);
      expect(await dirB.exists(), isFalse);

      // Registry has only A and C
      final remainingWallets = restartedRegistry.getWallets();
      expect(remainingWallets.length, equals(2));
      expect(remainingWallets.map((w) => w.id), containsAll([walletAId, walletCId]));
      expect(remainingWallets.any((w) => w.id == walletBId), isFalse);
      expect(restartedRegistry.getActiveWalletId(), isNot(equals(walletBId)));

      // -----------------------------------------------------------------------
      // Step 17: Verify remaining wallets (A and C) are fully functional
      // -----------------------------------------------------------------------
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletAId)),
        equals(phraseA),
      );
      expect(await copiedDbA.exists(), isTrue);
      expect(
        await storage.read(key: WalletStorageKeys.capabilityFor(walletCId)),
        equals(WalletCapability.watchOnly.storageValue),
      );
      expect(await dirC.exists(), isTrue);

      // -----------------------------------------------------------------------
      // Step 18: Verify duplicate detection: attempt to restore A's mnemonic
      // -----------------------------------------------------------------------
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
    });
  });
}

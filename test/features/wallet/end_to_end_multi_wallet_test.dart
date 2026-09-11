import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/services/add_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_migration_service.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Item 13 & 18: End-To-End Multi-Wallet Provider-Level Test Sequence', () {
    late InMemorySecureStorage storage;
    late SharedPreferences prefs;
    late Directory tempDir;

    const phraseA =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const phraseD =
        'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';
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

    ProviderContainer createContainer([SharedPreferences? customPrefs]) {
      final activePrefs = customPrefs ?? prefs;
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          sharedPreferencesProvider.overrideWith((ref) => activePrefs),
          walletStoragePathProvider.overrideWith((ref) => tempDir.path),
          walletRegistryProvider.overrideWith((ref) => WalletRegistry(activePrefs)),
        ],
      );
      return container;
    }

    test('executes complete provider-level multi-wallet lifecycle (A -> create B -> import C -> restore D) without restart or manual activation', () async {
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
      // Step 2: Initialize app & migration service -> verify migration runs
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

      // -----------------------------------------------------------------------
      // Step 3: Initialize Riverpod ProviderContainer with Migrated Wallet A
      // -----------------------------------------------------------------------
      final container = createContainer();
      addTearDown(container.dispose);

      final registry = WalletRegistry(prefs);
      expect(registry.getActiveWalletId(), equals(walletAId));
      expect(await container.read(activeWalletIdProvider.future), equals(walletAId));
      await container.read(walletsListProvider.future);
      expect(container.read(activeWalletRecordProvider)?.id, equals(walletAId));
      expect(container.read(bdkWalletServiceProvider).walletId, equals(walletAId));

      // Seed draft in sendController to verify reset on wallet switch
      container.read(sendControllerProvider.notifier).setAmountBtc('0.05');
      expect(container.read(sendControllerProvider).draft.amountBtcText, equals('0.05'));

      // -----------------------------------------------------------------------
      // Step 4: Flow 1 (A -> create B -> B active immediately in provider)
      // Executed exactly as CreateWalletPage does
      // -----------------------------------------------------------------------
      final addWalletService = await container.read(addWalletServiceProvider.future);
      final resultB = await addWalletService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Wallet B',
      );
      final walletBId = resultB.walletRecord!.id;
      final phraseB = resultB.recoveryPhrase;

      // Page activates new wallet ID in provider notifier
      await container.read(activeWalletIdProvider.notifier).setActiveWallet(walletBId);
      container.invalidate(walletCapabilityProvider);
      container.invalidate(walletHomeControllerProvider);
      await container.read(walletsListProvider.notifier).refresh();

      // Immediately WITHOUT app restart and WITHOUT manual registry.setActiveWalletId:
      expect(registry.getActiveWalletId(), equals(walletBId));
      expect(container.read(activeWalletIdProvider).value, equals(walletBId));
      expect(container.read(activeWalletRecordProvider)?.id, equals(walletBId));
      expect(container.read(bdkWalletServiceProvider).walletId, equals(walletBId));
      expect(container.read(sendControllerProvider).draft.amountBtcText, isEmpty);

      // Verify Wallet A remained 100% untouched
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletAId)),
        equals(phraseA),
      );
      expect(await copiedDbA.exists(), isTrue);

      // Verify Wallet B has unique ID, scoped keys, isolated DB directory
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
      // Step 5: Add label to transaction in B -> verify stored in B's namespace, not A's
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

      // Seed another send draft before next switch
      container.read(sendControllerProvider.notifier).setAmountBtc('0.10');
      expect(container.read(sendControllerProvider).draft.amountBtcText, equals('0.10'));

      // -----------------------------------------------------------------------
      // Step 6: Flow 2 (B -> import C -> C active immediately in provider)
      // Executed exactly as ImportWatchOnlyPage does
      // -----------------------------------------------------------------------
      final recordC = await addWalletService.importWatchOnlyWallet(
        externalDescriptor: validTpubC,
        walletName: 'Watch-Only C',
      );
      final walletCId = recordC.id;

      // Page activates new wallet ID in provider notifier
      await container.read(activeWalletIdProvider.notifier).setActiveWallet(walletCId);
      container.invalidate(walletCapabilityProvider);
      container.invalidate(walletHomeControllerProvider);
      await container.read(walletsListProvider.notifier).refresh();

      // Immediately WITHOUT app restart:
      expect(registry.getActiveWalletId(), equals(walletCId));
      expect(container.read(activeWalletIdProvider).value, equals(walletCId));
      expect(container.read(activeWalletRecordProvider)?.id, equals(walletCId));
      expect(container.read(bdkWalletServiceProvider).walletId, equals(walletCId));
      expect(container.read(sendControllerProvider).draft.amountBtcText, isEmpty);

      // C is watch-only, has no private keys, has isolated DB
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

      // Decoy wallet mnemonic is untouched
      expect(
        await storage.read(key: WalletStorageKeys.decoyMnemonic),
        equals('decoy phrase canary 123'),
      );

      // Attempt to sign from C fails closed
      final serviceC = container.read(bdkWalletServiceProvider);
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

      // Seed another send draft before next switch
      container.read(sendControllerProvider.notifier).setAmountBtc('0.15');
      expect(container.read(sendControllerProvider).draft.amountBtcText, equals('0.15'));

      // -----------------------------------------------------------------------
      // Step 7: Flow 3 (C -> restore D -> D active immediately in provider)
      // Executed exactly as RestoreWalletPage does
      // -----------------------------------------------------------------------
      final recordD = await addWalletService.restoreWallet(
        mnemonic: phraseD,
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Restored D',
      );
      final walletDId = recordD.id;

      // Page activates new wallet ID in provider notifier
      await container.read(activeWalletIdProvider.notifier).setActiveWallet(walletDId);
      container.invalidate(walletCapabilityProvider);
      container.invalidate(walletHomeControllerProvider);
      await container.read(walletsListProvider.notifier).refresh();

      // Immediately WITHOUT app restart:
      expect(registry.getActiveWalletId(), equals(walletDId));
      expect(container.read(activeWalletIdProvider).value, equals(walletDId));
      expect(container.read(activeWalletRecordProvider)?.id, equals(walletDId));
      expect(container.read(bdkWalletServiceProvider).walletId, equals(walletDId));
      expect(container.read(sendControllerProvider).draft.amountBtcText, isEmpty);

      // All four wallets present in registry
      final allWallets = registry.getWallets();
      expect(allWallets.length, equals(4));
      expect(
        allWallets.map((w) => w.id),
        containsAll([walletAId, walletBId, walletCId, walletDId]),
      );

      // -----------------------------------------------------------------------
      // Step 8: Switch between wallets (A, B, C, D) using provider notifier
      // -----------------------------------------------------------------------
      await container.read(activeWalletIdProvider.notifier).setActiveWallet(walletAId);
      expect(container.read(activeWalletIdProvider).value, equals(walletAId));
      expect(container.read(activeWalletRecordProvider)?.type, equals(WalletType.signing));

      await container.read(activeWalletIdProvider.notifier).setActiveWallet(walletCId);
      expect(container.read(activeWalletIdProvider).value, equals(walletCId));
      expect(container.read(activeWalletRecordProvider)?.type, equals(WalletType.watchOnly));

      // -----------------------------------------------------------------------
      // Step 9: Restart app simulation -> verify persistence & no re-migration
      // -----------------------------------------------------------------------
      final restartedPrefs = await SharedPreferences.getInstance();
      final restartedRegistry = WalletRegistry(restartedPrefs);
      final restartedMigration = WalletMigrationService(
        secureStorage: storage,
        preferences: restartedPrefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      final reMigrate = await restartedMigration.migrateIfNeeded();
      expect(reMigrate, isNull);

      final restartedWallets = restartedRegistry.getWallets();
      expect(restartedWallets.length, equals(4));
      expect(restartedRegistry.getActiveWalletId(), equals(walletCId));

      // -----------------------------------------------------------------------
      // Step 10: Delete Wallet B via WalletsListNotifier.deleteWallet()
      // -----------------------------------------------------------------------
      final restartedContainer = createContainer(restartedPrefs);
      addTearDown(restartedContainer.dispose);

      await restartedContainer.read(walletsListProvider.notifier).deleteWallet(walletBId);

      // B's scoped keys and directory are completely deleted
      expect(await storage.read(key: WalletStorageKeys.mnemonicFor(walletBId)), isNull);
      expect(await storage.read(key: WalletStorageKeys.capabilityFor(walletBId)), isNull);
      expect(await dirB.exists(), isFalse);

      // Registry now has exactly 3 wallets (A, C, D)
      final remainingWallets = restartedRegistry.getWallets();
      expect(remainingWallets.length, equals(3));
      expect(remainingWallets.map((w) => w.id), containsAll([walletAId, walletCId, walletDId]));
      expect(remainingWallets.any((w) => w.id == walletBId), isFalse);

      // -----------------------------------------------------------------------
      // Step 11: Verify remaining wallets (A, C, D) are intact and functional
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
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletDId)),
        equals(phraseD),
      );

      // -----------------------------------------------------------------------
      // Step 12: Duplicate detection: attempt to restore A's mnemonic throws
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

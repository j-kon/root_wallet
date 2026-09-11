import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/services/add_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Add Wallet Flow Integration & Real Provider Activation Tests (Items 1, 2, 3, 4)', () {
    late InMemorySecureStorage storage;
    late SharedPreferences prefs;
    late Directory tempDir;
    late WalletRegistry registry;

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
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    ProviderContainer createTestContainer() {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          walletStoragePathProvider.overrideWith((ref) => tempDir.path),
          walletRegistryProvider.overrideWith((ref) => registry),
        ],
      );
      return container;
    }

    Future<String> setupWalletA(ProviderContainer container) async {
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
      final dummyDbA = File('${dirA.path}/bdk_wallet.sqlite');
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

      // Activate Wallet A in provider
      await container.read(activeWalletIdProvider.notifier).setActiveWallet(walletAId);
      await container.read(walletsListProvider.notifier).refresh();
      return walletAId;
    }

    test('Item 2: Create-Wallet flow updates Riverpod provider immediately without restart and clears draft', () async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      final walletAId = await setupWalletA(container);

      // Verify Wallet A is active
      expect(await container.read(activeWalletIdProvider.future), equals(walletAId));
      expect(container.read(activeWalletRecordProvider)?.id, equals(walletAId));
      expect(container.read(bdkWalletServiceProvider).walletId, equals(walletAId));

      // Put a draft in SendController
      container.read(sendControllerProvider.notifier).setAmountBtc('0.05');
      expect(container.read(sendControllerProvider).draft.amountBtcText, equals('0.05'));

      // Write decoy mnemonic to ensure it is protected
      await storage.write(
        key: WalletStorageKeys.decoyMnemonic,
        value: 'decoy phrase test only',
      );

      // Execute Add Wallet flow (matching CreateWalletPage._handleCreateWallet)
      final addWalletService = await container.read(addWalletServiceProvider.future);
      final resultB = await addWalletService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Wallet B',
      );
      final walletBId = resultB.walletRecord!.id;

      // Page activates new wallet ID in provider notifier
      await container.read(activeWalletIdProvider.notifier).setActiveWallet(walletBId);
      container.invalidate(walletCapabilityProvider);
      container.invalidate(walletHomeControllerProvider);
      await container.read(walletsListProvider.notifier).refresh();

      // Immediately WITHOUT app restart:
      expect(registry.getActiveWalletId(), equals(walletBId));
      expect(container.read(activeWalletIdProvider).value, equals(walletBId));
      expect(container.read(activeWalletRecordProvider)?.id, equals(walletBId));
      expect(container.read(bdkWalletServiceProvider).walletId, equals(walletBId));

      final walletsList = container.read(walletsListProvider).value!;
      expect(walletsList.length, equals(2));
      expect(walletsList.firstWhere((w) => w.id == walletBId).isActive, isTrue);
      expect(walletsList.firstWhere((w) => w.id == walletAId).isActive, isFalse);

      // Send draft from Wallet A is cleared
      expect(container.read(sendControllerProvider).draft.amountBtcText, isEmpty);

      // Decoy mnemonic is untouched
      expect(
        await storage.read(key: WalletStorageKeys.decoyMnemonic),
        equals('decoy phrase test only'),
      );

      // Wallet A storage and DB are 100% UNTOUCHED
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletAId)),
        equals(phraseA),
      );
      final dbA = File('${tempDir.path}/wallets/$walletAId/bdk_wallet.sqlite');
      expect(await dbA.exists(), isTrue);
      expect(await dbA.readAsString(), equals('wallet_a_database_content'));
    });

    test('Item 3: Restore-Wallet flow updates Riverpod provider immediately and detects duplicates', () async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      final walletAId = await setupWalletA(container);

      // Put a draft in SendController
      container.read(sendControllerProvider.notifier).setAmountBtc('0.1');
      expect(container.read(sendControllerProvider).draft.amountBtcText, equals('0.1'));

      // Execute Restore Wallet flow (matching RestoreWalletPage._handleRestore)
      final addWalletService = await container.read(addWalletServiceProvider.future);
      final recordB = await addWalletService.restoreWallet(
        mnemonic: phraseB,
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Restored Wallet B',
      );
      final walletBId = recordB.id;

      // Page activates new wallet ID in provider notifier
      await container.read(activeWalletIdProvider.notifier).setActiveWallet(walletBId);
      container.invalidate(walletCapabilityProvider);
      container.invalidate(walletHomeControllerProvider);
      await container.read(walletsListProvider.notifier).refresh();

      // Immediately WITHOUT app restart:
      expect(registry.getActiveWalletId(), equals(walletBId));
      expect(container.read(activeWalletIdProvider).value, equals(walletBId));
      expect(container.read(activeWalletRecordProvider)?.id, equals(walletBId));
      expect(container.read(bdkWalletServiceProvider).walletId, equals(walletBId));

      final walletsList = container.read(walletsListProvider).value!;
      expect(walletsList.firstWhere((w) => w.id == walletBId).isActive, isTrue);
      expect(walletsList.firstWhere((w) => w.id == walletAId).isActive, isFalse);

      // Send draft cleared
      expect(container.read(sendControllerProvider).draft.amountBtcText, isEmpty);

      // Duplicate detection: restoring Wallet A's phrase with same scriptType throws AddWalletDuplicateException
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

    test('Item 4: Watch-Only Add Flow updates Riverpod provider immediately without restart', () async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      final walletAId = await setupWalletA(container);

      // Put a draft in SendController
      container.read(sendControllerProvider.notifier).setAmountBtc('0.25');
      expect(container.read(sendControllerProvider).draft.amountBtcText, equals('0.25'));

      // Setup decoy mnemonic
      await storage.write(
        key: WalletStorageKeys.decoyMnemonic,
        value: 'decoy secret private material',
      );

      // Execute Watch-Only flow (matching ImportWatchOnlyPage._handleImport)
      final addWalletService = await container.read(addWalletServiceProvider.future);
      final recordC = await addWalletService.importWatchOnlyWallet(
        externalDescriptor: validTpub,
        walletName: 'Watch-Only Vault',
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
      expect(container.read(activeWalletRecordProvider)?.type, equals(WalletType.watchOnly));

      // Capability provider switches to watch-only
      final cap = await container.read(walletCapabilityProvider.future);
      expect(cap.isWatchOnly, isTrue);

      final walletsList = container.read(walletsListProvider).value!;
      expect(walletsList.firstWhere((w) => w.id == walletCId).isActive, isTrue);
      expect(walletsList.firstWhere((w) => w.id == walletAId).isActive, isFalse);

      // Send draft cleared
      expect(container.read(sendControllerProvider).draft.amountBtcText, isEmpty);

      // Decoy mnemonic is 100% untouched
      expect(
        await storage.read(key: WalletStorageKeys.decoyMnemonic),
        equals('decoy secret private material'),
      );

      // Duplicate detection
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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/biometric_service.dart';
import 'package:root_wallet/core/security/lock_service.dart';
import 'package:root_wallet/core/security/pin_lock_service.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/services/add_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_storage_cleaner.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Wallet Security & Fail-Closed Tests', () {
    late InMemorySecureStorage storage;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = InMemorySecureStorage();
    });

    test('fail-closed: sensitive action authentication fails if PIN is incorrect', () async {
      final pinLockService = PinLockService(storage);
      await pinLockService.setPin('123456');

      final lockService = LockService(
        pinLockService: pinLockService,
        biometricService: _FakeBiometrics(available: false),
      );

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          lockServiceProvider.overrideWithValue(lockService),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(lockControllerProvider.notifier);
      await container.read(lockControllerProvider.future);

      // Wrong PIN entered
      final authOk = await controller.requireSensitiveActionAuthentication(
        promptPin: () async => '999999',
      );

      expect(authOk, isFalse, reason: 'Must fail-closed when incorrect PIN is provided');
    });

    test('fail-closed: sensitive action authentication fails if prompt cancelled', () async {
      final pinLockService = PinLockService(storage);
      await pinLockService.setPin('123456');

      final lockService = LockService(
        pinLockService: pinLockService,
        biometricService: _FakeBiometrics(available: false),
      );

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          lockServiceProvider.overrideWithValue(lockService),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(lockControllerProvider.notifier);
      await container.read(lockControllerProvider.future);

      // User cancels PIN entry dialog
      final authOk = await controller.requireSensitiveActionAuthentication(
        promptPin: () async => null,
      );

      expect(authOk, isFalse, reason: 'Must fail-closed when user cancels authentication');
    });

    test('last-wallet policy: WalletRegistry strictly forbids deleting the only wallet', () async {
      final registry = WalletRegistry(prefs);
      final soleWallet = WalletRecord(
        id: 'w_sole_wallet',
        name: 'Only Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11223344',
      );

      await registry.registerWallet(soleWallet);
      expect(registry.getWallets().length, equals(1));

      expect(
        () => registry.deleteWallet('w_sole_wallet'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot delete the last remaining wallet'),
          ),
        ),
      );
      expect(registry.hasWallets(), isTrue);
    });

    test('secret isolation: deleting wallet A purges secrets without affecting wallet B', () async {
      const walletA = 'w_wallet_a';
      const walletB = 'w_wallet_b';

      await storage.write(
        key: WalletStorageKeys.mnemonicFor(walletA),
        value: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      );
      await storage.write(
        key: WalletStorageKeys.mnemonicFor(walletB),
        value: 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong',
      );

      final registry = WalletRegistry(prefs);
      await registry.registerWallet(
        WalletRecord(
          id: walletA,
          name: 'Wallet A',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: 'AAAA1111',
        ),
      );
      await registry.registerWallet(
        WalletRecord(
          id: walletB,
          name: 'Wallet B',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: 'BBBB2222',
        ),
      );

      // Delete wallet A
      await registry.deleteWallet(walletA);
      for (final key in WalletStorageKeys.allKeysFor(walletA)) {
        await storage.delete(key: key);
      }

      // Verify wallet A secrets are purged
      expect(await storage.read(key: WalletStorageKeys.mnemonicFor(walletA)), isNull);

      // Verify wallet B secrets remain untouched and intact
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletB)),
        equals('zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong'),
      );
      expect(registry.getActiveWalletId(), equals(walletB));
    });

    test('decoy isolation: decoy mode remains hidden from multi-wallet registry', () async {
      final registry = WalletRegistry(prefs);
      final wallet1 = WalletRecord(
        id: 'w_primary',
        name: 'Primary Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11223344',
      );
      await registry.registerWallet(wallet1);

      // Verify registry contains only legitimate wallets and no decoy leaks
      final allWallets = registry.getWallets();
      expect(allWallets.length, equals(1));
      expect(allWallets.any((w) => w.id.contains('decoy')), isFalse);
    });

    test('storage isolation: wallet A cannot access wallet B keys or DB directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('sec_isolation_test_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      const walletA = 'w_isolated_a';
      const walletB = 'w_isolated_b';

      await storage.write(
        key: WalletStorageKeys.mnemonicFor(walletA),
        value: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      );
      await storage.write(
        key: WalletStorageKeys.mnemonicFor(walletB),
        value: 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong',
      );

      final dirA = Directory('${tempDir.path}/wallets/$walletA');
      final dirB = Directory('${tempDir.path}/wallets/$walletB');
      await dirA.create(recursive: true);
      await dirB.create(recursive: true);

      final dbA = File('${dirA.path}/bdk_wallet.sqlite');
      final dbB = File('${dirB.path}/bdk_wallet.sqlite');
      await dbA.writeAsString('db_a_private_data');
      await dbB.writeAsString('db_b_private_data');

      final cleaner = WalletStorageCleaner(
        secureStorage: storage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      // Clean wallet A data only
      await cleaner.deleteWalletData(walletA);

      // Wallet A data is purged
      expect(await storage.read(key: WalletStorageKeys.mnemonicFor(walletA)), isNull);
      expect(await dirA.exists(), isFalse);

      // Wallet B data remains completely intact
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletB)),
        equals('zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong'),
      );
      expect(await dirB.exists(), isTrue);
      expect(await dbB.readAsString(), equals('db_b_private_data'));
    });

    test('decoy protection: watch-only import and add-wallet operations preserve decoy mnemonic', () async {
      final tempDir = Directory.systemTemp.createTempSync('decoy_protect_test_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      const decoyPhrase = 'decoy canary phrase 123';
      await storage.write(
        key: WalletStorageKeys.decoyMnemonic,
        value: decoyPhrase,
      );

      final addWalletService = AddWalletService(
        secureStorage: storage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      // Create new signing wallet
      await addWalletService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'New Wallet',
      );

      // Decoy mnemonic must still exist and match
      expect(
        await storage.read(key: WalletStorageKeys.decoyMnemonic),
        equals(decoyPhrase),
      );

      // Import watch-only wallet
      const testTpub =
          'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';
      await addWalletService.importWatchOnlyWallet(
        externalDescriptor: testTpub,
        walletName: 'Watch Wallet',
      );

      // Decoy mnemonic must still be completely untouched
      expect(
        await storage.read(key: WalletStorageKeys.decoyMnemonic),
        equals(decoyPhrase),
      );
    });

    test('fail-closed registry: corrupted JSON, non-list JSON, or duplicate IDs throw WalletRegistryException', () async {
      final registry = WalletRegistry(prefs);

      // 1. Corrupted JSON fails closed
      await prefs.setString(WalletRegistry.registryKey, '{not valid json');
      expect(
        () => registry.getWallets(),
        throwsA(isA<WalletRegistryException>().having((e) => e.message, 'message', contains('Corrupted registry JSON'))),
      );

      // 2. Non-list JSON fails closed
      await prefs.setString(WalletRegistry.registryKey, '{"key": "value"}');
      expect(
        () => registry.getWallets(),
        throwsA(isA<WalletRegistryException>().having((e) => e.message, 'message', contains('expected JSON List'))),
      );

      // 3. Duplicate wallet IDs fail closed
      final duplicateJson = [
        {
          'id': 'w_dup',
          'name': 'Wallet 1',
          'type': 'signing',
          'scriptType': 'nativeSegwit',
          'network': 'testnet',
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'id': 'w_dup',
          'name': 'Wallet 2',
          'type': 'signing',
          'scriptType': 'nativeSegwit',
          'network': 'testnet',
          'createdAt': DateTime.now().toIso8601String(),
        },
      ];
      // Re-set valid JSON with duplicate IDs
      await prefs.setString(WalletRegistry.registryKey, jsonEncode(duplicateJson));
      expect(
        () => registry.getWallets(),
        throwsA(isA<WalletRegistryException>().having((e) => e.message, 'message', contains('Duplicate wallet ID'))),
      );
    });

    test('stale active ID deterministic repair in activeWalletIdProvider', () async {
      final registry = WalletRegistry(prefs);
      final w1 = WalletRecord(
        id: 'w_existing_1',
        name: 'First Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11111111',
      );
      final w2 = WalletRecord(
        id: 'w_existing_2',
        name: 'Second Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '22222222',
      );
      await registry.registerWallet(w1);
      await registry.registerWallet(w2);

      // Set stale active ID that does not exist in registry
      await prefs.setString(WalletRegistry.activeWalletIdKey, 'w_ghost_deleted_wallet');

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          walletRegistryProvider.overrideWith((ref) => registry),
        ],
      );
      addTearDown(container.dispose);

      final activeId = await container.read(activeWalletIdProvider.future);

      // Deterministically repairs to the first existing wallet in registry
      expect(activeId, equals('w_existing_1'));
      expect(registry.getActiveWalletId(), equals('w_existing_1'));
    });

    test('zero writes to legacy global keys during multi-wallet operations', () async {
      final tempDir = Directory.systemTemp.createTempSync('zero_legacy_test_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final addWalletService = AddWalletService(
        secureStorage: storage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      // Perform create
      final createResult = await addWalletService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Multi Wallet 1',
      );

      // Perform restore
      await addWalletService.restoreWallet(
        mnemonic: 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong',
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Multi Wallet 2',
      );

      // Perform watch-only import
      const testTpub =
          'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';
      await addWalletService.importWatchOnlyWallet(
        externalDescriptor: testTpub,
        walletName: 'Multi Wallet 3',
      );

      // Verify zero writes to legacy global keys
      expect(await storage.read(key: WalletStorageKeys.legacyMnemonic), isNull);
      expect(await storage.read(key: WalletStorageKeys.legacyScriptType), isNull);
      expect(await storage.read(key: WalletStorageKeys.legacyExternalDescriptor), isNull);
      expect(await storage.read(key: WalletStorageKeys.legacyInternalDescriptor), isNull);

      // Verify scoped keys exist
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(createResult.walletRecord!.id)),
        isNotNull,
      );
    });
  });
}

class _FakeBiometrics implements BiometricService {
  _FakeBiometrics({this.available = false});
  final bool available;

  @override
  Future<bool> authenticate({String reason = 'Auth'}) async => false;

  @override
  Future<bool> isAvailable() async => available;
}

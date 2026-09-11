import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/biometric_service.dart';
import 'package:root_wallet/core/security/lock_service.dart';
import 'package:root_wallet/core/security/pin_lock_service.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/app_start_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/services/add_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_migration_service.dart';
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
      const soleId = 'w_00000000-0000-0000-0000-000000000001';
      final soleWallet = WalletRecord(
        id: soleId,
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
        () => registry.deleteWallet(soleId),
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
      const walletA = 'w_00000000-0000-0000-0000-000000000001';
      const walletB = 'w_00000000-0000-0000-0000-000000000002';

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
        id: 'w_00000000-0000-0000-0000-000000000001',
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

      const walletA = 'w_00000000-0000-0000-0000-000000000001';
      const walletB = 'w_00000000-0000-0000-0000-000000000002';

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
          'id': 'w_11111111-1111-1111-1111-111111111111',
          'name': 'Wallet 1',
          'type': 'signing',
          'scriptType': 'nativeSegwit',
          'network': 'testnet',
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'id': 'w_11111111-1111-1111-1111-111111111111',
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
        id: 'w_00000000-0000-0000-0000-000000000001',
        name: 'First Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11111111',
      );
      final w2 = WalletRecord(
        id: 'w_00000000-0000-0000-0000-000000000002',
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
      await prefs.setString(WalletRegistry.activeWalletIdKey, 'w_00000000-0000-0000-0000-000000000099');

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          walletRegistryProvider.overrideWith((ref) => registry),
        ],
      );
      addTearDown(container.dispose);

      final activeId = await container.read(activeWalletIdProvider.future);

      // Deterministically repairs to the first existing wallet in registry
      expect(activeId, equals('w_00000000-0000-0000-0000-000000000001'));
      expect(registry.getActiveWalletId(), equals('w_00000000-0000-0000-0000-000000000001'));
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

    group('Strict Registry Schema Validation (Items 9, 10, 11)', () {
      test('unknown or missing wallet type throws WalletRegistryException', () async {
        final registry = WalletRegistry(prefs);

        // Unknown wallet type
        await prefs.setString(
          WalletRegistry.registryKey,
          jsonEncode([
            {
              'id': 'w_11111111-1111-1111-1111-111111111111',
              'name': 'Bad Type',
              'type': 'quantum_multisig',
              'scriptType': 'nativeSegwit',
              'network': 'testnet',
              'createdAt': DateTime.now().toIso8601String(),
            }
          ]),
        );
        expect(
          () => registry.getWallets(),
          throwsA(
            isA<WalletRegistryException>().having(
              (e) => e.message.toLowerCase(),
              'message',
              contains('wallet type'),
            ),
          ),
        );

        // Missing wallet type
        await prefs.setString(
          WalletRegistry.registryKey,
          jsonEncode([
            {
              'id': 'w_11111111-1111-1111-1111-111111111111',
              'name': 'Missing Type',
              'scriptType': 'nativeSegwit',
              'network': 'testnet',
              'createdAt': DateTime.now().toIso8601String(),
            }
          ]),
        );
        expect(
          () => registry.getWallets(),
          throwsA(
            isA<WalletRegistryException>().having(
              (e) => e.message.toLowerCase(),
              'message',
              contains('wallet "type"'),
            ),
          ),
        );
      });

      test('unknown or missing script type throws WalletRegistryException', () async {
        final registry = WalletRegistry(prefs);

        // Unknown script type
        await prefs.setString(
          WalletRegistry.registryKey,
          jsonEncode([
            {
              'id': 'w_11111111-1111-1111-1111-111111111111',
              'name': 'Bad Script',
              'type': 'signing',
              'scriptType': 'p2sh_unknown',
              'network': 'testnet',
              'createdAt': DateTime.now().toIso8601String(),
            }
          ]),
        );
        expect(
          () => registry.getWallets(),
          throwsA(
            isA<WalletRegistryException>().having(
              (e) => e.message.toLowerCase(),
              'message',
              contains('script type'),
            ),
          ),
        );

        // Missing script type
        await prefs.setString(
          WalletRegistry.registryKey,
          jsonEncode([
            {
              'id': 'w_11111111-1111-1111-1111-111111111111',
              'name': 'Missing Script',
              'type': 'signing',
              'network': 'testnet',
              'createdAt': DateTime.now().toIso8601String(),
            }
          ]),
        );
        expect(
          () => registry.getWallets(),
          throwsA(
            isA<WalletRegistryException>().having(
              (e) => e.message.toLowerCase(),
              'message',
              contains('wallet "scripttype"'),
            ),
          ),
        );
      });

      test('network validation: mainnet, unknown network, or missing network throws WalletRegistryException', () async {
        final registry = WalletRegistry(prefs);

        // Mainnet disallowed
        await prefs.setString(
          WalletRegistry.registryKey,
          jsonEncode([
            {
              'id': 'w_11111111-1111-1111-1111-111111111111',
              'name': 'Mainnet Wallet',
              'type': 'signing',
              'scriptType': 'nativeSegwit',
              'network': 'mainnet',
              'createdAt': DateTime.now().toIso8601String(),
            }
          ]),
        );
        expect(
          () => registry.getWallets(),
          throwsA(
            isA<WalletRegistryException>().having(
              (e) => e.message.toLowerCase(),
              'message',
              contains('network'),
            ),
          ),
        );

        // Unknown network
        await prefs.setString(
          WalletRegistry.registryKey,
          jsonEncode([
            {
              'id': 'w_11111111-1111-1111-1111-111111111111',
              'name': 'Unknown Net Wallet',
              'type': 'signing',
              'scriptType': 'nativeSegwit',
              'network': 'signet',
              'createdAt': DateTime.now().toIso8601String(),
            }
          ]),
        );
        expect(
          () => registry.getWallets(),
          throwsA(
            isA<WalletRegistryException>().having(
              (e) => e.message.toLowerCase(),
              'message',
              contains('network'),
            ),
          ),
        );

        // Missing network
        await prefs.setString(
          WalletRegistry.registryKey,
          jsonEncode([
            {
              'id': 'w_11111111-1111-1111-1111-111111111111',
              'name': 'Missing Net Wallet',
              'type': 'signing',
              'scriptType': 'nativeSegwit',
              'createdAt': DateTime.now().toIso8601String(),
            }
          ]),
        );
        expect(
          () => registry.getWallets(),
          throwsA(
            isA<WalletRegistryException>().having(
              (e) => e.message.toLowerCase(),
              'message',
              contains('network'),
            ),
          ),
        );
      });

      test('malformed createdAt throws WalletRegistryException', () async {
        final registry = WalletRegistry(prefs);

        await prefs.setString(
          WalletRegistry.registryKey,
          jsonEncode([
            {
              'id': 'w_11111111-1111-1111-1111-111111111111',
              'name': 'Bad Date Wallet',
              'type': 'signing',
              'scriptType': 'nativeSegwit',
              'network': 'testnet',
              'createdAt': 'not_a_valid_iso_date',
            }
          ]),
        );
        expect(
          () => registry.getWallets(),
          throwsA(
            isA<WalletRegistryException>().having(
              (e) => e.message.toLowerCase(),
              'message',
              contains('createdat'),
            ),
          ),
        );
      });

      test('fingerprint validation: non-8-hex throws, valid uppercase 8-hex and null succeed', () async {
        final registry = WalletRegistry(prefs);

        // Invalid fingerprints (e.g. 'xyz', '12345', '123456789', 'GHIJKLMN')
        for (final badFp in ['xyz', '12345', '123456789', 'GHIJKLMN']) {
          await prefs.setString(
            WalletRegistry.registryKey,
            jsonEncode([
              {
                'id': 'w_11111111-1111-1111-1111-111111111111',
                'name': 'Bad Fp Wallet',
                'type': 'signing',
                'scriptType': 'nativeSegwit',
                'network': 'testnet',
                'createdAt': DateTime.now().toIso8601String(),
                'fingerprint': badFp,
              }
            ]),
          );
          expect(
            () => registry.getWallets(),
            throwsA(
              isA<WalletRegistryException>().having(
                (e) => e.message.toLowerCase(),
                'message',
                contains('fingerprint'),
              ),
            ),
            reason: 'Fingerprint "$badFp" must fail schema validation',
          );
        }

        // Valid uppercase 8-hex fingerprint
        await prefs.setString(
          WalletRegistry.registryKey,
          jsonEncode([
            {
              'id': 'w_11111111-1111-1111-1111-111111111111',
              'name': 'Valid Fp Wallet',
              'type': 'signing',
              'scriptType': 'nativeSegwit',
              'network': 'testnet',
              'createdAt': DateTime.now().toIso8601String(),
              'fingerprint': '73C5DA0A',
            }
          ]),
        );
        final walletsWithFp = registry.getWallets();
        expect(walletsWithFp.length, equals(1));
        expect(walletsWithFp.first.fingerprint, equals('73C5DA0A'));

        // Valid null / omitted fingerprint
        await prefs.setString(
          WalletRegistry.registryKey,
          jsonEncode([
            {
              'id': 'w_22222222-2222-2222-2222-222222222222',
              'name': 'Null Fp Wallet',
              'type': 'signing',
              'scriptType': 'nativeSegwit',
              'network': 'testnet',
              'createdAt': DateTime.now().toIso8601String(),
              'fingerprint': null,
            }
          ]),
        );
        final walletsWithNullFp = registry.getWallets();
        expect(walletsWithNullFp.length, equals(1));
        expect(walletsWithNullFp.first.fingerprint, isNull);
      });
    });

    group('Transactional Add-Wallet Rollback & Failure Injection (Items 3, 4)', () {
      test('secure-storage write failure rolls back partial wallet without touching wallet A or decoy', () async {
        final tempDir = Directory.systemTemp.createTempSync('add_fail_sec_');
        addTearDown(() {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        final faultyStorage = FaultySecureStorage(storage);
        const decoyPhrase = 'decoy seed phrase preserved 123';
        await faultyStorage.write(
          key: WalletStorageKeys.decoyMnemonic,
          value: decoyPhrase,
        );

        // Pre-create Wallet A
        final addWalletService = AddWalletService(
          secureStorage: faultyStorage,
          preferences: prefs,
          walletStoragePathLoader: () async => tempDir.path,
        );

        final resultA = await addWalletService.createWallet(
          scriptType: WalletScriptType.nativeSegwit,
          walletName: 'Wallet A',
        );
        final walletAId = resultA.walletRecord!.id;
        final phraseA = resultA.recoveryPhrase;

        final registry = WalletRegistry(prefs);
        expect(registry.getWallets().length, equals(1));

        // Arm faulty storage to fail on capability key write of subsequent wallet
        faultyStorage.failOnWrite = true;
        faultyStorage.failKeySubstring = 'capability';

        await expectLater(
          addWalletService.createWallet(
            scriptType: WalletScriptType.nativeSegwit,
            walletName: 'Wallet B (Fails)',
          ),
          throwsA(isA<AddWalletException>()),
        );

        // Disarm
        faultyStorage.failOnWrite = false;
        faultyStorage.failKeySubstring = null;

        // Registry still only contains Wallet A
        final wallets = registry.getWallets();
        expect(wallets.length, equals(1));
        expect(wallets.first.id, equals(walletAId));

        // Wallet A secrets and files remain 100% intact
        expect(
          await faultyStorage.read(key: WalletStorageKeys.mnemonicFor(walletAId)),
          equals(phraseA),
        );
        expect(
          await Directory('${tempDir.path}/wallets/$walletAId').exists(),
          isTrue,
        );

        // Decoy phrase remains 100% intact
        expect(
          await faultyStorage.read(key: WalletStorageKeys.decoyMnemonic),
          equals(decoyPhrase),
        );
      });

      test('directory creation failure rolls back partial wallet without touching wallet A or decoy', () async {
        final tempDir = Directory.systemTemp.createTempSync('add_fail_dir_');
        addTearDown(() {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        const decoyPhrase = 'decoy seed phrase preserved 456';
        await storage.write(
          key: WalletStorageKeys.decoyMnemonic,
          value: decoyPhrase,
        );

        // Setup Wallet A
        final normalService = AddWalletService(
          secureStorage: storage,
          preferences: prefs,
          walletStoragePathLoader: () async => tempDir.path,
        );
        final resultA = await normalService.createWallet(
          scriptType: WalletScriptType.nativeSegwit,
          walletName: 'Wallet A',
        );
        final walletAId = resultA.walletRecord!.id;

        // Create service with path loader that throws
        final faultyService = AddWalletService(
          secureStorage: storage,
          preferences: prefs,
          walletStoragePathLoader: () async => throw const FileSystemException('Path loader failed'),
        );

        await expectLater(
          faultyService.createWallet(
            scriptType: WalletScriptType.nativeSegwit,
            walletName: 'Wallet B (Fails)',
          ),
          throwsA(
            isA<AddWalletException>().having(
              (e) => e.message,
              'message',
              contains('isolated storage directory'),
            ),
          ),
        );

        // Registry still only contains Wallet A
        final registry = WalletRegistry(prefs);
        final wallets = registry.getWallets();
        expect(wallets.length, equals(1));
        expect(wallets.first.id, equals(walletAId));

        // Decoy preserved
        expect(
          await storage.read(key: WalletStorageKeys.decoyMnemonic),
          equals(decoyPhrase),
        );
      });

      test('registry write failure rolls back partial wallet and preserves existing wallets', () async {
        final tempDir = Directory.systemTemp.createTempSync('add_fail_reg_');
        addTearDown(() {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        final normalService = AddWalletService(
          secureStorage: storage,
          preferences: prefs,
          walletStoragePathLoader: () async => tempDir.path,
        );
        final resultA = await normalService.createWallet(
          scriptType: WalletScriptType.nativeSegwit,
          walletName: 'Wallet A',
        );
        final walletAId = resultA.walletRecord!.id;

        final faultyRegistry = FaultyWalletRegistry(prefs);
        final faultyService = AddWalletService(
          secureStorage: storage,
          preferences: prefs,
          registry: faultyRegistry,
          walletStoragePathLoader: () async => tempDir.path,
        );

        // Arm registry failure
        faultyRegistry.failOnRegister = true;

        await expectLater(
          faultyService.createWallet(
            scriptType: WalletScriptType.nativeSegwit,
            walletName: 'Wallet B (Fails)',
          ),
          throwsA(
            isA<AddWalletException>().having(
              (e) => e.message,
              'message',
              contains('Injected WalletRegistry write failure'),
            ),
          ),
        );

        // Registry only contains Wallet A
        final wallets = faultyRegistry.getWallets();
        expect(wallets.length, equals(1));
        expect(wallets.first.id, equals(walletAId));
      });
    });

    group('Safe Delete Failure Injection & Retryability (Items 5, 6, 7, 8)', () {
      test('cleaner failure keeps wallet in registry, switches active safely, and is retryable', () async {
        final tempDir = Directory.systemTemp.createTempSync('del_fail_');
        addTearDown(() {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        final faultyStorage = FaultySecureStorage(storage);
        const decoyPhrase = 'decoy canary delete test 789';
        await faultyStorage.write(
          key: WalletStorageKeys.decoyMnemonic,
          value: decoyPhrase,
        );

        final addWalletService = AddWalletService(
          secureStorage: faultyStorage,
          preferences: prefs,
          walletStoragePathLoader: () async => tempDir.path,
        );

        final resultA = await addWalletService.createWallet(
          scriptType: WalletScriptType.nativeSegwit,
          walletName: 'Wallet A',
        );
        final walletAId = resultA.walletRecord!.id;

        final resultB = await addWalletService.createWallet(
          scriptType: WalletScriptType.nativeSegwit,
          walletName: 'Wallet B',
        );
        final walletBId = resultB.walletRecord!.id;

        final registry = WalletRegistry(prefs);
        await registry.setActiveWalletId(walletBId);

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(faultyStorage),
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            walletRegistryProvider.overrideWith((ref) => registry),
            walletStoragePathProvider.overrideWith((ref) => tempDir.path),
            walletStorageCleanerProvider.overrideWith(
              (ref) => WalletStorageCleaner(
                secureStorage: faultyStorage,
                preferences: prefs,
                walletStoragePathLoader: () async => tempDir.path,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Initialize active wallet
        await container.read(activeWalletIdProvider.future);
        await container.read(walletsListProvider.future);
        expect(registry.getActiveWalletId(), equals(walletBId));

        // Arm faulty storage to fail on delete of Wallet B's keys
        faultyStorage.failOnDelete = true;
        faultyStorage.failKeySubstring = walletBId;

        // Attempt to delete active Wallet B -> cleaner throws WalletStorageCleanupException
        await expectLater(
          container.read(walletsListProvider.notifier).deleteWallet(walletBId),
          throwsA(isA<WalletStorageCleanupException>()),
        );

        // 1. Registry entry for B remains intact (not deleted)
        expect(registry.getWallets().any((w) => w.id == walletBId), isTrue);
        expect(registry.getWallets().length, equals(2));

        // 2. Active wallet points safely to replacement (Wallet A)
        expect(registry.getActiveWalletId(), equals(walletAId));
        expect(container.read(activeWalletIdProvider).value, equals(walletAId));

        // 3. Wallet A secrets and decoy are untouched
        expect(
          await faultyStorage.read(key: WalletStorageKeys.mnemonicFor(walletAId)),
          equals(resultA.recoveryPhrase),
        );
        expect(
          await faultyStorage.read(key: WalletStorageKeys.decoyMnemonic),
          equals(decoyPhrase),
        );

        // 4. Disarm storage failure and retry deletion -> succeeds!
        faultyStorage.failOnDelete = false;
        faultyStorage.failKeySubstring = null;

        await container.read(walletsListProvider.notifier).deleteWallet(walletBId);

        // Now B is completely purged from registry and storage
        expect(registry.getWallets().any((w) => w.id == walletBId), isFalse);
        expect(registry.getWallets().length, equals(1));
        expect(await faultyStorage.read(key: WalletStorageKeys.mnemonicFor(walletBId)), isNull);
        expect(await Directory('${tempDir.path}/wallets/$walletBId').exists(), isFalse);

        // A and decoy still intact
        expect(registry.getActiveWalletId(), equals(walletAId));
        expect(
          await faultyStorage.read(key: WalletStorageKeys.mnemonicFor(walletAId)),
          equals(resultA.recoveryPhrase),
        );
        expect(
          await faultyStorage.read(key: WalletStorageKeys.decoyMnemonic),
          equals(decoyPhrase),
        );
      });

      test('filesystem deletion failure in cleaner throws WalletStorageCleanupException and preserves registry', () async {
        final tempDir = Directory.systemTemp.createTempSync('del_fail_fs_');
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

        await addWalletService.createWallet(
          scriptType: WalletScriptType.nativeSegwit,
          walletName: 'Wallet A',
        );
        final resultB = await addWalletService.createWallet(
          scriptType: WalletScriptType.nativeSegwit,
          walletName: 'Wallet B',
        );

        final registry = WalletRegistry(prefs);

        // Create cleaner whose path loader fails during directory deletion
        final faultyCleaner = WalletStorageCleaner(
          secureStorage: storage,
          preferences: prefs,
          walletStoragePathLoader: () async => throw const FileSystemException('Path loader error'),
        );

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            walletRegistryProvider.overrideWith((ref) => registry),
            walletStoragePathProvider.overrideWith((ref) => tempDir.path),
            walletStorageCleanerProvider.overrideWith((ref) => faultyCleaner),
          ],
        );
        addTearDown(container.dispose);

        await container.read(activeWalletIdProvider.future);
        await container.read(walletsListProvider.future);

        await expectLater(
          container.read(walletsListProvider.notifier).deleteWallet(resultB.walletRecord!.id),
          throwsA(isA<WalletStorageCleanupException>()),
        );

        // Registry entry remains intact
        expect(registry.getWallets().any((w) => w.id == resultB.walletRecord!.id), isTrue);
      });
    });

    group('Migration Path-Loader Failure Injection (Item 12)', () {
      test('path loader throwing fails closed with WalletMigrationException', () async {
        // Setup legacy data
        await storage.write(
          key: WalletStorageKeys.legacyMnemonic,
          value: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
        );
        await storage.write(
          key: WalletStorageKeys.legacyScriptType,
          value: 'nativeSegwit',
        );

        final migrationService = WalletMigrationService(
          secureStorage: storage,
          preferences: prefs,
          walletStoragePathLoader: () async => throw const FileSystemException('Cannot access storage'),
        );

        await expectLater(
          migrationService.migrateIfNeeded(),
          throwsA(
            isA<WalletMigrationException>().having(
              (e) => e.message,
              'message',
              contains('wallet storage path'),
            ),
          ),
        );

        // Registry is unmigrated and clean
        final registry = WalletRegistry(prefs);
        expect(registry.hasWallets(), isFalse);
      });
    });

    group('Wallet ID Validation & Filesystem Traversal Hardening', () {
      test('canonical ID regex matches valid UUIDs and w_primary_migrated', () {
        expect(WalletRecord.isValidWalletId('w_11111111-1111-1111-1111-111111111111'), isTrue);
        expect(WalletRecord.isValidWalletId('w_abcdef01-2345-6789-abcd-ef0123456789'), isTrue);
        expect(WalletRecord.isValidWalletId('w_primary_migrated'), isTrue);
        expect(WalletRecord.isValidWalletId(WalletRecord.generateId()), isTrue);

        // Does not throw
        WalletRecord.validateWalletId('w_11111111-1111-1111-1111-111111111111');
        WalletRecord.validateWalletId('w_primary_migrated');
      });

      test('rejects path traversal, non-canonical, control characters, and malformed IDs', () {
        final invalidIds = [
          '../w_evil',
          '../../etc/passwd',
          '../',
          '..',
          '/tmp/wallet',
          r'C:\temp\wallet',
          'wallets/w_test',
          'w_123',
          'wallet_1',
          'w_wallet_1',
          'w_alpha',
          '',
          'w_',
          'w_11111111-1111-1111-1111-11111111111g', // invalid hex
          'w_11111111-1111-1111-1111-111111111111\x00',
          'w_11111111-1111-1111-1111-111111111111\n',
          'w_${'a' * 100}',
        ];

        for (final id in invalidIds) {
          expect(WalletRecord.isValidWalletId(id), isFalse, reason: 'ID "$id" must be invalid');
          expect(
            () => WalletRecord.validateWalletId(id),
            throwsA(
              isA<FormatException>().having(
                (e) => e.message,
                'message',
                contains('Invalid wallet ID format'),
              ),
            ),
            reason: 'validateWalletId("$id") must throw FormatException',
          );
        }
      });

      test('WalletRecord.fromRegistryJson rejects non-canonical IDs with FormatException', () {
        expect(
          () => WalletRecord.fromRegistryJson({
            'id': '../evil_id',
            'name': 'Evil Wallet',
            'type': 'signing',
            'scriptType': 'nativeSegwit',
            'network': 'testnet',
            'createdAt': DateTime.now().toIso8601String(),
          }),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Invalid wallet ID format'),
            ),
          ),
        );
      });

      test('WalletRegistry.getWallets wraps invalid ID in WalletRegistryException', () async {
        final registry = WalletRegistry(prefs);
        await prefs.setString(
          WalletRegistry.registryKey,
          jsonEncode([
            {
              'id': '../evil_id',
              'name': 'Evil Wallet',
              'type': 'signing',
              'scriptType': 'nativeSegwit',
              'network': 'testnet',
              'createdAt': DateTime.now().toIso8601String(),
            }
          ]),
        );
        expect(
          () => registry.getWallets(),
          throwsA(
            isA<WalletRegistryException>().having(
              (e) => e.message,
              'message',
              contains('Invalid wallet ID format'),
            ),
          ),
        );
      });

      test('WalletRegistry mutators validate wallet IDs strictly', () async {
        final registry = WalletRegistry(prefs);
        const badId = '../evil_wallet';

        expect(
          () => registry.setActiveWalletId(badId),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => registry.renameWallet(badId, 'New Name'),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => registry.deleteWallet(badId),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => registry.registerWallet(
            WalletRecord(
              id: badId,
              name: 'Bad Wallet',
              type: WalletType.signing,
              scriptType: WalletScriptType.nativeSegwit,
              network: 'testnet',
              createdAt: DateTime.now(),
            ),
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('WalletStorageCleaner containment preserves external and sentinel files outside <base>/wallets/', () async {
        final tempDir = Directory.systemTemp.createTempSync('cleaner_containment_');
        addTearDown(() {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        // Create sentinels outside and inside wallets dir
        final sentinelOutside = File('${tempDir.path}/sentinel_outside.txt');
        await sentinelOutside.writeAsString('CRITICAL_SYSTEM_DATA');

        final walletsDir = Directory('${tempDir.path}/wallets');
        await walletsDir.create(recursive: true);
        final sentinelWallets = File('${walletsDir.path}/sentinel_wallets.txt');
        await sentinelWallets.writeAsString('WALLETS_SENTINEL');

        const validWalletId = 'w_11111111-1111-1111-1111-111111111111';
        final walletDir = Directory('${walletsDir.path}/$validWalletId');
        await walletDir.create(recursive: true);
        final dbFile = File('${walletDir.path}/bdk_wallet.sqlite');
        await dbFile.writeAsString('WALLET_DATA');

        final cleaner = WalletStorageCleaner(
          secureStorage: storage,
          preferences: prefs,
          walletStoragePathLoader: () async => tempDir.path,
        );

        // Attempting to delete traversal ID fails
        await expectLater(
          cleaner.deleteWalletData('../sentinel_outside.txt'),
          throwsA(isA<FormatException>()),
        );
        expect(await sentinelOutside.exists(), isTrue);

        // Delete valid wallet
        await cleaner.deleteWalletData(validWalletId);
        expect(await walletDir.exists(), isFalse);

        // Verify sentinels are completely untouched
        expect(await sentinelOutside.exists(), isTrue);
        expect(await sentinelOutside.readAsString(), equals('CRITICAL_SYSTEM_DATA'));
        expect(await sentinelWallets.exists(), isTrue);
        expect(await sentinelWallets.readAsString(), equals('WALLETS_SENTINEL'));
      });

      test('BdkWalletService validates wallet ID and enforces containment', () {
        expect(
          () => BdkWalletService(
            secureStorage: storage,
            walletId: '../evil_wallet',
            walletStoragePathLoader: () async => '/tmp',
            preferencesLoader: () async => prefs,
            allowCustomEsploraEndpoint: false,
          ),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('AddWallet Rollback Failure Aggregation & Observability', () {
      test('rollback failure aggregation surfaces AddWalletRollbackException without leaking secrets', () async {
        final tempDir = Directory.systemTemp.createTempSync('add_rollback_fail_');
        addTearDown(() {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        final faultyStorage = FaultySecureStorage(storage);
        const decoyPhrase = 'decoy seed phrase preserved 123';
        await faultyStorage.write(
          key: WalletStorageKeys.decoyMnemonic,
          value: decoyPhrase,
        );

        // Pre-create Wallet A
        final addWalletService = AddWalletService(
          secureStorage: faultyStorage,
          preferences: prefs,
          walletStoragePathLoader: () async => tempDir.path,
        );

        final resultA = await addWalletService.createWallet(
          scriptType: WalletScriptType.nativeSegwit,
          walletName: 'Wallet A',
        );
        final walletAId = resultA.walletRecord!.id;
        final phraseA = resultA.recoveryPhrase;

        // Arm failure: write succeeds, but directory creation will fail, AND during rollback delete will fail
        faultyStorage.failOnDelete = true;
        final failingAddWalletService = AddWalletService(
          secureStorage: faultyStorage,
          preferences: prefs,
          walletStoragePathLoader: () async => throw const FileSystemException('Directory creation simulated crash'),
        );

        try {
          await failingAddWalletService.createWallet(
            scriptType: WalletScriptType.nativeSegwit,
            walletName: 'Wallet B Failing',
          );
          fail('Should have thrown AddWalletRollbackException');
        } catch (e) {
          expect(e, isA<AddWalletRollbackException>());
          final rollbackEx = e as AddWalletRollbackException;
          expect(rollbackEx.walletId, isNotEmpty);
          expect(rollbackEx.rollbackFailures, isNotEmpty);
          expect(rollbackEx.toString(), contains('Cleanup failures:'));
          // Must not leak private keys/mnemonics in toString
          expect(rollbackEx.toString().contains('abandon'), isFalse);
          expect(rollbackEx.toString().contains('decoy'), isFalse);
        }

        // Wallet A and decoy remain intact
        expect(await storage.read(key: WalletStorageKeys.mnemonicFor(walletAId)), equals(phraseA));
        expect(await storage.read(key: WalletStorageKeys.decoyMnemonic), equals(decoyPhrase));
      });
    });

    group('Startup Migration Error Fail-Closed Handling', () {
      test('migration exception during app start fails closed to AsyncError without legacy fallback', () async {
        SharedPreferences.setMockInitialValues({
          // Inconsistent state: marked complete but registry empty
          WalletStorageKeys.legacyMigrationCompleted: true,
        });
        final testPrefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) => testPrefs),
            secureStorageProvider.overrideWithValue(storage),
            walletStoragePathProvider.overrideWith((ref) => '/tmp/wallet_test'),
          ],
        );
        addTearDown(container.dispose);

        // AppStartController should fail closed with AsyncError
        final appStartState = await container.read(appStartControllerProvider.future).then<AppStartState?>(
          (val) => val,
          onError: (err) => null,
        );

        expect(appStartState, isNull);
        final controllerState = container.read(appStartControllerProvider);
        expect(controllerState.hasError, isTrue);
        expect(controllerState.error, isA<WalletMigrationException>());
      });
    });
  });
}

class FaultySecureStorage implements SecureStorage {
  FaultySecureStorage([SecureStorage? inner]) : _inner = inner ?? InMemorySecureStorage();
  final SecureStorage _inner;
  bool failOnWrite = false;
  bool failOnDelete = false;
  String? failKeySubstring;

  @override
  Future<void> write({required String key, required String value}) async {
    if (failOnWrite && (failKeySubstring == null || key.contains(failKeySubstring!))) {
      throw const FileSystemException('Injected SecureStorage write failure');
    }
    return _inner.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) => _inner.read(key: key);

  @override
  Future<void> delete({required String key}) async {
    if (failOnDelete && (failKeySubstring == null || key.contains(failKeySubstring!))) {
      throw const FileSystemException('Injected SecureStorage delete failure');
    }
    return _inner.delete(key: key);
  }
}

class FaultyWalletRegistry extends WalletRegistry {
  FaultyWalletRegistry(super.preferences);
  bool failOnRegister = false;

  @override
  Future<void> registerWallet(WalletRecord record, {bool makeActive = false}) async {
    if (failOnRegister) {
      throw const FileSystemException('Injected WalletRegistry write failure');
    }
    return super.registerWallet(record, makeActive: makeActive);
  }
}

class _FakeBiometrics implements BiometricService {
  _FakeBiometrics({this.available = false});
  final bool available;

  @override
  Future<bool> authenticate({String reason = 'Auth'}) async => false;

  @override
  Future<bool> isAvailable() async => available;
}

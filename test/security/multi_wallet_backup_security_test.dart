import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/app_start_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/services/add_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_migration_service.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_storage_cleaner.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testMnemonicA =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  const testMnemonicB =
      'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';
  const testTpubC =
      'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';

  group('Multi-Wallet Backup Confirmation Isolation & Lifecycle (Items 1-23)', () {
    late InMemorySecureStorage storage;
    late SharedPreferences prefs;
    late Directory tempDir;
    late WalletRegistry registry;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = InMemorySecureStorage();
      tempDir = Directory.systemTemp.createTempSync('backup_isolation_test_');
      registry = WalletRegistry(prefs);
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    ProviderContainer createContainer({
      InMemorySecureStorage? customStorage,
      SharedPreferences? customPrefs,
      WalletRegistry? customRegistry,
    }) {
      final s = customStorage ?? storage;
      final p = customPrefs ?? prefs;
      final r = customRegistry ?? registry;

      return ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(s),
          sharedPreferencesProvider.overrideWith((ref) => p),
          walletStoragePathProvider.overrideWith((ref) => tempDir.path),
          walletRegistryProvider.overrideWith((ref) => r),
        ],
      );
    }

    test('Item 17: Multi-wallet backup isolation between Wallet A and Wallet B across restarts', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final addWalletService = AddWalletService(
        secureStorage: storage,
        preferences: prefs,
        registry: registry,
        walletStoragePathLoader: () async => tempDir.path,
      );

      // 1. Create Wallet A
      final resultA = await addWalletService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Wallet A',
      );
      final walletAId = resultA.walletRecord!.id;
      await container.read(activeWalletIdProvider.notifier).setActiveWallet(walletAId);

      // Initial state of Wallet A: backup_confirmed is false
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletAId)), isFalse);
      expect(await container.read(backupReminderProvider.future), isFalse);

      // 2. Complete backup for Wallet A
      await container.read(backupReminderProvider.notifier).confirmBackup(walletAId);
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletAId)), isTrue);
      expect(await container.read(backupReminderProvider.future), isTrue);

      // 3. Create Wallet B
      final resultB = await addWalletService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Wallet B',
      );
      final walletBId = resultB.walletRecord!.id;
      await container.read(activeWalletIdProvider.notifier).setActiveWallet(walletBId);

      // A remains true, B is initialized to false
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletAId)), isTrue);
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletBId)), isFalse);
      // Active wallet is B -> backup reminder reflects B (false)
      expect(await container.read(backupReminderProvider.future), isFalse);

      // 4. Restart application with B active
      final restartContainer = createContainer();
      addTearDown(restartContainer.dispose);

      expect(registry.getActiveWalletId(), equals(walletBId));
      final appStartState = await restartContainer.read(appStartControllerProvider.future);
      expect(appStartState.destination, equals(AppStartDestination.needsBackup));
      expect(appStartState.backupConfirmed, isFalse);

      // 5. Complete backup for Wallet B
      await restartContainer.read(backupReminderProvider.notifier).confirmBackup(walletBId);
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletBId)), isTrue);

      // Re-read app start after B backup
      restartContainer.invalidate(appStartControllerProvider);
      final postBackupState = await restartContainer.read(appStartControllerProvider.future);
      expect(postBackupState.destination, equals(AppStartDestination.mainShell));
      expect(postBackupState.backupConfirmed, isTrue);

      // 6. Switch A -> B -> A and verify independent states
      // Invalidate B's backup to test dynamic switching
      await restartContainer.read(backupReminderProvider.notifier).clearBackupConfirmation(walletBId);
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletAId)), isTrue);
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletBId)), isFalse);

      // Switch to A
      await restartContainer.read(activeWalletIdProvider.notifier).setActiveWallet(walletAId);
      expect(await restartContainer.read(backupReminderProvider.future), isTrue);

      // Switch to B
      await restartContainer.read(activeWalletIdProvider.notifier).setActiveWallet(walletBId);
      expect(await restartContainer.read(backupReminderProvider.future), isFalse);

      // Switch back to A
      await restartContainer.read(activeWalletIdProvider.notifier).setActiveWallet(walletAId);
      expect(await restartContainer.read(backupReminderProvider.future), isTrue);
    });

    test('Item 18: Restored wallet policy and watch-only wallet policy without cross-leakage', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final addWalletService = AddWalletService(
        secureStorage: storage,
        preferences: prefs,
        registry: registry,
        walletStoragePathLoader: () async => tempDir.path,
      );

      // 1. Wallet A: Generated signing wallet, backed up
      final resultA = await addWalletService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Wallet A',
      );
      final walletAId = resultA.walletRecord!.id;
      await container.read(activeWalletIdProvider.notifier).setActiveWallet(walletAId);
      await container.read(backupReminderProvider.notifier).confirmBackup(walletAId);
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletAId)), isTrue);

      // 2. Restore Wallet B from seed
      // Documented policy: restoreWallet sets backup_confirmed = true because seed was just provided
      final recordB = await addWalletService.restoreWallet(
        mnemonic: testMnemonicB,
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Restored Wallet B',
      );
      final walletBId = recordB.id;
      await container.read(activeWalletIdProvider.notifier).setActiveWallet(walletBId);

      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletBId)), isTrue);
      expect(await container.read(backupReminderProvider.future), isTrue);

      // 3. Import watch-only Wallet C
      final recordC = await addWalletService.importWatchOnlyWallet(
        externalDescriptor: testTpubC,
        walletName: 'Watch-Only C',
      );
      final walletCId = recordC.id;
      await container.read(activeWalletIdProvider.notifier).setActiveWallet(walletCId);

      // Watch-only policy: does not store seed backup confirmation flag
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletCId)), isNull);
      // And backup reminder is true (not required / never prompts seed backup)
      expect(await container.read(backupReminderProvider.future), isTrue);

      // AppStart routing with watch-only active goes directly to mainShell
      final restartContainer = createContainer();
      addTearDown(restartContainer.dispose);

      expect(registry.getActiveWalletId(), equals(walletCId));
      final appStartState = await restartContainer.read(appStartControllerProvider.future);
      expect(appStartState.destination, equals(AppStartDestination.mainShell));
      expect(appStartState.backupConfirmed, isTrue);

      // 4. Switch between A, B, C to confirm zero state contamination
      // Make A need backup
      await restartContainer.read(backupReminderProvider.notifier).clearBackupConfirmation(walletAId);
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletAId)), isFalse);
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletBId)), isTrue);
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletCId)), isNull);

      // Active A -> needs backup (false)
      await restartContainer.read(activeWalletIdProvider.notifier).setActiveWallet(walletAId);
      expect(await restartContainer.read(backupReminderProvider.future), isFalse);

      // Active B -> backed up (true)
      await restartContainer.read(activeWalletIdProvider.notifier).setActiveWallet(walletBId);
      expect(await restartContainer.read(backupReminderProvider.future), isTrue);

      // Active C -> watch-only (true)
      await restartContainer.read(activeWalletIdProvider.notifier).setActiveWallet(walletCId);
      expect(await restartContainer.read(backupReminderProvider.future), isTrue);
    });

    test('Item 19: Legacy global backup flag migrates to w_primary_migrated and does NOT leak to new wallets', () async {
      // 1. Setup legacy installation
      await prefs.setBool('settings.backup_confirmed', true);
      await storage.write(
        key: WalletStorageKeys.legacyMnemonic,
        value: testMnemonicA,
      );
      await storage.write(
        key: WalletStorageKeys.legacyScriptType,
        value: WalletScriptType.nativeSegwit.storageValue,
      );
      final dummyDb = File('${tempDir.path}/root_wallet_testnet.sqlite');
      await dummyDb.writeAsString('BDK_MOCK_LEGACY_SQLITE');

      // 2. Run migration
      final migrationService = WalletMigrationService(
        secureStorage: storage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );
      final migratedRecord = await migrationService.migrateIfNeeded();
      expect(migratedRecord, isNotNull);
      expect(migratedRecord!.id, equals(WalletMigrationService.defaultMigratedWalletId));

      // Verify scoped backup key is true for migrated wallet
      expect(
        prefs.getBool(WalletStorageKeys.backupConfirmedFor(migratedRecord.id)),
        isTrue,
      );

      // 3. Create brand-new Wallet B
      final addWalletService = AddWalletService(
        secureStorage: storage,
        preferences: prefs,
        registry: registry,
        walletStoragePathLoader: () async => tempDir.path,
      );
      final resultB = await addWalletService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Wallet B',
      );
      final walletBId = resultB.walletRecord!.id;

      // Crucial requirement: Wallet B must initialize to false and NOT inherit legacy global true!
      expect(
        prefs.getBool(WalletStorageKeys.backupConfirmedFor(walletBId)),
        isFalse,
      );
      expect(
        prefs.getBool(WalletStorageKeys.backupConfirmedFor(migratedRecord.id)),
        isTrue,
      );
    });

    test('Item 20: Unknown backup state fails safe to false for signing wallets', () async {
      // Register two signing wallets without any scoped backup keys in prefs
      const wallet1Id = 'w_11111111-1111-1111-1111-111111111111';
      const wallet2Id = 'w_22222222-2222-2222-2222-222222222222';

      final record1 = WalletRecord(
        id: wallet1Id,
        name: 'Wallet 1',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11111111',
        isActive: true,
      );
      final record2 = WalletRecord(
        id: wallet2Id,
        name: 'Wallet 2',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '22222222',
        isActive: false,
      );

      await registry.registerWallet(record1, makeActive: true);
      await registry.registerWallet(record2, makeActive: false);

      // Ensure no scoped backup key exists for either
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(wallet1Id)), isNull);
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(wallet2Id)), isNull);
      // Ensure no global backup key exists
      expect(prefs.getBool('settings.backup_confirmed'), isNull);

      final container = createContainer();
      addTearDown(container.dispose);

      // AppStartController must route to needsBackup
      final state = await container.read(appStartControllerProvider.future);
      expect(state.destination, equals(AppStartDestination.needsBackup));
      expect(state.backupConfirmed, isFalse);

      // BackupReminderController must require backup
      expect(await container.read(backupReminderProvider.future), isFalse);
    });

    test('Item 15: WalletStorageCleaner removes scoped backup_confirmed on wallet deletion', () async {
      final addWalletService = AddWalletService(
        secureStorage: storage,
        preferences: prefs,
        registry: registry,
        walletStoragePathLoader: () async => tempDir.path,
      );

      final resultA = await addWalletService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Wallet A',
      );
      final resultB = await addWalletService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Wallet B',
      );
      final idA = resultA.walletRecord!.id;
      final idB = resultB.walletRecord!.id;

      await prefs.setBool(WalletStorageKeys.backupConfirmedFor(idA), true);
      await prefs.setBool(WalletStorageKeys.backupConfirmedFor(idB), false);

      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(idA)), isTrue);
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(idB)), isFalse);

      // Delete Wallet A using cleaner
      final cleaner = WalletStorageCleaner(
        preferences: prefs,
        secureStorage: storage,
        walletStoragePathLoader: () async => tempDir.path,
      );
      await cleaner.deleteWalletData(idA);

      // Wallet A backup confirmation is purged
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(idA)), isNull);
      // Wallet B backup confirmation is completely untouched
      expect(prefs.getBool(WalletStorageKeys.backupConfirmedFor(idB)), isFalse);
    });

    test('Item 23: Rollback edge case unregisters partially registered FIRST wallet cleanly', () async {
      // Create a faulty preferences where writing the scoped backup key fails
      final faultyPrefs = _FaultyScopedPrefs(prefs);
      faultyPrefs.failOnScopedBackupKey = true;

      final addWalletService = AddWalletService(
        secureStorage: storage,
        preferences: faultyPrefs,
        registry: WalletRegistry(faultyPrefs),
        walletStoragePathLoader: () async => tempDir.path,
      );

      // Registry is initially completely empty
      expect(registry.getWallets(), isEmpty);

      // Attempt to create the very first wallet. Step 4 (registry registration) succeeds,
      // but Step 5 (scoped backup confirmation write) throws an exception.
      await expectLater(
        addWalletService.createWallet(
          scriptType: WalletScriptType.nativeSegwit,
          walletName: 'First Wallet (Should Rollback)',
        ),
        throwsA(
          isA<AddWalletException>().having(
            (e) => e.message,
            'message',
            contains('Failed to initialize scoped backup confirmation'),
          ),
        ),
      );

      // Verification of clean rollback for first wallet:
      // 1. Registry must be empty (the partially registered first wallet was unregistered)
      expect(registry.getWallets(), isEmpty);
      expect(registry.getActiveWalletId(), isNull);

      // 2. User-facing deleteWallet still prevents deleting the last remaining wallet
      final normalRecord = WalletRecord(
        id: 'w_99999999-9999-9999-9999-999999999999',
        name: 'Normal Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '99999999',
        isActive: true,
      );
      await registry.registerWallet(normalRecord, makeActive: true);
      expect(registry.getWallets().length, equals(1));
      expect(
        () => registry.deleteWallet(normalRecord.id),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Cannot delete the last remaining wallet'))),
      );
    });
  });
}

class _FaultyScopedPrefs implements SharedPreferences {
  _FaultyScopedPrefs(this._inner);
  final SharedPreferences _inner;
  bool failOnScopedBackupKey = false;

  @override
  Future<bool> commit() async => true;

  @override
  Future<bool> setBool(String key, bool value) {
    if (failOnScopedBackupKey && key.contains('backup_confirmed')) {
      return Future.value(false);
    }
    return _inner.setBool(key, value);
  }

  @override
  bool? getBool(String key) => _inner.getBool(key);

  @override
  Future<bool> clear() => _inner.clear();

  @override
  bool containsKey(String key) => _inner.containsKey(key);

  @override
  Object? get(String key) => _inner.get(key);

  @override
  double? getDouble(String key) => _inner.getDouble(key);

  @override
  int? getInt(String key) => _inner.getInt(key);

  @override
  Set<String> getKeys() => _inner.getKeys();

  @override
  String? getString(String key) => _inner.getString(key);

  @override
  List<String>? getStringList(String key) => _inner.getStringList(key);

  @override
  Future<void> reload() => _inner.reload();

  @override
  Future<bool> remove(String key) => _inner.remove(key);

  @override
  Future<bool> setDouble(String key, double value) => _inner.setDouble(key, value);

  @override
  Future<bool> setInt(String key, int value) => _inner.setInt(key, value);

  @override
  Future<bool> setString(String key, String value) => _inner.setString(key, value);

  @override
  Future<bool> setStringList(String key, List<String> value) => _inner.setStringList(key, value);
}

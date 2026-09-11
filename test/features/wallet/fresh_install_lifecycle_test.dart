import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/app_start_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/services/add_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_migration_service.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fresh Install Multi-Wallet Native Lifecycle Tests', () {
    late InMemorySecureStorage storage;
    late SharedPreferences prefs;
    late Directory tempDir;

    const validTpub =
        'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = InMemorySecureStorage();
      tempDir = Directory.systemTemp.createTempSync('fresh_install_lifecycle_');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    ProviderContainer createContainer({
      required SharedPreferences testPrefs,
      required InMemorySecureStorage testStorage,
    }) {
      return ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(testStorage),
          sharedPreferencesProvider.overrideWith((ref) => testPrefs),
          walletStoragePathProvider.overrideWith((ref) => tempDir.path),
        ],
      );
    }

    test('Fresh install create-wallet flow: starts empty, creates native multi-wallet, restarts without migration', () async {
      // 1. Initial Fresh Install State
      final migrationService = WalletMigrationService(
        secureStorage: storage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      // On fresh install, migrateIfNeeded returns null and does NOT write legacyMigrationCompleted
      final initialMigration = await migrationService.migrateIfNeeded();
      expect(initialMigration, isNull);
      expect(prefs.getBool(WalletStorageKeys.legacyMigrationCompleted), isNull);

      final initialRegistry = WalletRegistry(prefs);
      expect(initialRegistry.hasWallets(), isFalse);
      expect(initialRegistry.getActiveWalletId(), isNull);

      // AppStartController resolves to onboarding
      final container = createContainer(testPrefs: prefs, testStorage: storage);
      addTearDown(container.dispose);

      final appStartState = await container.read(appStartControllerProvider.future);
      expect(appStartState.destination, equals(AppStartDestination.onboarding));
      expect(appStartState.walletExists, isFalse);

      // 2. First-Run Onboarding Create Wallet via AddWalletService
      final addWalletService = AddWalletService(
        secureStorage: storage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      final creationResult = await addWalletService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Main Wallet',
      );

      final walletA = creationResult.walletRecord!;
      expect(WalletRecord.isValidWalletId(walletA.id), isTrue);
      expect(walletA.name, equals('Main Wallet'));
      expect(walletA.type, equals(WalletType.signing));
      expect(walletA.scriptType, equals(WalletScriptType.nativeSegwit));
      expect(walletA.fingerprint, isNotNull);
      expect(walletA.fingerprint!.length, equals(8));
      expect(creationResult.recoveryPhrase.split(' ').length, equals(12));

      // Check scoped storage writes: only scoped keys, NO legacy keys
      expect(await storage.read(key: WalletStorageKeys.mnemonicFor(walletA.id)), equals(creationResult.recoveryPhrase));
      expect(await storage.read(key: WalletStorageKeys.scriptTypeFor(walletA.id)), equals(WalletScriptType.nativeSegwit.storageValue));
      expect(await storage.read(key: WalletStorageKeys.capabilityFor(walletA.id)), equals(WalletCapability.signing.storageValue));
      expect(await storage.read(key: WalletStorageKeys.legacyMnemonic), isNull);
      expect(await storage.read(key: WalletStorageKeys.legacyScriptType), isNull);
      expect(await storage.read(key: WalletStorageKeys.legacyExternalDescriptor), isNull);
      expect(await storage.read(key: WalletStorageKeys.legacyInternalDescriptor), isNull);

      // Check isolated directory exists
      final dirA = Directory('${tempDir.path}/wallets/${walletA.id}');
      expect(await dirA.exists(), isTrue);

      // Activate in registry
      await initialRegistry.setActiveWalletId(walletA.id);
      expect(initialRegistry.getActiveWalletId(), equals(walletA.id));

      // User confirms seed backup
      await prefs.setBool('settings.backup_confirmed', true);

      // 3. App Restart Simulation
      // In a new session with persisted storage and prefs:
      final restartMigration = await migrationService.migrateIfNeeded();
      // Must return null immediately without running migration because registry has wallets
      expect(restartMigration, isNull);
      expect(prefs.getBool(WalletStorageKeys.legacyMigrationCompleted), isNull);

      final restartContainer = createContainer(testPrefs: prefs, testStorage: storage);
      addTearDown(restartContainer.dispose);

      final restartAppState = await restartContainer.read(appStartControllerProvider.future);
      expect(restartAppState.destination, equals(AppStartDestination.mainShell));
      expect(restartAppState.walletExists, isTrue);
      expect(restartAppState.backupConfirmed, isTrue);

      final activeId = await restartContainer.read(activeWalletIdProvider.future);
      expect(activeId, equals(walletA.id));
      await restartContainer.read(walletsListProvider.future);
      final activeRecord = restartContainer.read(activeWalletRecordProvider);
      expect(activeRecord?.id, equals(walletA.id));
      expect(activeRecord?.name, equals('Main Wallet'));

      // 4. Add Wallet B (Signing) and Wallet C (Watch-Only)
      final creationResultB = await addWalletService.createWallet(
        scriptType: WalletScriptType.taproot,
        walletName: 'Second Account',
      );
      final walletB = creationResultB.walletRecord!;
      expect(WalletRecord.isValidWalletId(walletB.id), isTrue);

      final recordC = await addWalletService.importWatchOnlyWallet(
        externalDescriptor: validTpub,
        walletName: 'Cold Vault',
      );
      expect(WalletRecord.isValidWalletId(recordC.id), isTrue);

      // Refresh list
      await restartContainer.read(walletsListProvider.notifier).refresh();
      final allWallets = await restartContainer.read(walletsListProvider.future);
      expect(allWallets.length, equals(3));

      // Switch to Wallet B
      await restartContainer.read(activeWalletIdProvider.notifier).setActiveWallet(walletB.id);
      expect(await restartContainer.read(activeWalletIdProvider.future), equals(walletB.id));
      expect(restartContainer.read(activeWalletRecordProvider)?.id, equals(walletB.id));
      expect(restartContainer.read(activeWalletRecordProvider)?.name, equals('Second Account'));

      // Switch to Wallet C (watch-only)
      await restartContainer.read(activeWalletIdProvider.notifier).setActiveWallet(recordC.id);
      expect(await restartContainer.read(activeWalletIdProvider.future), equals(recordC.id));
      expect(restartContainer.read(activeWalletRecordProvider)?.isWatchOnly, isTrue);
    });

    test('Fresh install restore-wallet flow: restores directly to multi-wallet native', () async {
      const phrase = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

      final addWalletService = AddWalletService(
        secureStorage: storage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      // Restore wallet
      final restored = await addWalletService.restoreWallet(
        mnemonic: phrase,
        scriptType: WalletScriptType.nativeSegwit,
        walletName: 'Restored Primary',
      );

      expect(WalletRecord.isValidWalletId(restored.id), isTrue);
      expect(restored.name, equals('Restored Primary'));
      expect(restored.type, equals(WalletType.signing));

      // Verify scoped storage keys
      expect(await storage.read(key: WalletStorageKeys.mnemonicFor(restored.id)), equals(phrase));
      expect(await storage.read(key: WalletStorageKeys.legacyMnemonic), isNull);

      // Verify isolated directory
      expect(await Directory('${tempDir.path}/wallets/${restored.id}').exists(), isTrue);

      // Verify registry
      final registry = WalletRegistry(prefs);
      expect(registry.getWallets().length, equals(1));
      expect(registry.getActiveWalletId(), equals(restored.id));

      // Confirm backup
      await prefs.setBool('settings.backup_confirmed', true);

      // Restart app
      final container = createContainer(testPrefs: prefs, testStorage: storage);
      addTearDown(container.dispose);

      final appState = await container.read(appStartControllerProvider.future);
      expect(appState.destination, equals(AppStartDestination.mainShell));
      expect(appState.walletExists, isTrue);
    });
  });
}

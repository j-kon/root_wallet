import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_migration_service.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletMigrationService Tests', () {
    late InMemorySecureStorage secureStorage;
    late SharedPreferences prefs;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      secureStorage = InMemorySecureStorage();
      tempDir = await Directory.systemTemp.createTemp('migration_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('fresh install without legacy wallet does not create any wallet', () async {
      final service = WalletMigrationService(
        secureStorage: secureStorage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      final migrated = await service.migrateIfNeeded();
      expect(migrated, isNull);

      final registry = WalletRegistry(prefs);
      expect(registry.hasWallets(), isFalse);
      expect(prefs.getBool(WalletStorageKeys.legacyMigrationCompleted), isNull);
    });

    test('migrates legacy signing wallet accurately and completely', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      await secureStorage.write(
        key: WalletStorageKeys.legacyMnemonic,
        value: mnemonic,
      );
      await secureStorage.write(
        key: WalletStorageKeys.legacyScriptType,
        value: WalletScriptType.nativeSegwit.storageValue,
      );
      await prefs.setString(
        'wallet.local_labels.v2.primary',
        '{"transactions":{"tx1":{"label":"Test Tx","note":""}},"addresses":{}}',
      );
      await prefs.setStringList('settings.locked_utxos', ['txid1:0']);

      // Create a dummy legacy sqlite database file
      final legacyDb = File('${tempDir.path}/root_wallet_testnet.sqlite');
      await legacyDb.writeAsString('BDK_MOCK_SQLITE_DATA');

      final service = WalletMigrationService(
        secureStorage: secureStorage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      final record = await service.migrateIfNeeded();
      expect(record, isNotNull);
      expect(record!.id, equals(WalletMigrationService.defaultMigratedWalletId));
      expect(record.name, equals('Main Wallet'));
      expect(record.type, equals(WalletType.signing));
      expect(record.scriptType, equals(WalletScriptType.nativeSegwit));
      expect(record.isActive, isTrue);

      // Verify scoped secrets in SecureStorage
      final scopedMnemonic = await secureStorage.read(
        key: WalletStorageKeys.mnemonicFor(record.id),
      );
      expect(scopedMnemonic, equals(mnemonic));
      final scopedScriptType = await secureStorage.read(
        key: WalletStorageKeys.scriptTypeFor(record.id),
      );
      expect(scopedScriptType, equals(WalletScriptType.nativeSegwit.storageValue));
      final scopedCapability = await secureStorage.read(
        key: WalletStorageKeys.capabilityFor(record.id),
      );
      expect(scopedCapability, equals(WalletCapability.signing.storageValue));

      // Verify BDK SQLite relocated to isolated directory
      final relocatedDb = File(
        '${tempDir.path}/wallets/${record.id}/bdk_wallet.sqlite',
      );
      expect(await relocatedDb.exists(), isTrue);
      expect(await relocatedDb.readAsString(), equals('BDK_MOCK_SQLITE_DATA'));

      // Verify BIP-329 labels migrated
      expect(
        prefs.getString('wallet.local_labels.v3.${record.id}'),
        contains('Test Tx'),
      );

      // Verify locked UTXOs migrated
      expect(
        prefs.getStringList('wallet.${record.id}.locked_utxos'),
        equals(['txid1:0']),
      );

      // Verify registry registration
      final registry = WalletRegistry(prefs);
      expect(registry.hasWallets(), isTrue);
      expect(registry.getActiveWalletId(), equals(record.id));
      expect(registry.getActiveWallet()?.id, equals(record.id));
    });

    test('migrates legacy watch-only wallet with descriptors', () async {
      const externalDesc =
          'wpkh([73c5da0a/84h/1h/0h]tpubDC5FSnEfJDFDZZwexYP1NBnvJWqSueauGL47D2JYdQWhvduYj7KZUg4jcM262nvqmkNiSfgBQY34CeK44oqRIJLayDzm2znnPu4Ta1hQbDY/0/*)#22clw720';
      const internalDesc =
          'wpkh([73c5da0a/84h/1h/0h]tpubDC5FSnEfJDFDZZwexYP1NBnvJWqSueauGL47D2JYdQWhvduYj7KZUg4jcM262nvqmkNiSfgBQY34CeK44oqRIJLayDzm2znnPu4Ta1hQbDY/1/*)#6e6s7yye';

      await secureStorage.write(
        key: WalletStorageKeys.legacyExternalDescriptor,
        value: externalDesc,
      );
      await secureStorage.write(
        key: WalletStorageKeys.legacyInternalDescriptor,
        value: internalDesc,
      );
      await secureStorage.write(
        key: WalletStorageKeys.legacyScriptType,
        value: WalletScriptType.nativeSegwit.storageValue,
      );

      final service = WalletMigrationService(
        secureStorage: secureStorage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      final record = await service.migrateIfNeeded();
      expect(record, isNotNull);
      expect(record!.type, equals(WalletType.watchOnly));
      expect(record.name, equals('Watch-Only Wallet'));
      expect(record.fingerprint, equals('73C5DA0A'));

      final scopedExt = await secureStorage.read(
        key: WalletStorageKeys.externalDescriptorFor(record.id),
      );
      expect(scopedExt, equals(externalDesc));

      final scopedMnemonic = await secureStorage.read(
        key: WalletStorageKeys.mnemonicFor(record.id),
      );
      expect(scopedMnemonic, isNull);
    });

    test('is strictly idempotent: subsequent runs return null and never duplicate', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      await secureStorage.write(
        key: WalletStorageKeys.legacyMnemonic,
        value: mnemonic,
      );

      final service = WalletMigrationService(
        secureStorage: secureStorage,
        preferences: prefs,
        walletStoragePathLoader: () async => tempDir.path,
      );

      final firstRun = await service.migrateIfNeeded();
      expect(firstRun, isNotNull);

      final registry = WalletRegistry(prefs);
      expect(registry.getWallets().length, equals(1));

      // Second run
      final secondRun = await service.migrateIfNeeded();
      expect(secondRun, isNull);
      expect(registry.getWallets().length, equals(1));
    });
  });
}

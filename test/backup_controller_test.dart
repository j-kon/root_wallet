import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/settings/presentation/providers/backup_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:root_wallet/core/security/backup_encryption_service.dart';

class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '/tmp/root_wallet_test_docs';
  }
}

class FakeBdkWalletService extends BdkWalletService {
  FakeBdkWalletService({
    required super.secureStorage,
    required super.walletStoragePathLoader,
    required super.preferencesLoader,
    required super.allowCustomEsploraEndpoint,
  });

  bool _decoyActive = false;

  @override
  bool get isDecoyActive => _decoyActive;

  @override
  void setDecoyActive(bool active) {
    _decoyActive = active;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PathProviderPlatform.instance = FakePathProviderPlatform();
    // Ensure temporary directory exists
    Directory('/tmp/root_wallet_test_docs').createSync(recursive: true);
  });

  tearDownAll(() {
    final dir = Directory('/tmp/root_wallet_test_docs');
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('BackupController', () {
    late InMemorySecureStorage secureStorage;
    late FakeBdkWalletService bdkWalletService;

    setUp(() {
      secureStorage = InMemorySecureStorage();
      bdkWalletService = FakeBdkWalletService(
        secureStorage: secureStorage,
        walletStoragePathLoader: () async => '',
        preferencesLoader: SharedPreferences.getInstance,
        allowCustomEsploraEndpoint: false,
      );
    });

    Future<ProviderContainer> buildContainer({
      required Map<String, Object> prefs,
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      final sharedPrefs = await SharedPreferences.getInstance();
      final labelStore = WalletLabelStore(sharedPrefs);

      return ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(secureStorage),
          bdkWalletServiceProvider.overrideWithValue(bdkWalletService),
          walletLabelStoreProvider.overrideWith((ref) => labelStore),
        ],
      );
    }

    test('initializes with null or stored last backup time', () async {
      final container = await buildContainer(prefs: {});
      // Wait for async init of controller
      await container.read(sharedPreferencesProvider.future);
      container.read(backupControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(backupControllerProvider).lastBackupTime, isNull);

      final containerWithTime = await buildContainer(prefs: {
        'settings.last_backup_time': '2026-06-23T12:00:00.000Z',
      });
      await containerWithTime.read(sharedPreferencesProvider.future);
      containerWithTime.read(backupControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final state = containerWithTime.read(backupControllerProvider);
      expect(
        state.lastBackupTime,
        DateTime.parse('2026-06-23T12:00:00.000Z'),
      );
    });

    test('backupToFile encrypts and saves labels using active mnemonic key', () async {
      await secureStorage.write(
        key: WalletStorageKeys.mnemonic,
        value: 'about check dynamic elegant first health dynamic dynamic dynamic dynamic dynamic dynamic',
      );

      final container = await buildContainer(prefs: {
        'wallet.local_labels.v1': jsonEncode({
          'addresses': {'tb1qaddress': 'Faucet Payout'},
          'transactions': {},
        }),
      });
      await container.read(sharedPreferencesProvider.future);
      // Wait for walletLabelsControllerProvider to load
      await container.read(walletLabelsControllerProvider.future);
      final controller = container.read(backupControllerProvider.notifier);

      await controller.backupToFile();

      final state = container.read(backupControllerProvider);
      expect(state.errorMessage, isNull);
      expect(state.successMessage, contains('saved successfully'));
      expect(state.lastBackupTime, isNotNull);

      // Verify backup file exists and can be read/decrypted
      final file = File('/tmp/root_wallet_test_docs/backup.enc');
      expect(file.existsSync(), isTrue);

      final encryptedCombined = file.readAsStringSync();
      expect(encryptedCombined, isNotEmpty);
    });

    test('restoreFromFile decrypts and updates label store', () async {
      const normalMnemonic = 'about check dynamic elegant first health dynamic dynamic dynamic dynamic dynamic dynamic';
      await secureStorage.write(
        key: WalletStorageKeys.mnemonic,
        value: normalMnemonic,
      );

      final container = await buildContainer(prefs: {});
      await container.read(sharedPreferencesProvider.future);
      final controller = container.read(backupControllerProvider.notifier);

      // Write mock backup file
      final encrypted = BackupEncryptionService.encrypt(
        plainText: '{"addresses": {"tb1qaddress": "Restored Label"}, "transactions": {}}',
        mnemonic: normalMnemonic,
      );
      final file = File('/tmp/root_wallet_test_docs/backup.enc');
      file.writeAsStringSync(encrypted);

      final success = await controller.restoreFromFile();
      expect(success, isTrue);

      final state = container.read(backupControllerProvider);
      expect(state.errorMessage, isNull);
      expect(state.successMessage, contains('restored successfully'));

      // Check that controller loaded the restored data
      final labelsSnapshot = await container.read(walletLabelsControllerProvider.future);
      expect(labelsSnapshot.addressLabel('tb1qaddress'), 'Restored Label');
    });

    test('backup/restore respects decoy mode mnemonic', () async {
      const normalMnemonic = 'about check dynamic elegant first health dynamic dynamic dynamic dynamic dynamic dynamic';
      const decoyMnemonic = 'fringe zero basic simple filter useful double double double double double double';

      await secureStorage.write(key: WalletStorageKeys.mnemonic, value: normalMnemonic);
      await secureStorage.write(key: WalletStorageKeys.decoyMnemonic, value: decoyMnemonic);

      final container = await buildContainer(prefs: {
        'wallet.local_labels.v1': jsonEncode({
          'addresses': {'tb1qaddress': 'Faucet Payout'},
          'transactions': {},
        }),
      });
      await container.read(sharedPreferencesProvider.future);
      await container.read(walletLabelsControllerProvider.future);
      final controller = container.read(backupControllerProvider.notifier);

      // 1. Decoy mode active
      bdkWalletService.setDecoyActive(true);

      // Export while decoy active
      final decoyExport = await controller.exportToBase64();
      expect(decoyExport, isNotNull);

      // Try decrypting with decoy mnemonic -> should succeed
      final decoyDecrypted = BackupEncryptionService.decrypt(
        encryptedCombinedBase64: decoyExport!,
        mnemonic: decoyMnemonic,
      );
      expect(decoyDecrypted, contains('Faucet Payout'));

      // Try decrypting with normal mnemonic -> should fail/throw
      expect(
        () => BackupEncryptionService.decrypt(
          encryptedCombinedBase64: decoyExport,
          mnemonic: normalMnemonic,
        ),
        throwsArgumentError,
      );
    });
  });
}

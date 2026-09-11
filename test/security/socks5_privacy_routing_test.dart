import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/core/network/network_storage_keys.dart';
import 'package:root_wallet/core/network/network_transport_config.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/settings/presentation/providers/network_transport_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_seed_service.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SOCKS5 & Privacy Routing Security Tests', () {
    late Directory tempDir;
    late InMemorySecureStorage secureStorage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('socks5_test_');
      secureStorage = InMemorySecureStorage();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Config Validation & Secret Redaction', () {
      test('validates standard localhost and IP endpoints', () {
        final config1 = Socks5ProxyConfig(host: '127.0.0.1', port: 9050);
        expect(config1.host, '127.0.0.1');
        expect(config1.port, 9050);
        expect(config1.address, '127.0.0.1:9050');
        expect(config1.isOnion, isFalse);

        final config2 = Socks5ProxyConfig(host: 'localhost', port: 1080);
        expect(config2.host, 'localhost');
        expect(config2.port, 1080);
      });

      test('normalizes schemes and accidental path inputs', () {
        final config = Socks5ProxyConfig(
          host: 'socks5://proxy.example.com:9050/',
          port: 9050,
        );
        expect(config.host, 'proxy.example.com');
        expect(config.port, 9050);
      });

      test('accepts Tor v3 .onion addresses without local DNS', () {
        const onionHost =
            'vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd.onion';
        final config = Socks5ProxyConfig(host: onionHost, port: 9050);
        expect(config.host, onionHost);
        expect(config.isOnion, isTrue);
      });

      test('rejects invalid hosts (empty, whitespace, illegal chars, too long)', () {
        expect(() => Socks5ProxyConfig(host: '', port: 9050), throwsFormatException);
        expect(
          () => Socks5ProxyConfig(host: '   ', port: 9050),
          throwsFormatException,
        );
        expect(
          () => Socks5ProxyConfig(host: 'host with spaces', port: 9050),
          throwsFormatException,
        );
        expect(
          () => Socks5ProxyConfig(host: 'a' * 256, port: 9050),
          throwsFormatException,
        );
        expect(
          () => Socks5ProxyConfig(host: 'bad_host*!', port: 9050),
          throwsFormatException,
        );
      });

      test('rejects invalid ports (0, negative, >65535)', () {
        expect(() => Socks5ProxyConfig(host: '127.0.0.1', port: 0), throwsFormatException);
        expect(() => Socks5ProxyConfig(host: '127.0.0.1', port: -1), throwsFormatException);
        expect(
          () => Socks5ProxyConfig(host: '127.0.0.1', port: 65536),
          throwsFormatException,
        );
        // Valid edge boundaries
        expect(Socks5ProxyConfig(host: '127.0.0.1', port: 1).port, 1);
        expect(Socks5ProxyConfig(host: '127.0.0.1', port: 65535).port, 65535);
      });

      test('redacts proxy credentials from toString() and display strings', () {
        final config = Socks5ProxyConfig(
          host: '127.0.0.1',
          port: 9050,
          username: 'tor_user',
          password: 'super_secret_password',
        );

        final stringified = config.toString();
        expect(stringified, isNot(contains('super_secret_password')));
        expect(stringified, contains('hasPassword: true'));
        expect(config.displayAddress, '127.0.0.1:9050');
      });
    });

    group('Credential Storage Isolation', () {
      test('proxy password stored in SecureStorage, NEVER in SharedPreferences', () async {
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            secureStorageProvider.overrideWithValue(secureStorage),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(networkTransportProvider.notifier);
        final config = Socks5ProxyConfig(
          host: '10.0.0.1',
          port: 9050,
          username: 'user1',
          password: 'secret_proxy_password',
        );

        await controller.saveProxyConfig(config, activate: true);

        // Host and port in SharedPreferences
        expect(prefs.getString(NetworkStorageKeys.proxyHost), '10.0.0.1');
        expect(prefs.getInt(NetworkStorageKeys.proxyPort), 9050);
        expect(prefs.getString(NetworkStorageKeys.proxyUsername), 'user1');
        expect(prefs.getString(NetworkStorageKeys.transportMode), 'socks5');

        // Password MUST NOT be in SharedPreferences
        expect(prefs.containsKey('secure.settings.network.proxy_password'), isFalse);
        expect(prefs.containsKey('proxy_password'), isFalse);
        for (final key in prefs.getKeys()) {
          final val = prefs.get(key).toString();
          expect(val, isNot(contains('secret_proxy_password')));
        }

        // Password MUST be stored in SecureStorage
        final storedPassword = await secureStorage.read(
          key: NetworkStorageKeys.proxyPassword,
        );
        expect(storedPassword, equals('secret_proxy_password'));
      });
    });

    group('Fail-Closed Privacy Guarantees', () {
      test(
        'syncWallet fails closed when SOCKS5 proxy is unavailable (no direct fallback)',
        () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
          await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
          await prefs.setInt(NetworkStorageKeys.proxyPort, 19999); // Dead port

          final seedService = WalletSeedService(
            secureStorage: secureStorage,
            walletStoragePathLoader: () async => tempDir.path,
          );
          await seedService.createWallet();

          final bdkService = BdkWalletService(
            secureStorage: secureStorage,
            walletStoragePathLoader: () async => tempDir.path,
            preferencesLoader: () async => prefs,
            allowCustomEsploraEndpoint: false,
          );

          expect(
            () => bdkService.syncWallet(),
            throwsA(
              isA<BdkWalletServiceException>().having(
                (e) => e.toString(),
                'toString',
                allOf(
                  contains('SOCKS5 proxy is unavailable for wallet sync'),
                  contains('Clearnet fallback is disabled'),
                ),
              ),
            ),
          );
        },
      );

      test(
        'getWalletOverview fails closed when SOCKS5 proxy is unavailable (no direct fallback in isolate)',
        () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
          await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
          await prefs.setInt(NetworkStorageKeys.proxyPort, 19999); // Dead port

          final seedService = WalletSeedService(
            secureStorage: secureStorage,
            walletStoragePathLoader: () async => tempDir.path,
          );
          await seedService.createWallet();

          final bdkService = BdkWalletService(
            secureStorage: secureStorage,
            walletStoragePathLoader: () async => tempDir.path,
            preferencesLoader: () async => prefs,
            allowCustomEsploraEndpoint: false,
          );

          final overview = await bdkService.loadWalletOverviewInBackground();
          expect(overview.syncSucceeded, isFalse);
          expect(overview.syncError, isNotNull);
          expect(overview.syncError, contains('SOCKS5 proxy is unavailable'));
          expect(
            overview.syncError,
            contains('Root Wallet will not fall back to a direct connection'),
          );
        },
      );

      test(
        'fee estimation fails closed when SOCKS5 proxy is unavailable (no direct fallback)',
        () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
          await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
          await prefs.setInt(NetworkStorageKeys.proxyPort, 19999); // Dead port

          final bdkService = BdkWalletService(
            secureStorage: secureStorage,
            walletStoragePathLoader: () async => tempDir.path,
            preferencesLoader: () async => prefs,
            allowCustomEsploraEndpoint: false,
          );

          expect(
            () => bdkService.estimateFeeSatPerVbyte(),
            throwsA(
              isA<BdkWalletServiceException>().having(
                (e) => e.toString(),
                'toString',
                allOf(
                  contains('SOCKS5 proxy is unavailable for fee estimation'),
                  contains('Clearnet fallback is disabled'),
                ),
              ),
            ),
          );
        },
      );

      test(
        'chain height fails closed when SOCKS5 proxy is unavailable (no direct fallback to Esplora)',
        () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
          await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
          await prefs.setInt(NetworkStorageKeys.proxyPort, 19999); // Dead port

          final bdkService = BdkWalletService(
            secureStorage: secureStorage,
            walletStoragePathLoader: () async => tempDir.path,
            preferencesLoader: () async => prefs,
            allowCustomEsploraEndpoint: false,
          );

          expect(
            () => bdkService.chainHeight(),
            throwsA(
              isA<BdkWalletServiceException>().having(
                (e) => e.toString(),
                'toString',
                allOf(
                  contains('SOCKS5 proxy is unavailable to read chain height'),
                  contains('Clearnet fallback is disabled'),
                ),
              ),
            ),
          );
        },
      );
    });

    group('First Connection On Restart & Persistence', () {
      test('persisted SOCKS5 mode is loaded before constructing network backend', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
        await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
        await prefs.setInt(NetworkStorageKeys.proxyPort, 9050);

        // Simulate app cold start: fresh BdkWalletService without in-memory state
        final bdkService = BdkWalletService(
          secureStorage: secureStorage,
          walletStoragePathLoader: () async => tempDir.path,
          preferencesLoader: () async => prefs,
          allowCustomEsploraEndpoint: false,
        );

        final diagnostics = await bdkService.diagnostics();
        expect(diagnostics.transportMode, equals('socks5'));
        expect(diagnostics.proxyAddress, equals('127.0.0.1:9050'));
        expect(diagnostics.backendType, equals('Electrum (via SOCKS5)'));
      });
    });

    group('Provider Invalidation & Transport Switching', () {
      test('switching transport mode invalidates BdkWalletService cleanly', () async {
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            secureStorageProvider.overrideWithValue(secureStorage),
            walletStoragePathProvider.overrideWith((ref) => tempDir.path),
          ],
        );
        addTearDown(container.dispose);
        await container.read(networkTransportProvider.future);

        // 1. Initially direct
        final initialService = container.read(bdkWalletServiceProvider);
        final initialDiag = await initialService.diagnostics();
        expect(initialDiag.transportMode, equals('direct'));

        // 2. Switch to SOCKS5
        final controller = container.read(networkTransportProvider.notifier);
        await controller.saveProxyConfig(
          Socks5ProxyConfig(host: '127.0.0.1', port: 9050),
          activate: true,
        );

        // 3. Provider invalidation yields new BdkWalletService instance
        final updatedService = container.read(bdkWalletServiceProvider);
        expect(identical(initialService, updatedService), isFalse);

        final updatedDiag = await updatedService.diagnostics();
        expect(updatedDiag.transportMode, equals('socks5'));
        expect(updatedDiag.proxyAddress, equals('127.0.0.1:9050'));

        // 4. Switch back to direct
        await controller.revertToDirect();
        final directService = container.read(bdkWalletServiceProvider);
        expect(identical(updatedService, directService), isFalse);

        final directDiag = await directService.diagnostics();
        expect(directDiag.transportMode, equals('direct'));
      });
    });

    group('Multi-Wallet Transport Isolation & Decoy Compliance', () {
      test('switching active wallets maintains global SOCKS5 policy', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
        await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
        await prefs.setInt(NetworkStorageKeys.proxyPort, 9050);

        final registry = WalletRegistry(prefs);
        final walletA = WalletRecord(
          id: 'w_11111111-1111-1111-1111-111111111111',
          name: 'Wallet A',
          network: 'testnet',
          fingerprint: '11111111',
          createdAt: DateTime.now(),
          scriptType: WalletScriptType.nativeSegwit,
          type: WalletType.signing,
        );
        final walletB = WalletRecord(
          id: 'w_22222222-2222-2222-2222-222222222222',
          name: 'Wallet B',
          network: 'testnet',
          fingerprint: '22222222',
          createdAt: DateTime.now(),
          scriptType: WalletScriptType.nativeSegwit,
          type: WalletType.signing,
        );
        await registry.registerWallet(walletA);
        await registry.registerWallet(walletB);
        await registry.setActiveWalletId(walletA.id);

        await secureStorage.write(
          key: WalletStorageKeys.scriptTypeFor(walletA.id),
          value: WalletScriptType.nativeSegwit.storageValue,
        );
        await secureStorage.write(
          key: WalletStorageKeys.scriptTypeFor(walletB.id),
          value: WalletScriptType.nativeSegwit.storageValue,
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            secureStorageProvider.overrideWithValue(secureStorage),
            walletStoragePathProvider.overrideWith((ref) => tempDir.path),
          ],
        );
        addTearDown(container.dispose);
        await container.read(networkTransportProvider.future);

        // Wallet A
        final diagA = await container.read(bdkWalletServiceProvider).diagnostics();
        expect(diagA.transportMode, equals('socks5'));

        // Switch to Wallet B
        final reg = await container.read(walletRegistryProvider.future);
        await reg.setActiveWalletId(walletB.id);
        container.invalidate(activeWalletIdProvider);

        final diagB = await container.read(bdkWalletServiceProvider).diagnostics();
        expect(diagB.transportMode, equals('socks5'));
        expect(diagB.proxyAddress, equals('127.0.0.1:9050'));
      });

      test('decoy wallet activation respects global SOCKS5 routing policy', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
        await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
        await prefs.setInt(NetworkStorageKeys.proxyPort, 9050);

        final bdkService = BdkWalletService(
          secureStorage: secureStorage,
          walletStoragePathLoader: () async => tempDir.path,
          preferencesLoader: () async => prefs,
          allowCustomEsploraEndpoint: false,
        );

        bdkService.setDecoyActive(true);
        expect(bdkService.isDecoyActive, isTrue);

        final diagnostics = await bdkService.diagnostics();
        expect(diagnostics.transportMode, equals('socks5'));
        expect(diagnostics.proxyAddress, equals('127.0.0.1:9050'));
      });
    });
  });
}

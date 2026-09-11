import 'dart:io';
import 'dart:typed_data';
import 'package:bdk_dart/bdk.dart' as bdk;
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

/// Test client tracking helper that counts and records all network backend client instantiations.
class MockClientTracker {
  int socksElectrumAttempts = 0;
  int directElectrumAttempts = 0;
  int esploraAttempts = 0;
  final List<String> attemptedElectrumUrls = [];
  final List<String?> attemptedSocksProxies = [];
  final List<bool?> attemptedValidateDomains = [];

  ElectrumClientFactory createElectrumFactory({
    bool shouldFail = false,
    String? failMessage,
  }) {
    return ({
      required String url,
      String? socks5,
      int timeout = 10,
      int retry = 2,
      bool? validateDomain,
    }) {
      if (socks5 != null && socks5.isNotEmpty) {
        socksElectrumAttempts++;
      } else {
        directElectrumAttempts++;
      }
      attemptedElectrumUrls.add(url);
      attemptedSocksProxies.add(socks5);
      attemptedValidateDomains.add(validateDomain);

      if (shouldFail) {
        throw SocketException(
          failMessage ?? 'Proxy connection failed: Connection refused',
        );
      }
      return defaultElectrumClientFactory(
        url: url,
        socks5: socks5,
        timeout: timeout,
        retry: retry,
        validateDomain: validateDomain,
      );
    };
  }

  EsploraClientFactory createEsploraFactory({
    bool shouldFail = false,
  }) {
    return (String url, {String? proxy}) {
      esploraAttempts++;
      if (shouldFail) {
        throw const SocketException('Esplora unreachable');
      }
      return defaultEsploraClientFactory(url, proxy: proxy);
    };
  }
}

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

    group('Config Validation & IPv6 Normalization', () {
      test('validates standard localhost and IP endpoints', () {
        final config1 = Socks5ProxyConfig(host: '127.0.0.1', port: 9050);
        expect(config1.host, '127.0.0.1');
        expect(config1.port, 9050);
        expect(config1.address, '127.0.0.1:9050');
        expect(config1.displayAddress, '127.0.0.1:9050');
        expect(config1.isIpv6, isFalse);

        final config2 = Socks5ProxyConfig(host: 'localhost', port: 1080);
        expect(config2.host, 'localhost');
        expect(config2.port, 1080);
        expect(config2.address, 'localhost:1080');
      });

      test('normalizes schemes and accidental path inputs', () {
        final config = Socks5ProxyConfig(
          host: 'socks5://proxy.example.com:9050/',
          port: 9050,
        );
        expect(config.host, 'proxy.example.com');
        expect(config.port, 9050);
        expect(config.address, 'proxy.example.com:9050');
      });

      test('supports and normalizes IPv6 proxy hosts to exact BDK format', () {
        // Unbracketed loopback ::1
        final configIpv6Loopback = Socks5ProxyConfig(host: '::1', port: 9050);
        expect(configIpv6Loopback.host, '::1');
        expect(configIpv6Loopback.isIpv6, isTrue);
        expect(configIpv6Loopback.address, '[::1]:9050');

        // Bracketed loopback [::1]
        final configBracketed = Socks5ProxyConfig(host: '[::1]', port: 9050);
        expect(configBracketed.host, '::1');
        expect(configBracketed.isIpv6, isTrue);
        expect(configBracketed.address, '[::1]:9050');

        // Bracketed loopback with port [::1]:9050
        final configBracketedWithPort = Socks5ProxyConfig(
          host: '[::1]:9050',
          port: 9050,
        );
        expect(configBracketedWithPort.host, '::1');
        expect(configBracketedWithPort.address, '[::1]:9050');

        // Global unicast IPv6 address
        final configGlobal = Socks5ProxyConfig(
          host: '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
          port: 1080,
        );
        expect(configGlobal.isIpv6, isTrue);
        expect(
          configGlobal.address,
          '[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:1080',
        );
      });

      test('rejects .onion in proxy host (onion belongs in Electrum target)', () {
        const onionHost =
            'vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd.onion';
        expect(
          () => Socks5ProxyConfig(host: onionHost, port: 9050),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Proxy host cannot be a .onion address'),
            ),
          ),
        );
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

      test('contains no credential fields and toString is clean', () {
        final config = Socks5ProxyConfig(host: '127.0.0.1', port: 9050);
        expect(config.toString(), 'Socks5ProxyConfig(host: 127.0.0.1, port: 9050)');
      });
    });

    group('Tor v3 Onion & Custom Electrum Validation', () {
      test('validates Tor v3 56-char onion targets correctly', () {
        const validV3 =
            'vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd.onion';
        expect(Socks5ProxyConfig.isValidTorV3Onion(validV3), isTrue);

        // Tor v2 (16 chars) is deprecated and must be rejected
        const deprecatedV2 = 'expyuzz4wqqfdgah.onion';
        expect(Socks5ProxyConfig.isValidTorV3Onion(deprecatedV2), isFalse);

        // Arbitrary short onion is rejected
        expect(Socks5ProxyConfig.isValidTorV3Onion('abc.onion'), isFalse);
      });

      test('validates Electrum target endpoint schemes and ports', () {
        // Valid TCP and SSL endpoints
        expect(
          () => Socks5ProxyConfig.validateElectrumEndpoint('tcp://127.0.0.1:50001'),
          returnsNormally,
        );
        expect(
          () => Socks5ProxyConfig.validateElectrumEndpoint('ssl://electrum.example.com:50002'),
          returnsNormally,
        );
        expect(
          () => Socks5ProxyConfig.validateElectrumEndpoint(
            'tcp://vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd.onion:50001',
          ),
          returnsNormally,
        );

        // Reject invalid onion targets
        expect(
          () => Socks5ProxyConfig.validateElectrumEndpoint('tcp://abc.onion:50001'),
          throwsFormatException,
        );

        // Reject missing port or invalid scheme
        expect(
          () => Socks5ProxyConfig.validateElectrumEndpoint('http://electrum.example.com:50001'),
          throwsFormatException,
        );
        expect(
          () => Socks5ProxyConfig.validateElectrumEndpoint('tcp://electrum.example.com'),
          throwsFormatException,
        );
      });
    });

    group('Transport Mode Strict Fail-Closed Parsing', () {
      test('parsePersisted treats null as direct on genuine fresh install', () {
        expect(NetworkTransportMode.parsePersisted(null), NetworkTransportMode.direct);
      });

      test('parsePersisted accepts explicit direct and socks5', () {
        expect(NetworkTransportMode.parsePersisted('direct'), NetworkTransportMode.direct);
        expect(NetworkTransportMode.parsePersisted('socks5'), NetworkTransportMode.socks5);
      });

      test('parsePersisted throws NetworkConfigurationException for invalid values', () {
        const invalidModes = ['socks', 'sock5', 'tor', '', 'unknown', 'DIRECT', 'SOCKS5'];
        for (final invalid in invalidModes) {
          expect(
            () => NetworkTransportMode.parsePersisted(invalid),
            throwsA(isA<NetworkConfigurationException>()),
            reason: 'Persisted mode "$invalid" must fail closed with NetworkConfigurationException',
          );
        }
      });

      test('persisted corrupted mode in storage fails closed before any client is created', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(NetworkStorageKeys.transportMode, 'sock5'); // Corrupt mode

        final tracker = MockClientTracker();
        final bdkService = BdkWalletService(
          secureStorage: secureStorage,
          walletStoragePathLoader: () async => tempDir.path,
          preferencesLoader: () async => prefs,
          allowCustomEsploraEndpoint: false,
          electrumClientFactory: tracker.createElectrumFactory(),
          esploraClientFactory: tracker.createEsploraFactory(),
        );

        await expectLater(
          bdkService.syncWallet(),
          throwsA(
            isA<BdkWalletServiceException>().having(
              (e) => e.cause,
              'cause',
              isA<NetworkConfigurationException>(),
            ),
          ),
        );

        await expectLater(
          bdkService.chainHeight(),
          throwsA(
            isA<BdkWalletServiceException>().having(
              (e) => e.cause,
              'cause',
              isA<NetworkConfigurationException>(),
            ),
          ),
        );

        // ZERO clients of ANY kind created
        expect(tracker.socksElectrumAttempts, equals(0));
        expect(tracker.directElectrumAttempts, equals(0));
        expect(tracker.esploraAttempts, equals(0));
      });
    });

    group('No-Direct-Fallback Fail-Closed Guarantees (Injectable Factory)', () {
      test(
        'syncWallet fails closed with zero direct and zero Esplora clients on proxy failure',
        () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
          await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
          await prefs.setInt(NetworkStorageKeys.proxyPort, 9050);

          final seedService = WalletSeedService(
            secureStorage: secureStorage,
            walletStoragePathLoader: () async => tempDir.path,
          );
          await seedService.createWallet();

          final tracker = MockClientTracker();
          final bdkService = BdkWalletService(
            secureStorage: secureStorage,
            walletStoragePathLoader: () async => tempDir.path,
            preferencesLoader: () async => prefs,
            allowCustomEsploraEndpoint: false,
            electrumClientFactory: tracker.createElectrumFactory(shouldFail: true),
            esploraClientFactory: tracker.createEsploraFactory(),
          );

          await expectLater(
            bdkService.syncWallet(),
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

          expect(tracker.socksElectrumAttempts, greaterThan(0));
          expect(tracker.directElectrumAttempts, equals(0));
          expect(tracker.esploraAttempts, equals(0));
        },
      );

      test(
        'chainHeight fails closed with zero direct and zero Esplora clients on proxy failure',
        () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
          await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
          await prefs.setInt(NetworkStorageKeys.proxyPort, 9050);

          final tracker = MockClientTracker();
          final bdkService = BdkWalletService(
            secureStorage: secureStorage,
            walletStoragePathLoader: () async => tempDir.path,
            preferencesLoader: () async => prefs,
            allowCustomEsploraEndpoint: false,
            electrumClientFactory: tracker.createElectrumFactory(shouldFail: true),
            esploraClientFactory: tracker.createEsploraFactory(),
          );

          await expectLater(
            bdkService.chainHeight(),
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

          expect(tracker.socksElectrumAttempts, greaterThan(0));
          expect(tracker.directElectrumAttempts, equals(0));
          expect(tracker.esploraAttempts, equals(0));
        },
      );

      test(
        'fee estimation fails closed with zero direct and zero Esplora clients on proxy failure',
        () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
          await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
          await prefs.setInt(NetworkStorageKeys.proxyPort, 9050);

          final tracker = MockClientTracker();
          final bdkService = BdkWalletService(
            secureStorage: secureStorage,
            walletStoragePathLoader: () async => tempDir.path,
            preferencesLoader: () async => prefs,
            allowCustomEsploraEndpoint: false,
            electrumClientFactory: tracker.createElectrumFactory(shouldFail: true),
            esploraClientFactory: tracker.createEsploraFactory(),
          );

          await expectLater(
            bdkService.estimateFeeSatPerVbyte(),
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

          expect(tracker.socksElectrumAttempts, greaterThan(0));
          expect(tracker.directElectrumAttempts, equals(0));
          expect(tracker.esploraAttempts, equals(0));
        },
      );

      test(
        'broadcastTransaction fails closed with zero direct and zero Esplora clients on proxy failure',
        () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
          await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
          await prefs.setInt(NetworkStorageKeys.proxyPort, 9050);

          final tracker = MockClientTracker();
          final bdkService = BdkWalletService(
            secureStorage: secureStorage,
            walletStoragePathLoader: () async => tempDir.path,
            preferencesLoader: () async => prefs,
            allowCustomEsploraEndpoint: false,
            electrumClientFactory: tracker.createElectrumFactory(shouldFail: true),
            esploraClientFactory: tracker.createEsploraFactory(),
          );

          const rawTxHex =
              '02000000010000000000000000000000000000000000000000000000000000000000000000ffffffff00ffffffff010000000000000000010000000000';
          final rawTxBytes = List<int>.generate(
            rawTxHex.length ~/ 2,
            (i) => int.parse(rawTxHex.substring(i * 2, i * 2 + 2), radix: 16),
          );
          final dummyTx = bdk.Transaction(
            transactionBytes: Uint8List.fromList(rawTxBytes),
          );

          await expectLater(
            bdkService.broadcastTransaction(dummyTx),
            throwsA(
              isA<BdkWalletServiceException>().having(
                (e) => e.toString(),
                'toString',
                allOf(
                  contains('SOCKS5 proxy is unavailable for transaction broadcast'),
                  contains('Clearnet fallback is disabled'),
                ),
              ),
            ),
          );

          expect(tracker.socksElectrumAttempts, greaterThan(0));
          expect(tracker.directElectrumAttempts, equals(0));
          expect(tracker.esploraAttempts, equals(0));
        },
      );

      test(
        'loadWalletOverviewInBackground fails closed in isolate without direct fallback',
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
    });

    group('Custom Electrum Isolation (No Public Fallback)', () {
      test('custom Electrum failure in SOCKS5 does NOT query public Electrum fallbacks', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
        await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
        await prefs.setInt(NetworkStorageKeys.proxyPort, 9050);
        const customUrl = 'tcp://private-node.example.org:50001';
        await prefs.setString(NetworkStorageKeys.customElectrumUrl, customUrl);

        final tracker = MockClientTracker();
        final bdkService = BdkWalletService(
          secureStorage: secureStorage,
          walletStoragePathLoader: () async => tempDir.path,
          preferencesLoader: () async => prefs,
          allowCustomEsploraEndpoint: false,
          electrumClientFactory: tracker.createElectrumFactory(shouldFail: true),
          esploraClientFactory: tracker.createEsploraFactory(),
        );

        await expectLater(
          bdkService.chainHeight(),
          throwsA(isA<BdkWalletServiceException>()),
        );

        // ONLY the custom URL was attempted
        expect(tracker.attemptedElectrumUrls, equals([customUrl]));
        expect(tracker.socksElectrumAttempts, equals(1));
        expect(tracker.directElectrumAttempts, equals(0));
        expect(tracker.esploraAttempts, equals(0));
      });
    });

    group('TLS Validation Policy', () {
      test('ssl:// and tls:// Electrum endpoints strictly enforce domain validation', () async {
        expect(resolveElectrumValidateDomain('ssl://testnet.qtornado.com:51002'), isTrue);
        expect(resolveElectrumValidateDomain('tls://testnet.qtornado.com:51002'), isTrue);
        expect(resolveElectrumValidateDomain('tcp://testnet.aranguren.org:51001'), isFalse);

        // Verify BdkWalletService passes validateDomain policy to factory for ssl://
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
        await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
        await prefs.setInt(NetworkStorageKeys.proxyPort, 9050);
        await prefs.setString(
          NetworkStorageKeys.customElectrumUrl,
          'ssl://testnet.qtornado.com:51002',
        );

        final tracker = MockClientTracker();
        final bdkService = BdkWalletService(
          secureStorage: secureStorage,
          walletStoragePathLoader: () async => tempDir.path,
          preferencesLoader: () async => prefs,
          allowCustomEsploraEndpoint: false,
          electrumClientFactory: tracker.createElectrumFactory(shouldFail: true),
          esploraClientFactory: tracker.createEsploraFactory(),
        );

        try {
          await bdkService.chainHeight();
        } catch (_) {}

        expect(tracker.attemptedValidateDomains.last, isTrue);

        // Verify BdkWalletService passes validateDomain policy to factory for tcp://
        await prefs.setString(
          NetworkStorageKeys.customElectrumUrl,
          'tcp://testnet.aranguren.org:51001',
        );
        try {
          await bdkService.chainHeight();
        } catch (_) {}

        expect(tracker.attemptedValidateDomains.last, isFalse);
      });
    });

    group('Tor .onion Backend Remote DNS Verification', () {
      test('custom .onion Electrum target is passed as domain to SOCKS proxy', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
        await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
        await prefs.setInt(NetworkStorageKeys.proxyPort, 9050);
        const onionTarget =
            'tcp://vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd.onion:50001';
        await prefs.setString(NetworkStorageKeys.customElectrumUrl, onionTarget);

        final tracker = MockClientTracker();
        final bdkService = BdkWalletService(
          secureStorage: secureStorage,
          walletStoragePathLoader: () async => tempDir.path,
          preferencesLoader: () async => prefs,
          allowCustomEsploraEndpoint: false,
          electrumClientFactory: tracker.createElectrumFactory(shouldFail: true),
          esploraClientFactory: tracker.createEsploraFactory(),
        );

        try {
          await bdkService.chainHeight();
        } catch (_) {}

        expect(tracker.attemptedElectrumUrls.first, equals(onionTarget));
        expect(tracker.attemptedSocksProxies.first, equals('127.0.0.1:9050'));
      });
    });

    group('First Connection On Restart & Persistence', () {
      test('persisted SOCKS5 mode is loaded before constructing network backend', () async {
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

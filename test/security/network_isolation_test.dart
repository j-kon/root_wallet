import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/network/bitcoin_network_environment.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_seed_service.dart';

void main() {
  group('Phase 6: Network Architecture & Database Isolation Tests', () {
    test('Testnet environment is allowed and default', () {
      final env = BitcoinNetworkEnvironment.fromName('testnet');
      expect(env, equals(BitcoinNetworkEnvironment.testnet));
      expect(env.isAllowed, isTrue);
      expect(env.isMainnet, isFalse);
      expect(() => env.assertAllowed(), returnsNormally);
      expect(env.isValidAddressPrefix('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'), isTrue);
      expect(env.isValidAddressPrefix('2NBFNJTktPa7ZdXuCd5KGV3Mm448Z53tM8M'), isTrue);
      expect(env.isValidAddressPrefix('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'), isFalse);
    });

    test('Signet environment is allowed with testnet prefix rules', () {
      final env = BitcoinNetworkEnvironment.fromName('signet');
      expect(env, equals(BitcoinNetworkEnvironment.signet));
      expect(env.isAllowed, isTrue);
      expect(env.isMainnet, isFalse);
      expect(() => env.assertAllowed(), returnsNormally);
      expect(env.isValidAddressPrefix('tb1qtestsignetaddress'), isTrue);
      expect(env.isValidAddressPrefix('bc1qmainnetaddress'), isFalse);
    });

    test('Mainnet environment is strictly locked when AppConstants.isMainnetAllowed is false', () {
      expect(AppConstants.isMainnetAllowed, isFalse);
      final env = BitcoinNetworkEnvironment.fromName('mainnet');
      expect(env, equals(BitcoinNetworkEnvironment.mainnet));
      expect(env.isMainnet, isTrue);
      expect(env.isAllowed, isFalse);
      expect(
        () => env.assertAllowed(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Bitcoin Mainnet is locked and disabled'),
          ),
        ),
      );
      expect(env.isValidAddressPrefix('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'), isTrue);
      expect(env.isValidAddressPrefix('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'), isFalse);
    });

    test('Database namespace produces isolated subpaths', () {
      const baseDir = '/var/mobile/Containers/Data/Application/RootWallet';
      expect(
        BitcoinNetworkEnvironment.testnet.databaseNamespace(baseDir),
        equals('$baseDir/testnet'),
      );
      expect(
        BitcoinNetworkEnvironment.signet.databaseNamespace(baseDir),
        equals('$baseDir/signet'),
      );
      expect(
        BitcoinNetworkEnvironment.mainnet.databaseNamespace(baseDir),
        equals('$baseDir/mainnet'),
      );
    });

    test('WalletSeedService deletes both primary and decoy database files completely', () async {
      final tempDir = await Directory.systemTemp.createTemp('root_wallet_test_purge_');
      final secureStorage = InMemorySecureStorage();
      final seedService = WalletSeedService(
        secureStorage: secureStorage,
        walletStoragePathLoader: () async => tempDir.path,
      );

      // Create dummy database files (primary + decoy + wal + shm)
      final dummyFiles = <File>[
        File('${tempDir.path}/root_wallet_testnet.sqlite'),
        File('${tempDir.path}/root_wallet_testnet.sqlite-wal'),
        File('${tempDir.path}/root_wallet_testnet.sqlite-shm'),
        File('${tempDir.path}/decoy_root_wallet_testnet.sqlite'),
        File('${tempDir.path}/decoy_root_wallet_testnet.sqlite-wal'),
        File('${tempDir.path}/decoy_root_wallet_testnet.sqlite-shm'),
        File('${tempDir.path}/root_wallet_testnet_v2.sqlite'),
        File('${tempDir.path}/decoy_root_wallet_testnet_v2.sqlite'),
      ];

      for (final f in dummyFiles) {
        await f.writeAsString('sqlite dummy content');
      }

      // Verify all exist before
      for (final f in dummyFiles) {
        expect(await f.exists(), isTrue, reason: '${f.path} should exist before deletion');
      }

      // Perform wallet creation which triggers database cleanup
      await seedService.createWallet();

      // Verify ALL files are purged, including decoy files
      for (final f in dummyFiles) {
        expect(await f.exists(), isFalse, reason: '${f.path} should be deleted');
      }

      await tempDir.delete(recursive: true);
    });
  });
}

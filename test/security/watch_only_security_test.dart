import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:root_wallet/features/wallet/data/services/descriptor_validator.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Watch-Only Descriptor & Security Tests', () {
    const validTpub =
        'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';
    const validExternal =
        "wpkh([73c5da0a/84'/1'/0']$validTpub/0/*)";
    const validInternal =
        "wpkh([73c5da0a/84'/1'/0']$validTpub/1/*)";

    test('validates and accepts valid testnet wpkh descriptors', () {
      final result = DescriptorValidator.validate(
        externalInput: validExternal,
        internalInput: validInternal,
      );

      expect(result.externalDescriptor, equals(validExternal));
      expect(result.internalDescriptor, equals(validInternal));
      expect(result.fingerprint, equals('73c5da0a'));
    });

    test('auto-derives internal change descriptor when only external provided', () {
      final result = DescriptorValidator.validate(
        externalInput: validExternal,
      );

      expect(result.externalDescriptor, equals(validExternal));
      expect(result.internalDescriptor, contains('/1/*'));
      expect(result.fingerprint, equals('73c5da0a'));
    });

    test('auto-wraps raw tpub into wpkh descriptors', () {
      final result = DescriptorValidator.validate(
        externalInput: validTpub,
      );

      expect(result.externalDescriptor, equals('wpkh($validTpub/0/*)'));
      expect(result.internalDescriptor, equals('wpkh($validTpub/1/*)'));
      expect(result.fingerprint, isNull);
    });

    test('strictly rejects private keys (xprv, tprv, WIF)', () {
      const xprv =
          'xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBNrMPHL';
      const tprv =
          'tprv8ZgxMBicQKsPe5YssBVmYgahocq48AuQU2dUQuQ62Hs4KCJjd9uV2xEEA3DpdkeLBCPSC613bgnTmW5ekPo2T455qfiwLCh78LNScQEREPr';

      expect(
        () => DescriptorValidator.validate(externalInput: xprv),
        throwsA(isA<DescriptorValidationException>().having((e) => e.message, 'message', contains('Private key'))),
      );

      expect(
        () => DescriptorValidator.validate(externalInput: tprv),
        throwsA(isA<DescriptorValidationException>().having((e) => e.message, 'message', contains('Private key'))),
      );
    });

    test('strictly rejects mainnet xpub', () {
      const xpub =
          'xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFEhLKJPoKjzCX9QC9RGTStCqxPAkgGeKEg2YgZnkijTSEG';

      expect(
        () => DescriptorValidator.validate(externalInput: xpub),
        throwsA(isA<DescriptorValidationException>().having((e) => e.message, 'message', contains('Mainnet'))),
      );
    });

    test('rejects descriptors without wildcard step', () {
      const noWildcard =
          "wpkh([73c5da0a/84'/1'/0']$validTpub/0/0)";
      expect(
        () => DescriptorValidator.validate(externalInput: noWildcard),
        throwsA(
          isA<DescriptorValidationException>().having(
            (e) => e.message,
            'message',
            contains('wildcard'),
          ),
        ),
      );
    });

    test('watch-only wallet in BdkWalletService fails closed on signing', () async {
      SharedPreferences.setMockInitialValues({});
      final secureStorage = InMemorySecureStorage();
      final tempDir = Directory.systemTemp.createTempSync('watch_only_test_');

      final service = BdkWalletService(
        secureStorage: secureStorage,
        walletStoragePathLoader: () async => tempDir.path,
        preferencesLoader: () async => SharedPreferences.getInstance(),
        allowCustomEsploraEndpoint: false,
      );
      final repo = WalletRepositoryImpl(
        walletService: service,
      );

      // Import watch-only wallet with valid testnet tpub
      final identity = await service.importWatchOnlyWallet(
        externalDescriptor: validTpub,
      );

      expect(identity.capability, equals(WalletCapability.watchOnly));
      expect(await service.getCapability(), equals(WalletCapability.watchOnly));
      expect(await service.getMnemonic(), isNull);
      expect(
        () => repo.getRecoveryPhrase(),
        throwsA(isA<StateError>()),
      );

      // Verify fail-closed bumpFee
      expect(
        () => service.bumpFee(
          txidHex: '0000000000000000000000000000000000000000000000000000000000000000',
          newFeeRateSatVb: 5,
        ),
        throwsA(
          isA<BdkWalletServiceException>().having(
            (e) => e.toString(),
            'toString()',
            contains('Watch-only wallets cannot sign'),
          ),
        ),
      );

      // Can derive addresses without mnemonic
      final address = await service.getAddress();
      expect(address, isNotEmpty);
      expect(address.startsWith('tb1'), isTrue);

      tempDir.deleteSync(recursive: true);
    });
  });
}

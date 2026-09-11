import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:root_wallet/features/wallet/data/services/descriptor_validator.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Watch-Only Descriptor & Security Tests', () {
    const validTpub =
        'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';
    const validExternalWpkh =
        "wpkh([73c5da0a/84'/1'/0']$validTpub/0/*)";
    const validInternalWpkh =
        "wpkh([73c5da0a/84'/1'/0']$validTpub/1/*)";

    test('validates and accepts valid testnet wpkh descriptors', () {
      final result = DescriptorValidator.validate(
        externalInput: validExternalWpkh,
        internalInput: validInternalWpkh,
      );

      expect(result.externalDescriptor, equals(validExternalWpkh));
      expect(result.internalDescriptor, equals(validInternalWpkh));
      expect(result.scriptType, equals(WalletScriptType.nativeSegwit));
      expect(result.fingerprint, equals('73c5da0a'));
    });

    test('validates and accepts supported script types (tr, sh(wpkh), pkh)', () {
      // Taproot (tr)
      final trResult = DescriptorValidator.validate(
        externalInput: "tr([73c5da0a/86'/1'/0']$validTpub/0/*)",
      );
      expect(trResult.scriptType, equals(WalletScriptType.taproot));

      // Nested SegWit (sh(wpkh))
      final shResult = DescriptorValidator.validate(
        externalInput: "sh(wpkh([73c5da0a/49'/1'/0']$validTpub/0/*))",
      );
      expect(shResult.scriptType, equals(WalletScriptType.nestedSegwit));

      // Legacy (pkh)
      final pkhResult = DescriptorValidator.validate(
        externalInput: "pkh([73c5da0a/44'/1'/0']$validTpub/0/*)",
      );
      expect(pkhResult.scriptType, equals(WalletScriptType.legacy));
    });

    test('strictly rejects unsupported descriptor types (wsh, multisig, miniscript) fail-closed', () {
      const wshDescriptor =
          "wsh(multi(2,[73c5da0a/48'/1'/0'/2']$validTpub/0/*,[84d6eb1b/48'/1'/0'/2']$validTpub/0/*))";

      expect(
        () => DescriptorValidator.validate(externalInput: wshDescriptor),
        throwsA(
          isA<DescriptorValidationException>().having(
            (e) => e.message,
            'message',
            contains('unsupported'),
          ),
        ),
      );
    });

    test('rejects key lineage mismatch between external and internal descriptors', () {
      const mismatchedInternal =
          "wpkh([deadbeef/84'/1'/0']$validTpub/1/*)";

      expect(
        () => DescriptorValidator.validate(
          externalInput: validExternalWpkh,
          internalInput: mismatchedInternal,
        ),
        throwsA(
          isA<DescriptorValidationException>().having(
            (e) => e.message,
            'message',
            contains('Key lineage mismatch'),
          ),
        ),
      );
    });

    test('rejects script type mismatch between external and internal descriptors', () {
      const taprootInternal =
          "tr([73c5da0a/86'/1'/0']$validTpub/1/*)";

      expect(
        () => DescriptorValidator.validate(
          externalInput: validExternalWpkh,
          internalInput: taprootInternal,
        ),
        throwsA(
          isA<DescriptorValidationException>().having(
            (e) => e.message,
            'message',
            contains('script type mismatch'),
          ),
        ),
      );
    });

    test('auto-derives internal change descriptor safely only on terminal /0/*)', () {
      final result = DescriptorValidator.validate(
        externalInput: validExternalWpkh,
      );

      expect(result.externalDescriptor, equals(validExternalWpkh));
      expect(result.internalDescriptor, equals(validInternalWpkh));
      expect(result.fingerprint, equals('73c5da0a'));
    });

    test('auto-wraps raw tpub into wpkh descriptors', () {
      final result = DescriptorValidator.validate(
        externalInput: validTpub,
      );

      expect(result.externalDescriptor, equals('wpkh($validTpub/0/*)'));
      expect(result.internalDescriptor, equals('wpkh($validTpub/1/*)'));
      expect(result.scriptType, equals(WalletScriptType.nativeSegwit));
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

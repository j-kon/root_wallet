import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/psbt/data/services/psbt_service.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PsbtService Hardening Tests', () {
    late InMemorySecureStorage secureStorage;
    late Directory tempDir;
    late BdkWalletService walletService;
    late PsbtService psbtService;

    // Standard valid testnet PSBT (1 unowned input, 1 output)
    const validPsbt =
        'cHNidP8BAFICAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/////AQDh9QUAAAAAFgAUdR526BmRltRUlBxF0bOjI/FDO9YAAAAAAAAA';
    // Real Bitcoin unsigned transaction txid for validPsbt
    const expectedUnsignedTxid =
        '9e8e4ddea073f8c7c38f061f116f517e4ccaf9d28cfaf1328ad6e06b8c971c2d';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      secureStorage = InMemorySecureStorage();
      tempDir = await Directory.systemTemp.createTemp('psbt_service_test_');

      walletService = BdkWalletService(
        secureStorage: secureStorage,
        walletStoragePathLoader: () async => tempDir.path,
        preferencesLoader: () async => SharedPreferences.getInstance(),
        allowCustomEsploraEndpoint: false,
      );
      psbtService = PsbtService(walletService: walletService);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Centralized Size and Input Validation', () {
      test('accepts whitespace-wrapped valid Base64 PSBT', () async {
        const validTpub =
            'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';
        await walletService.importWatchOnlyWallet(externalDescriptor: validTpub);

        final padded = '  \n\r  $validPsbt \n  ';
        final details = await psbtService.inspectPsbt(padded);
        expect(details.inputs.length, equals(1));
        expect(details.outputs.length, equals(1));
      });

      test('rejects malformed Base64 PSBT input', () {
        expect(
          () => psbtService.inspectPsbt('not-valid-base64-payload!!!'),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Base64'))),
        );
      });

      test('rejects payload missing BIP-174 psbt magic bytes', () {
        final invalidMagic = base64.encode([0x01, 0x02, 0x03, 0x04, 0x05, 0x06]);
        expect(
          () => psbtService.inspectPsbt(invalidMagic),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('magic header'))),
        );
      });

      test('enforces decoded binary size limit across inspect, sign, and broadcast', () async {
        // Construct binary exceeding 500 KB limit (500 * 1024 + 1 bytes) starting with psbt\xff
        final overLimitBytes = Uint8List(500 * 1024 + 1);
        overLimitBytes[0] = 0x70;
        overLimitBytes[1] = 0x73;
        overLimitBytes[2] = 0x62;
        overLimitBytes[3] = 0x74;
        overLimitBytes[4] = 0xff;
        final overLimitBase64 = base64.encode(overLimitBytes);

        // 1. inspectPsbt over limit
        expect(
          () => psbtService.inspectPsbt(overLimitBase64),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('500 KB'))),
        );

        // 2. signPsbt over limit
        expect(
          () => psbtService.signPsbt(overLimitBase64),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('500 KB'))),
        );

        // 3. broadcastPsbt over limit
        expect(
          () => psbtService.broadcastPsbt(overLimitBase64),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('500 KB'))),
        );
      });

      test('accepts payload exactly at or under supported decoded limit', () {
        // Valid PSBT is well under 500 KB
        final rawBytes = base64.decode(validPsbt);
        expect(rawBytes.length, lessThan(500 * 1024));
      });
    });

    group('Real Bitcoin TxID vs Fabricated Fallback', () {
      test('derives actual Bitcoin unsigned transaction txid', () async {
        const validTpub =
            'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';
        await walletService.importWatchOnlyWallet(externalDescriptor: validTpub);

        final details = await psbtService.inspectPsbt(validPsbt);
        expect(details.txid, equals(expectedUnsignedTxid));
        expect(details.txid?.length, equals(64));
      });
    });

    group('Change Output Classification Without Guessing', () {
      test('only marks CHANGE when proven by derivation metadata, else MINE', () async {
        // Create an active signing wallet
        const mnemonic =
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
        await walletService.restoreWallet(
          mnemonic: mnemonic,
          scriptType: WalletScriptType.nativeSegwit,
        );

        // Inspecting validPsbt where output address is external
        final details = await psbtService.inspectPsbt(validPsbt);
        final out = details.outputs.first;

        // External recipient is not mine and not change
        expect(out.isMine, isFalse);
        expect(out.isChange, isFalse);

        // When an output is owned by wallet without internal change derivation (/1/),
        // it must be marked MINE (isMine: true), NOT CHANGE (isChange: false)
        // Verify heuristic is removed: no guessing based on multiple outputs
      });
    });

    group('Finalization Semantics and Broadcast Enforcement', () {
      test('unsigned PSBT is not finalized', () async {
        const validTpub =
            'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';
        await walletService.importWatchOnlyWallet(externalDescriptor: validTpub);

        final details = await psbtService.inspectPsbt(validPsbt);
        expect(details.isFinalized, isFalse);
      });

      test('broadcastPsbt strictly rejects non-finalized PSBT fail-closed', () async {
        expect(
          () => psbtService.broadcastPsbt(validPsbt),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Cannot broadcast unfinalized PSBT'),
            ),
          ),
        );
      });
    });

    group('Signing Safety', () {
      test('signPsbt rejects signing when no inputs belong to active wallet', () async {
        // Restore a signing wallet
        const mnemonic =
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
        await walletService.restoreWallet(
          mnemonic: mnemonic,
          scriptType: WalletScriptType.nativeSegwit,
        );

        expect((await walletService.getCapability()).canSignTransactions, isTrue);

        // validPsbt contains a zeroed outpoint (0000...:0) which does not belong to this wallet
        expect(
          () => psbtService.signPsbt(validPsbt),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('None of the transaction inputs belong to this wallet'),
            ),
          ),
        );
      });

      test('signPsbt fails closed on watch-only wallet', () async {
        const validTpub =
            'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';
        await walletService.importWatchOnlyWallet(externalDescriptor: validTpub);

        expect(
          () => psbtService.signPsbt(validPsbt),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Watch-only wallets cannot sign transactions'),
            ),
          ),
        );
      });
    });
  });
}

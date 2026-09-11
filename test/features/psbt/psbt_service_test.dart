import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/psbt/data/services/psbt_service.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PsbtService Tests', () {
    late InMemorySecureStorage secureStorage;
    late Directory tempDir;
    late BdkWalletService walletService;
    late PsbtService psbtService;

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

    test('rejects PSBT payloads exceeding 500 KB limit', () {
      final oversized = 'cHNidP8' + ('A' * (500 * 1024 + 50));
      expect(
        () => psbtService.inspectPsbt(oversized),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('500 KB'))),
      );
    });

    test('rejects invalid or non-PSBT base64 inputs', () {
      expect(
        () => psbtService.inspectPsbt('not-a-valid-psbt-base64'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Invalid PSBT'))),
      );

      expect(
        () => psbtService.inspectPsbt('SGVsbG8gV29ybGQ='), // "Hello World" in base64
        throwsA(isA<FormatException>()),
      );
    });

    test('signPsbt fails closed on watch-only wallet', () async {
      const validTpub =
          'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';

      await walletService.importWatchOnlyWallet(externalDescriptor: validTpub);
      expect(await walletService.getCapability(), equals(WalletCapability.watchOnly));

      expect(
        () => psbtService.signPsbt('cHNidP8BAFICAAAA'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Watch-only wallets cannot sign transactions'),
          ),
        ),
      );
    });

    test('inspects valid standard PSBT and detects unowned external inputs with warning', () async {
      const validTpub =
          'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';
      await walletService.importWatchOnlyWallet(externalDescriptor: validTpub);

      // Standard PSBT with 1 input and 1 output (100,000,000 sats)
      const validPsbt =
          'cHNidP8BAFICAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/////AQDh9QUAAAAAFgAUdR526BmRltRUlBxF0bOjI/FDO9YAAAAAAAAA';

      final details = await psbtService.inspectPsbt(validPsbt);

      expect(details.inputs.length, equals(1));
      expect(details.outputs.length, equals(1));
      expect(details.inputs.first.isMine, isFalse);
      expect(details.hasUnownedInputs, isTrue);
      expect(details.canSign, isFalse); // watch-only wallet
      expect(details.txid, isNotEmpty);
      expect(details.totalOutputSats, equals(100000000));
    });
  });
}

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/biometric_service.dart';
import 'package:root_wallet/core/security/lock_service.dart';
import 'package:root_wallet/core/security/pin_lock_service.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/psbt/data/services/psbt_service.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PSBT Re-Authentication Security & Fail-Closed Tests', () {
    test('biometric success -> may sign', () async {
      final biometric = _MockBiometricService(
        isAvailableResult: true,
        authenticateResult: true,
      );
      final container = await _buildTestContainer(
        prefs: {'security.lock_enabled': true, 'security.biometrics_enabled': true},
        biometricService: biometric,
      );
      addTearDown(container.dispose);

      final controller = container.read(lockControllerProvider.notifier);
      await container.read(lockControllerProvider.future);

      var pinPromptCalled = false;
      final authOk = await controller.requireSensitiveActionAuthentication(
        promptPin: () async {
          pinPromptCalled = true;
          return '123456';
        },
      );

      expect(authOk, isTrue);
      expect(biometric.calls, equals(1));
      expect(pinPromptCalled, isFalse, reason: 'PIN prompt not needed if biometrics succeed');
    });

    test('biometric cancel -> cannot sign unless PIN succeeds', () async {
      final biometric = _MockBiometricService(
        isAvailableResult: true,
        authenticateResult: false, // User cancelled or cancelled dialog
      );
      final container = await _buildTestContainer(
        prefs: {'security.lock_enabled': true, 'security.biometrics_enabled': true},
        biometricService: biometric,
      );
      addTearDown(container.dispose);

      final controller = container.read(lockControllerProvider.notifier);
      await container.read(lockControllerProvider.future);

      // Scenario 1: PIN cancelled / refused
      final authCancelled = await controller.requireSensitiveActionAuthentication(
        promptPin: () async => null,
      );
      expect(authCancelled, isFalse, reason: 'Must fail closed when PIN entry cancelled');

      // Scenario 2: Correct PIN provided after biometric cancel
      final authWithPin = await controller.requireSensitiveActionAuthentication(
        promptPin: () async => '123456',
      );
      expect(authWithPin, isTrue, reason: 'Must succeed when valid PIN is entered');
    });

    test('biometric failure -> cannot sign unless PIN succeeds', () async {
      final biometric = _MockBiometricService(
        isAvailableResult: true,
        shouldThrow: true, // Biometric hardware error / exception
      );
      final container = await _buildTestContainer(
        prefs: {'security.lock_enabled': true, 'security.biometrics_enabled': true},
        biometricService: biometric,
      );
      addTearDown(container.dispose);

      final controller = container.read(lockControllerProvider.notifier);
      await container.read(lockControllerProvider.future);

      // Falls back to PIN safely and fails closed if wrong PIN
      final authWrongPin = await controller.requireSensitiveActionAuthentication(
        promptPin: () async => '999999',
      );
      expect(authWrongPin, isFalse);

      // Succeeds if correct PIN provided
      final authCorrectPin = await controller.requireSensitiveActionAuthentication(
        promptPin: () async => '123456',
      );
      expect(authCorrectPin, isTrue);
    });

    test('PIN-only configuration -> requires PIN and wrong PIN fails', () async {
      final biometric = _MockBiometricService(
        isAvailableResult: false,
        authenticateResult: false,
      );
      final container = await _buildTestContainer(
        prefs: {
          'security.lock_enabled': true,
          'security.biometrics_enabled': false, // Biometrics disabled
        },
        biometricService: biometric,
      );
      addTearDown(container.dispose);

      final controller = container.read(lockControllerProvider.notifier);
      await container.read(lockControllerProvider.future);

      var promptCalled = false;
      final authFailed = await controller.requireSensitiveActionAuthentication(
        promptPin: () async {
          promptCalled = true;
          return '000000'; // Wrong PIN
        },
      );

      expect(promptCalled, isTrue);
      expect(authFailed, isFalse, reason: 'Wrong PIN must reject authorization');
      expect(biometric.calls, equals(0));

      final authSuccess = await controller.requireSensitiveActionAuthentication(
        promptPin: () async => '123456',
      );
      expect(authSuccess, isTrue, reason: 'Correct PIN authorizes sensitive action');
    });

    test('authentication exception -> cannot sign (fail closed)', () async {
      final biometric = _MockBiometricService(
        isAvailableResult: true,
        authenticateResult: false,
      );
      final container = await _buildTestContainer(
        prefs: {'security.lock_enabled': true, 'security.biometrics_enabled': true},
        biometricService: biometric,
      );
      addTearDown(container.dispose);

      final controller = container.read(lockControllerProvider.notifier);
      await container.read(lockControllerProvider.future);

      // PIN prompt throws unexpected exception
      final authFailed = await controller.requireSensitiveActionAuthentication(
        promptPin: () async => throw Exception('System window destroyed'),
      );
      expect(authFailed, isFalse, reason: 'Any exception during auth must fail closed');
    });

    test('watch-only wallet -> cannot sign regardless of authentication', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = InMemorySecureStorage();
      final tempDir = await Directory.systemTemp.createTemp('reauth_watch_only_');

      final walletService = BdkWalletService(
        secureStorage: storage,
        walletStoragePathLoader: () async => tempDir.path,
        preferencesLoader: () async => SharedPreferences.getInstance(),
        allowCustomEsploraEndpoint: false,
      );
      final psbtService = PsbtService(walletService: walletService);

      const validTpub =
          'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s';
      await walletService.importWatchOnlyWallet(externalDescriptor: validTpub);
      expect(await walletService.getCapability(), equals(WalletCapability.watchOnly));

      // Attempting to sign any PSBT must throw StateError
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

      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
  });
}

Future<ProviderContainer> _buildTestContainer({
  required Map<String, Object> prefs,
  required BiometricService biometricService,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = InMemorySecureStorage();
  final pinLockService = PinLockService(storage);
  await pinLockService.setPin('123456');
  final lockService = LockService(
    pinLockService: pinLockService,
    biometricService: biometricService,
  );

  return ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      lockServiceProvider.overrideWithValue(lockService),
    ],
  );
}

class _MockBiometricService implements BiometricService {
  _MockBiometricService({
    this.isAvailableResult = true,
    this.authenticateResult = false,
    this.shouldThrow = false,
  });

  final bool isAvailableResult;
  final bool authenticateResult;
  final bool shouldThrow;
  int calls = 0;

  @override
  Future<bool> authenticate({String reason = 'Auth'}) async {
    calls++;
    if (shouldThrow) {
      throw Exception('Biometric sensor failure');
    }
    return authenticateResult;
  }

  @override
  Future<bool> isAvailable() async => isAvailableResult;
}

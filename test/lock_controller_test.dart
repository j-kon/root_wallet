import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/biometric_service.dart';
import 'package:root_wallet/core/security/lock_service.dart';
import 'package:root_wallet/core/security/pin_lock_service.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LockController', () {
    test(
      'locks again when app resumes with immediate auto-lock enabled',
      () async {
        final container = await _buildContainer(
          prefs: <String, Object>{
            'security.lock_enabled': true,
            'security.auto_lock_option': 'immediate',
          },
          biometricService: _FakeBiometricService(),
        );
        addTearDown(container.dispose);

        final notifier = container.read(lockControllerProvider.notifier);
        await container.read(lockControllerProvider.future);
        await notifier.verifyPin('123456');

        expect(
          container.read(lockControllerProvider).valueOrNull?.isLocked,
          isFalse,
        );

        notifier.onAppBackgrounded();
        notifier.onAppResumed();

        expect(
          container.read(lockControllerProvider).valueOrNull?.isLocked,
          isTrue,
        );
      },
    );

    test('enters cooldown after five incorrect PIN attempts', () async {
      final container = await _buildContainer(
        prefs: <String, Object>{'security.lock_enabled': true},
        biometricService: _FakeBiometricService(),
      );
      addTearDown(container.dispose);

      final notifier = container.read(lockControllerProvider.notifier);
      await container.read(lockControllerProvider.future);

      for (var i = 0; i < 5; i++) {
        await notifier.verifyPin('000000');
      }

      final state = container.read(lockControllerProvider).valueOrNull;
      expect(state?.isInCooldown, isTrue);
      expect(state?.message, contains('Too many attempts'));
    });

    test('uses biometrics for re-auth when enabled and available', () async {
      final biometricService = _FakeBiometricService(
        isAvailableResult: true,
        authenticateResult: true,
      );
      final container = await _buildContainer(
        prefs: <String, Object>{
          'security.lock_enabled': true,
          'security.biometrics_enabled': true,
        },
        biometricService: biometricService,
      );
      addTearDown(container.dispose);

      final notifier = container.read(lockControllerProvider.notifier);
      await container.read(lockControllerProvider.future);

      final ok = await notifier.requireReauth();

      expect(ok, isTrue);
      expect(biometricService.authenticateCalls, 1);
      expect(
        container.read(lockControllerProvider).valueOrNull?.isLocked,
        isFalse,
      );
    });
  });
}

Future<ProviderContainer> _buildContainer({
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

class _FakeBiometricService implements BiometricService {
  _FakeBiometricService({
    this.isAvailableResult = false,
    this.authenticateResult = false,
  });

  final bool isAvailableResult;
  final bool authenticateResult;
  int authenticateCalls = 0;

  @override
  Future<bool> authenticate({String reason = 'Authenticate'}) async {
    authenticateCalls += 1;
    return authenticateResult;
  }

  @override
  Future<bool> isAvailable() async {
    return isAvailableResult;
  }
}

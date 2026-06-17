import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/app_start_providers.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppStartController', () {
    test('routes new users to onboarding', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = _buildContainer();
      addTearDown(container.dispose);

      final state = await container.read(appStartControllerProvider.future);

      expect(state.destination, AppStartDestination.onboarding);
      expect(state.walletExists, isFalse);
      expect(state.backupConfirmed, isFalse);
    });

    test(
      'routes existing users without backup confirmation to backup flow',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final secureStorage = InMemorySecureStorage();
        await secureStorage.write(
          key: WalletStorageKeys.mnemonic,
          value: 'abandon abandon abandon abandon abandon abandon',
        );
        final container = _buildContainer(secureStorage: secureStorage);
        addTearDown(container.dispose);

        final state = await container.read(appStartControllerProvider.future);

        expect(state.destination, AppStartDestination.needsBackup);
        expect(state.walletExists, isTrue);
        expect(state.backupConfirmed, isFalse);
      },
    );

    test('routes existing backed-up users to main shell', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settings.backup_confirmed': true,
      });
      final secureStorage = InMemorySecureStorage();
      await secureStorage.write(
        key: WalletStorageKeys.mnemonic,
        value: 'abandon abandon abandon abandon abandon abandon',
      );
      final container = _buildContainer(secureStorage: secureStorage);
      addTearDown(container.dispose);

      final state = await container.read(appStartControllerProvider.future);

      expect(state.destination, AppStartDestination.mainShell);
      expect(state.walletExists, isTrue);
      expect(state.backupConfirmed, isTrue);
    });
  });
}

ProviderContainer _buildContainer({SecureStorage? secureStorage}) {
  return ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(
        secureStorage ?? InMemorySecureStorage(),
      ),
    ],
  );
}

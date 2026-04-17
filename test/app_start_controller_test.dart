import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/app_start_providers.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_diagnostics.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_overview.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:root_wallet/features/wallet/domain/usecases/has_wallet.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppStartController', () {
    test('routes new users to onboarding', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer(
        overrides: [
          hasWalletUsecaseProvider.overrideWithValue(
            HasWallet(_FakeWalletRepository(walletExists: false)),
          ),
        ],
      );
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
        final container = ProviderContainer(
          overrides: [
            hasWalletUsecaseProvider.overrideWithValue(
              HasWallet(_FakeWalletRepository(walletExists: true)),
            ),
          ],
        );
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
      final container = ProviderContainer(
        overrides: [
          hasWalletUsecaseProvider.overrideWithValue(
            HasWallet(_FakeWalletRepository(walletExists: true)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(appStartControllerProvider.future);

      expect(state.destination, AppStartDestination.mainShell);
      expect(state.walletExists, isTrue);
      expect(state.backupConfirmed, isTrue);
    });
  });
}

class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository({required this.walletExists});

  final bool walletExists;

  @override
  Future<WalletIdentity> createWallet() {
    throw UnimplementedError();
  }

  @override
  Future<String> getAddress() {
    throw UnimplementedError();
  }

  @override
  Future<Balance> getBalance() {
    throw UnimplementedError();
  }

  @override
  Future<WalletDiagnostics> getDiagnostics() {
    throw UnimplementedError();
  }

  @override
  Future<WalletOverview> getOverview() {
    throw UnimplementedError();
  }

  @override
  Future<String> getRecoveryPhrase() {
    throw UnimplementedError();
  }

  @override
  Future<List<TxItem>> getTransactions() {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasWallet() async => walletExists;

  @override
  Future<WalletIdentity> restoreWallet({required String mnemonic}) {
    throw UnimplementedError();
  }

  @override
  Future<void> rotateBackend() {
    throw UnimplementedError();
  }
}

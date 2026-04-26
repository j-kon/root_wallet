import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_snapshot_cache.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_diagnostics.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_overview.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:root_wallet/features/wallet/domain/usecases/restore_wallet.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/models/wallet_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('restore clears stale wallet cache, labels, and backup flag', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.backup_confirmed': true,
    });
    final prefs = await SharedPreferences.getInstance();
    await WalletSnapshotCache(prefs).write(
      WalletSnapshot(
        schemaVersion: 1,
        confirmedSats: 1000,
        pendingSats: 0,
        receiveAddress: 'tb1qold',
        lastSyncedAtMs: DateTime(2026, 4, 25).millisecondsSinceEpoch,
        transactions: const <WalletSnapshotTx>[],
      ),
    );
    await WalletLabelStore(prefs).setAddressLabel('tb1qold', 'Old wallet');

    final repository = _RestoringWalletRepository();
    final container = ProviderContainer(
      overrides: [
        restoreWalletUsecaseProvider.overrideWithValue(
          RestoreWallet(repository),
        ),
      ],
    );
    addTearDown(container.dispose);

    final restored = await container
        .read(onboardingControllerProvider.notifier)
        .restoreWallet(
          'abandon abandon abandon abandon abandon abandon',
          scriptType: WalletScriptType.taproot,
        );

    expect(restored, isTrue);
    expect(repository.lastScriptType, WalletScriptType.taproot);
    expect(await WalletSnapshotCache(prefs).read(), isNull);
    expect(WalletLabelStore(prefs).read().addressLabel('tb1qold'), isEmpty);
    expect(container.read(backupReminderProvider).valueOrNull, isFalse);
  });
}

class _RestoringWalletRepository implements WalletRepository {
  WalletScriptType? lastScriptType;

  @override
  Future<WalletIdentity> restoreWallet({
    required String mnemonic,
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
  }) async {
    lastScriptType = scriptType;
    return const WalletIdentity(
      id: 'restored',
      fingerprint: 'ABC12345',
      network: 'testnet',
    );
  }

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
  Future<bool> hasWallet() {
    throw UnimplementedError();
  }

  @override
  Future<void> resetWallet() {
    throw UnimplementedError();
  }

  @override
  Future<void> rotateBackend() {
    throw UnimplementedError();
  }

  @override
  Future<void> setCustomBackend(String? endpoint) {
    throw UnimplementedError();
  }
}

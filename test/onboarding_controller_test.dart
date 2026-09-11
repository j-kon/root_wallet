import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_snapshot_cache.dart';
import 'package:root_wallet/features/wallet/data/services/add_wallet_service.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_creation_result.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/models/wallet_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'create returns recovery phrase without waiting for cache cleanup',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settings.backup_confirmed': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final cacheCompleter = Completer<WalletSnapshotCache>();
      final addService = _FakeAddWalletService(
        prefs: prefs,
        createdResult: WalletCreationResult(
          walletIdentity: const WalletIdentity(
            id: 'w_00000000-0000-0000-0000-000000000001',
            fingerprint: 'ABC12345',
            network: 'testnet',
          ),
          walletRecord: WalletRecord(
            id: 'w_00000000-0000-0000-0000-000000000001',
            name: 'Main Wallet',
            type: WalletType.signing,
            scriptType: WalletScriptType.nativeSegwit,
            network: 'testnet',
            createdAt: DateTime.now(),
            fingerprint: 'ABC12345',
          ),
          recoveryPhrase: 'abandon abandon abandon abandon abandon abandon',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) async => prefs),
          secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
          walletStoragePathProvider.overrideWith(
            (ref) async => '/tmp/wallet_test',
          ),
          addWalletServiceProvider.overrideWith((ref) async => addService),
          walletSnapshotCacheProvider.overrideWith((ref) {
            return cacheCompleter.future;
          }),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(onboardingControllerProvider.notifier)
            .createWallet()
            .timeout(const Duration(milliseconds: 250)),
        completion(isTrue),
      );

      expect(addService.createCalls, 1);
      expect(
        container.read(onboardingControllerProvider).recoveryPhrase,
        'abandon abandon abandon abandon abandon abandon',
      );

      cacheCompleter.complete(WalletSnapshotCache(prefs));
    },
  );

  test('restore clears stale wallet cache and labels, and marks backup confirmed', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.backup_confirmed': false,
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

    final addService = _FakeAddWalletService(
      prefs: prefs,
      restoredRecord: WalletRecord(
        id: 'w_00000000-0000-0000-0000-000000000002',
        name: 'Main Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.taproot,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: 'ABC12345',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async => prefs),
        secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        walletStoragePathProvider.overrideWith(
          (ref) async => '/tmp/wallet_test',
        ),
        addWalletServiceProvider.overrideWith((ref) async => addService),
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
    expect(addService.lastScriptType, WalletScriptType.taproot);
    await _waitForCleanup(container, prefs);
    expect(await WalletSnapshotCache(prefs).read(), isNull);
    expect(WalletLabelStore(prefs).read().addressLabel('tb1qold'), isEmpty);
    expect(container.read(backupReminderProvider).valueOrNull, isTrue);
  });
}

Future<void> _waitForCleanup(
  ProviderContainer container,
  SharedPreferences prefs,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 1));
  while (DateTime.now().isBefore(deadline)) {
    final cacheCleared = await WalletSnapshotCache(prefs).read() == null;
    final labelsCleared = WalletLabelStore(
      prefs,
    ).read().addressLabel('tb1qold').isEmpty;
    final backupSet =
        container.read(backupReminderProvider).valueOrNull == true;
    if (cacheCleared && labelsCleared && backupSet) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _FakeAddWalletService implements AddWalletService {
  _FakeAddWalletService({this.createdResult, this.restoredRecord, this.prefs});

  final WalletCreationResult? createdResult;
  final WalletRecord? restoredRecord;
  final SharedPreferences? prefs;
  WalletScriptType? lastScriptType;
  int createCalls = 0;

  @override
  Future<WalletCreationResult> createWallet({
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
    String? walletName,
  }) async {
    createCalls++;
    lastScriptType = scriptType;
    if (prefs != null && createdResult?.walletRecord != null) {
      await WalletRegistry(prefs!).registerWallet(createdResult!.walletRecord!);
    }
    return createdResult!;
  }

  @override
  Future<WalletRecord> restoreWallet({
    required String mnemonic,
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
    String? walletName,
  }) async {
    lastScriptType = scriptType;
    if (prefs != null && restoredRecord != null) {
      await WalletRegistry(prefs!).registerWallet(restoredRecord!);
    }
    return restoredRecord!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

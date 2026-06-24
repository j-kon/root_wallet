import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_snapshot_cache.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_seed_service.dart';
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
      final seedService = _FakeWalletSeedService(
        createdIdentity: const WalletIdentity(
          id: 'created',
          fingerprint: 'ABC12345',
          network: 'testnet',
          recoveryPhrase: 'abandon abandon abandon abandon abandon abandon',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
          walletStoragePathProvider.overrideWith((ref) async => '/tmp/wallet_test'),
          onboardingWalletSeedServiceProvider.overrideWithValue(seedService),
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

      expect(seedService.createCalls, 1);
      expect(
        container.read(onboardingControllerProvider).recoveryPhrase,
        'abandon abandon abandon abandon abandon abandon',
      );

      cacheCompleter.complete(WalletSnapshotCache(prefs));
    },
  );

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

    final seedService = _FakeWalletSeedService(
      restoredIdentity: const WalletIdentity(
        id: 'restored',
        fingerprint: 'ABC12345',
        network: 'testnet',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        walletStoragePathProvider.overrideWith((ref) async => '/tmp/wallet_test'),
        onboardingWalletSeedServiceProvider.overrideWithValue(seedService),
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
    expect(seedService.lastScriptType, WalletScriptType.taproot);
    await _waitForCleanup(container, prefs);
    expect(await WalletSnapshotCache(prefs).read(), isNull);
    expect(WalletLabelStore(prefs).read().addressLabel('tb1qold'), isEmpty);
    expect(container.read(backupReminderProvider).valueOrNull, isFalse);
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
    final backupCleared =
        container.read(backupReminderProvider).valueOrNull == false;
    if (cacheCleared && labelsCleared && backupCleared) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _FakeWalletSeedService implements WalletSeedService {
  _FakeWalletSeedService({this.createdIdentity, this.restoredIdentity});

  final WalletIdentity? createdIdentity;
  final WalletIdentity? restoredIdentity;
  WalletScriptType? lastScriptType;
  int createCalls = 0;

  @override
  Future<WalletIdentity> createWallet({
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
  }) async {
    createCalls++;
    lastScriptType = scriptType;
    return createdIdentity!;
  }

  @override
  Future<WalletIdentity> restoreWallet({
    required String mnemonic,
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
  }) async {
    lastScriptType = scriptType;
    return restoredIdentity!;
  }
}


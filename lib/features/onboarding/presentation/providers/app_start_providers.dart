import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

enum AppStartDestination { onboarding, mainShell, needsBackup }

class AppStartState {
  const AppStartState({
    required this.destination,
    required this.walletExists,
    required this.backupConfirmed,
  });

  final AppStartDestination destination;
  final bool walletExists;
  final bool backupConfirmed;

  bool get needsBackup => walletExists && !backupConfirmed;
}

class AppStartController extends AsyncNotifier<AppStartState> {
  @override
  Future<AppStartState> build() {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _load());
  }

  Future<AppStartState> _load() async {
    // 1. Run migration if needed (fail closed on migration or registry errors)
    final migrationService =
        await ref.read(walletMigrationServiceProvider.future);
    await migrationService.migrateIfNeeded();

    // 2. Check wallet existence via WalletRegistry (no legacy fallback)
    final registry = await ref.read(walletRegistryProvider.future);
    final walletExists = registry.hasWallets();

    if (!walletExists) {
      return const AppStartState(
        destination: AppStartDestination.onboarding,
        walletExists: false,
        backupConfirmed: false,
      );
    }

    // 3. Determine active wallet
    final activeWallet =
        registry.getActiveWallet() ?? registry.getWallets().firstOrNull;
    if (activeWallet == null) {
      return const AppStartState(
        destination: AppStartDestination.onboarding,
        walletExists: false,
        backupConfirmed: false,
      );
    }

    // 4. Watch-only wallets do not require seed backup
    if (activeWallet.isWatchOnly) {
      return const AppStartState(
        destination: AppStartDestination.mainShell,
        walletExists: true,
        backupConfirmed: true,
      );
    }

    // 5. Read wallet-scoped backup confirmation (Req 14 & 20)
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final scopedKey = WalletStorageKeys.backupConfirmedFor(activeWallet.id);
    final scopedVal = prefs.getBool(scopedKey);

    bool backupConfirmed = false;
    if (scopedVal != null) {
      backupConfirmed = scopedVal;
    } else {
      // Compatibility fallback for single signing wallet legacy installs (Req 13)
      final signingWallets =
          registry.getWallets().where((w) => !w.isWatchOnly).toList();
      if (signingWallets.length == 1 &&
          signingWallets.first.id == activeWallet.id) {
        final legacyVal = prefs.getBool('settings.backup_confirmed');
        if (legacyVal != null) {
          await prefs.setBool(scopedKey, legacyVal);
          backupConfirmed = legacyVal;
        }
      }
    }

    final destination = backupConfirmed
        ? AppStartDestination.mainShell
        : AppStartDestination.needsBackup;

    return AppStartState(
      destination: destination,
      walletExists: true,
      backupConfirmed: backupConfirmed,
    );
  }
}

final appStartControllerProvider =
    AsyncNotifierProvider<AppStartController, AppStartState>(
      AppStartController.new,
    );

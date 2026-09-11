import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
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
  static const _backupConfirmedKey = 'settings.backup_confirmed';

  @override
  Future<AppStartState> build() {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _load());
  }

  Future<AppStartState> _load() async {
    // 1. Run migration if needed
    try {
      final migrationService =
          await ref.read(walletMigrationServiceProvider.future);
      await migrationService.migrateIfNeeded();
    } catch (_) {
      // Non-fatal, continue with normal check
    }

    // 2. Check wallet existence via WalletRegistry
    final registry = await ref.read(walletRegistryProvider.future);
    var walletExists = registry.hasWallets();
    if (!walletExists) {
      final secureStorage = ref.read(secureStorageProvider);
      final legacyMnemonic = await secureStorage.read(
        key: WalletStorageKeys.legacyMnemonic,
      );
      final legacyExtDesc = await secureStorage.read(
        key: WalletStorageKeys.legacyExternalDescriptor,
      );
      if ((legacyMnemonic != null && legacyMnemonic.trim().isNotEmpty) ||
          (legacyExtDesc != null && legacyExtDesc.trim().isNotEmpty)) {
        walletExists = true;
      }
    }

    final prefs = await ref.read(sharedPreferencesProvider.future);
    final rawBackupConfirmed = prefs.getBool(_backupConfirmedKey) ?? false;

    // Watch-only wallets do not have a seed phrase to back up
    final activeWallet =
        registry.getActiveWallet() ?? registry.getWallets().firstOrNull;
    final isWatchOnly = activeWallet?.type == WalletType.watchOnly;
    final backupConfirmed = isWatchOnly || rawBackupConfirmed;

    final destination = !walletExists
        ? AppStartDestination.onboarding
        : backupConfirmed
        ? AppStartDestination.mainShell
        : AppStartDestination.needsBackup;

    return AppStartState(
      destination: destination,
      walletExists: walletExists,
      backupConfirmed: backupConfirmed,
    );
  }
}

final appStartControllerProvider =
    AsyncNotifierProvider<AppStartController, AppStartState>(
      AppStartController.new,
    );

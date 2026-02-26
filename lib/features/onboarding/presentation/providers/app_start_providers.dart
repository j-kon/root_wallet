import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
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
    final walletExists = await ref.read(hasWalletUsecaseProvider).call();
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final backupConfirmed = prefs.getBool(_backupConfirmedKey) ?? false;

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

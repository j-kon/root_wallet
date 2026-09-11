import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

class BackupReminderController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final activeId = await ref.watch(activeWalletIdProvider.future);
    if (activeId == null) return true;

    // Resolve active wallet record from registry
    final registry = await ref.watch(walletRegistryProvider.future);
    final wallet = registry.getWallet(activeId);
    if (wallet == null) return false;

    // Watch-only wallets do not have a seed phrase to back up
    if (wallet.isWatchOnly) {
      return true;
    }

    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final scopedKey = WalletStorageKeys.backupConfirmedFor(activeId);
    final scopedVal = prefs.getBool(scopedKey);
    if (scopedVal != null) {
      return scopedVal;
    }

    // Compatibility check for existing modern users from PR #19 feature branch (Req 13)
    final signingWallets =
        registry.getWallets().where((w) => !w.isWatchOnly).toList();
    if (signingWallets.length == 1 && signingWallets.first.id == activeId) {
      final legacyVal = prefs.getBool('settings.backup_confirmed');
      if (legacyVal != null) {
        await prefs.setBool(scopedKey, legacyVal);
        return legacyVal;
      }
    }

    return false; // Unknown signing wallet backup state fails safe to false
  }

  Future<void> confirmBackup([String? targetWalletId]) async {
    final activeId = ref.read(activeWalletIdProvider).valueOrNull;
    final walletId = targetWalletId ?? activeId;
    if (walletId == null) return;
    WalletRecord.validateWalletId(walletId);

    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(WalletStorageKeys.backupConfirmedFor(walletId), true);

    if (activeId == walletId) {
      state = const AsyncData(true);
    }
  }

  Future<void> clearBackupConfirmation([String? targetWalletId]) async {
    final activeId = ref.read(activeWalletIdProvider).valueOrNull;
    final walletId = targetWalletId ?? activeId;
    if (walletId == null) return;
    WalletRecord.validateWalletId(walletId);

    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(WalletStorageKeys.backupConfirmedFor(walletId), false);

    if (activeId == walletId) {
      state = const AsyncData(false);
    }
  }
}

final backupReminderProvider =
    AsyncNotifierProvider<BackupReminderController, bool>(
      BackupReminderController.new,
    );

class BalancePrivacyController extends AsyncNotifier<bool> {
  static const _hideBalancesKey = 'settings.hide_balances';

  @override
  Future<bool> build() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    return prefs.getBool(_hideBalancesKey) ?? false;
  }

  Future<void> setHidden(bool hidden) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_hideBalancesKey, hidden);
    state = AsyncData(hidden);
  }

  Future<void> clear() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.remove(_hideBalancesKey);
    state = const AsyncData(false);
  }
}

final balancePrivacyProvider =
    AsyncNotifierProvider<BalancePrivacyController, bool>(
      BalancePrivacyController.new,
    );

enum AutoLockOption { immediate, after30Seconds }

extension AutoLockOptionX on AutoLockOption {
  String get prefsValue {
    return switch (this) {
      AutoLockOption.immediate => 'immediate',
      AutoLockOption.after30Seconds => 'after_30_seconds',
    };
  }

  String get label {
    return switch (this) {
      AutoLockOption.immediate => 'Immediately',
      AutoLockOption.after30Seconds => 'After 30s',
    };
  }

  static AutoLockOption fromPrefs(String? value) {
    return switch (value) {
      'after_30_seconds' => AutoLockOption.after30Seconds,
      _ => AutoLockOption.immediate,
    };
  }
}

class AppLockState {
  const AppLockState({
    required this.isLockEnabled,
    required this.isBiometricsEnabled,
    required this.isBiometricAvailable,
    required this.autoLockOption,
    required this.hasPin,
    required this.isLocked,
    required this.isBusy,
    required this.failedAttempts,
    this.cooldownEndsAt,
    this.message,
  });

  final bool isLockEnabled;
  final bool isBiometricsEnabled;
  final bool isBiometricAvailable;
  final AutoLockOption autoLockOption;
  final bool hasPin;
  final bool isLocked;
  final bool isBusy;
  final int failedAttempts;
  final DateTime? cooldownEndsAt;
  final String? message;

  bool get isInCooldown {
    final end = cooldownEndsAt;
    return end != null && DateTime.now().isBefore(end);
  }

  int get cooldownRemainingSeconds {
    final end = cooldownEndsAt;
    if (end == null) {
      return 0;
    }
    final remaining = end.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  AppLockState copyWith({
    bool? isLockEnabled,
    bool? isBiometricsEnabled,
    bool? isBiometricAvailable,
    AutoLockOption? autoLockOption,
    bool? hasPin,
    bool? isLocked,
    bool? isBusy,
    int? failedAttempts,
    DateTime? cooldownEndsAt,
    String? message,
    bool clearCooldown = false,
    bool clearMessage = false,
  }) {
    return AppLockState(
      isLockEnabled: isLockEnabled ?? this.isLockEnabled,
      isBiometricsEnabled: isBiometricsEnabled ?? this.isBiometricsEnabled,
      isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
      autoLockOption: autoLockOption ?? this.autoLockOption,
      hasPin: hasPin ?? this.hasPin,
      isLocked: isLocked ?? this.isLocked,
      isBusy: isBusy ?? this.isBusy,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      cooldownEndsAt: clearCooldown
          ? null
          : (cooldownEndsAt ?? this.cooldownEndsAt),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

class LockController extends AsyncNotifier<AppLockState> {
  static const _lockEnabledKey = 'security.lock_enabled';
  static const _biometricsEnabledKey = 'security.biometrics_enabled';
  static const _autoLockOptionKey = 'security.auto_lock_option';

  DateTime? _backgroundedAt;
  Timer? _cooldownTicker;

  @override
  Future<AppLockState> build() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final lockService = ref.read(lockServiceProvider);

    final isLockEnabled = prefs.getBool(_lockEnabledKey) ?? false;
    final isBiometricsEnabled = prefs.getBool(_biometricsEnabledKey) ?? false;
    final autoLockOption = AutoLockOptionX.fromPrefs(
      prefs.getString(_autoLockOptionKey),
    );
    final hasPin = await lockService.hasPin();
    final isBiometricAvailable = await lockService.isBiometricAvailable();
    final failedAttempts = await lockService.getFailedAttempts();
    final remainingCooldownSeconds =
        await lockService.getRemainingCooldownSeconds();

    DateTime? cooldownEndsAt;
    if (remainingCooldownSeconds > 0) {
      cooldownEndsAt =
          DateTime.now().add(Duration(seconds: remainingCooldownSeconds));
    }

    ref.onDispose(() {
      _cooldownTicker?.cancel();
    });

    if (cooldownEndsAt != null) {
      _startCooldownTicker(cooldownEndsAt);
    }

    return AppLockState(
      isLockEnabled: isLockEnabled,
      isBiometricsEnabled: isBiometricsEnabled,
      isBiometricAvailable: isBiometricAvailable,
      autoLockOption: autoLockOption,
      hasPin: hasPin,
      isLocked: isLockEnabled && hasPin,
      isBusy: false,
      failedAttempts: failedAttempts,
      cooldownEndsAt: cooldownEndsAt,
      message: cooldownEndsAt != null
          ? 'Lockout active. Try again in ${remainingCooldownSeconds}s.'
          : null,
    );
  }

  Future<bool> authenticateWithBiometrics({
    String reason = 'Unlock Root Wallet',
  }) async {
    final current = state.valueOrNull;
    if (current == null || !current.isBiometricAvailable) {
      return false;
    }

    if (!current.isBiometricsEnabled) {
      return false;
    }

    state = AsyncData(current.copyWith(isBusy: true, clearMessage: true));

    final lockService = ref.read(lockServiceProvider);
    final ok = await lockService.authenticateBiometric(reason: reason);
    final next = state.valueOrNull;
    if (next == null) {
      return ok;
    }

    if (ok) {
      _backgroundedAt = null;
      state = AsyncData(
        next.copyWith(
          isBusy: false,
          isLocked: false,
          failedAttempts: 0,
          clearCooldown: true,
          clearMessage: true,
        ),
      );
      return true;
    }

    state = AsyncData(next.copyWith(isBusy: false));
    return false;
  }

  void lockNow() {
    final current = state.valueOrNull;
    if (current == null || !current.isLockEnabled || !current.hasPin) {
      return;
    }

    ref.read(bdkWalletServiceProvider).setDecoyActive(false);
    state = AsyncData(current.copyWith(isLocked: true, clearMessage: true));
  }

  void onAppBackgrounded() {
    // Avoid recording background time during active biometric prompts
    final current = state.valueOrNull;
    if (current?.isBusy ?? false) {
      return;
    }
    _backgroundedAt = DateTime.now();
  }

  void onAppResumed() {
    final current = state.valueOrNull;
    if (current == null ||
        !current.isLockEnabled ||
        !current.hasPin ||
        current.isBusy) {
      return;
    }

    final shouldLock = switch (current.autoLockOption) {
      AutoLockOption.immediate => true,
      AutoLockOption.after30Seconds =>
        _backgroundedAt != null &&
            DateTime.now().difference(_backgroundedAt!) >=
                const Duration(seconds: 30),
    };

    if (shouldLock) {
      ref.read(bdkWalletServiceProvider).setDecoyActive(false);
      state = AsyncData(current.copyWith(isLocked: true, clearMessage: true));
    }
  }

  Future<bool> requireReauth() async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    if (current.isBiometricsEnabled && current.isBiometricAvailable) {
      return authenticateWithBiometrics(reason: 'Re-authenticate to continue');
    }

    return false;
  }

  /// Requires explicit authorization for sensitive actions (such as PSBT signing).
  ///
  /// Fails closed:
  /// - Sensitive actions fail closed when no approved authentication
  ///   credential is configured.
  /// - If biometrics are configured and available: attempts biometric re-auth.
  /// - If biometrics are unavailable, disabled, cancelled, or fail:
  ///   falls back to PIN verification via [promptPin] and [verifyPin].
  /// - If no PIN is configured, returns `false` without invoking [promptPin].
  /// - If neither approved authentication method succeeds: returns `false`.
  Future<bool> requireSensitiveActionAuthentication({
    required Future<String?> Function() promptPin,
    String biometricReason = 'Authorize sensitive action',
    void Function()? onNoPinConfigured,
  }) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    if (current.isInCooldown) {
      return false;
    }

    // A. Attempt biometrics if configured & available
    if (current.isBiometricsEnabled && current.isBiometricAvailable) {
      try {
        final bioOk = await authenticateWithBiometrics(reason: biometricReason);
        if (bioOk) {
          return true;
        }
      } catch (_) {
        // Biometric error, fallback to secure PIN path below
      }
    }

    // B. If no PIN is configured, fail closed immediately without prompting PIN
    if (!current.hasPin) {
      onNoPinConfigured?.call();
      return false;
    }

    // C. Provide existing secure PIN verification path
    try {
      final pin = await promptPin();
      if (pin == null || pin.isEmpty) {
        return false;
      }
      return await verifyPin(pin);
    } catch (_) {
      return false;
    }
  }

  Future<void> setAutoLockOption(AutoLockOption option) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_autoLockOptionKey, option.prefsValue);

    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(autoLockOption: option));
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    if (enabled && !current.isBiometricAvailable) {
      return;
    }

    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_biometricsEnabledKey, enabled);

    state = AsyncData(current.copyWith(isBiometricsEnabled: enabled));
  }

  Future<bool> setLockEnabled(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    if (enabled && !current.hasPin) {
      state = AsyncData(
        current.copyWith(
          message: 'Set a 6-digit PIN before enabling app lock.',
        ),
      );
      return false;
    }

    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_lockEnabledKey, enabled);

    state = AsyncData(
      current.copyWith(
        isLockEnabled: enabled,
        isLocked: enabled ? current.isLocked : false,
        clearMessage: true,
      ),
    );
    return true;
  }

  Future<void> setPin(String pin) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(isBusy: true, clearMessage: true));

    final lockService = ref.read(lockServiceProvider);
    await lockService.setPin(pin);

    final refreshed = state.valueOrNull;
    if (refreshed == null) {
      return;
    }

    state = AsyncData(
      refreshed.copyWith(
        hasPin: true,
        isBusy: false,
        failedAttempts: 0,
        clearCooldown: true,
      ),
    );
  }

  Future<bool> verifyPin(String pin) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    if (current.isInCooldown) {
      return false;
    }

    state = AsyncData(current.copyWith(isBusy: true, clearMessage: true));

    final lockService = ref.read(lockServiceProvider);

    // Check if decoy PIN matches
    final hasDecoy = await lockService.hasDecoyPin();
    if (hasDecoy) {
      final isDecoy = await lockService.verifyDecoyPin(pin);
      if (isDecoy) {
        await lockService.resetLockout();
        ref.read(bdkWalletServiceProvider).setDecoyActive(true);
        _cooldownTicker?.cancel();
        _backgroundedAt = null;
        state = AsyncData(
          current.copyWith(
            isBusy: false,
            isLocked: false,
            failedAttempts: 0,
            clearCooldown: true,
            clearMessage: true,
          ),
        );
        ref.read(selectedUtxosProvider.notifier).clear();
        ref.invalidate(lockedUtxosProvider);
        ref.invalidate(walletHomeControllerProvider);
        ref.invalidate(walletDiagnosticsControllerProvider);
        ref.invalidate(walletUtxosProvider);
        return true;
      }
    }

    final ok = await lockService.verifyPin(pin);

    final next = state.valueOrNull;
    if (next == null) {
      return ok;
    }

    if (ok) {
      await lockService.resetLockout();
      ref.read(bdkWalletServiceProvider).setDecoyActive(false);
      _cooldownTicker?.cancel();
      _backgroundedAt = null;
      state = AsyncData(
        next.copyWith(
          isBusy: false,
          isLocked: false,
          failedAttempts: 0,
          clearCooldown: true,
          clearMessage: true,
        ),
      );
      ref.read(selectedUtxosProvider.notifier).clear();
      ref.invalidate(lockedUtxosProvider);
      ref.invalidate(walletHomeControllerProvider);
      ref.invalidate(walletDiagnosticsControllerProvider);
      ref.invalidate(walletUtxosProvider);
      return true;
    }

    final attempts = await lockService.recordFailedAttempt();
    final delaySeconds = lockService.delayForAttempts(attempts);

    if (delaySeconds > 0) {
      final cooldownEnd = DateTime.now().add(Duration(seconds: delaySeconds));
      _startCooldownTicker(cooldownEnd);
      final delayText = delaySeconds >= 60
          ? '${(delaySeconds / 60).round()}m'
          : '${delaySeconds}s';
      state = AsyncData(
        next.copyWith(
          isBusy: false,
          failedAttempts: attempts,
          cooldownEndsAt: cooldownEnd,
          message: 'Too many attempts. Try again in $delayText.',
        ),
      );
      return false;
    }

    final left = 5 - attempts;
    state = AsyncData(
      next.copyWith(
        isBusy: false,
        failedAttempts: attempts,
        message: 'Incorrect PIN. $left attempt${left == 1 ? '' : 's'} left.',
      ),
    );
    return false;
  }

  void _startCooldownTicker(DateTime cooldownEnd) {
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state.valueOrNull;
      if (current == null) {
        timer.cancel();
        return;
      }

      if (DateTime.now().isAfter(cooldownEnd)) {
        timer.cancel();
        state = AsyncData(
          current.copyWith(
            clearCooldown: true,
            clearMessage: true,
          ),
        );
        return;
      }

      state = AsyncData(current.copyWith(cooldownEndsAt: cooldownEnd));
    });
  }
}

final lockControllerProvider =
    AsyncNotifierProvider<LockController, AppLockState>(LockController.new);

class CustomNodeController extends AsyncNotifier<String?> {
  static const _key = 'settings.custom_electrum_url';

  @override
  Future<String?> build() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    return prefs.getString(_key);
  }

  Future<void> setNodeUrl(String? url) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_key);
      state = const AsyncData(null);
    } else {
      final normalized = _normalizeUrl(url);
      await prefs.setString(_key, normalized);
      state = AsyncData(normalized);
    }
  }

  String _normalizeUrl(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty || uri.port == 0) {
      throw const FormatException(
        'Enter a valid Electrum URL (e.g. tcp://host:port).',
      );
    }
    if (uri.scheme != 'tcp' && uri.scheme != 'ssl') {
      throw const FormatException(
        'Only tcp:// or ssl:// protocols are supported.',
      );
    }
    return trimmed;
  }
}

final customNodeProvider = AsyncNotifierProvider<CustomNodeController, String?>(
  CustomNodeController.new,
);

class DecoyPinController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final lockService = ref.read(lockServiceProvider);
    return lockService.hasDecoyPin();
  }

  Future<void> setDecoyPin(String pin) async {
    state = const AsyncLoading();
    final lockService = ref.read(lockServiceProvider);
    await lockService.setDecoyPin(pin);
    ref.invalidateSelf();
  }

  Future<void> clearDecoyPin() async {
    state = const AsyncLoading();
    final lockService = ref.read(lockServiceProvider);
    await lockService.clearDecoyPin();
    ref.invalidateSelf();
  }
}

final decoyPinProvider = AsyncNotifierProvider<DecoyPinController, bool>(
  DecoyPinController.new,
);

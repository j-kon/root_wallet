import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';

class BackupReminderController extends AsyncNotifier<bool> {
  static const _backupConfirmedKey = 'settings.backup_confirmed';

  @override
  Future<bool> build() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    return prefs.getBool(_backupConfirmedKey) ?? false;
  }

  Future<void> confirmBackup() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_backupConfirmedKey, true);
    state = const AsyncData(true);
  }

  Future<void> clearBackupConfirmation() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_backupConfirmedKey, false);
    state = const AsyncData(false);
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

    ref.onDispose(() {
      _cooldownTicker?.cancel();
    });

    return AppLockState(
      isLockEnabled: isLockEnabled,
      isBiometricsEnabled: isBiometricsEnabled,
      isBiometricAvailable: isBiometricAvailable,
      autoLockOption: autoLockOption,
      hasPin: hasPin,
      isLocked: isLockEnabled && hasPin,
      isBusy: false,
      failedAttempts: 0,
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

    state = AsyncData(current.copyWith(isLocked: true, clearMessage: true));
  }

  void onAppBackgrounded() {
    _backgroundedAt = DateTime.now();
  }

  void onAppResumed() {
    final current = state.valueOrNull;
    if (current == null || !current.isLockEnabled || !current.hasPin) {
      return;
    }

    final shouldLock = switch (current.autoLockOption) {
      AutoLockOption.immediate => true,
      AutoLockOption.after30Seconds =>
        _backgroundedAt == null ||
            DateTime.now().difference(_backgroundedAt!) >=
                const Duration(seconds: 30),
    };

    if (shouldLock) {
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
    final ok = await lockService.verifyPin(pin);

    final next = state.valueOrNull;
    if (next == null) {
      return ok;
    }

    if (ok) {
      _cooldownTicker?.cancel();
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

    final attempts = next.failedAttempts + 1;
    if (attempts >= 5) {
      final cooldownEnd = DateTime.now().add(const Duration(seconds: 15));
      _startCooldownTicker(cooldownEnd);
      state = AsyncData(
        next.copyWith(
          isBusy: false,
          failedAttempts: attempts,
          cooldownEndsAt: cooldownEnd,
          message: 'Too many attempts. Try again in 15s.',
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
            failedAttempts: 0,
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

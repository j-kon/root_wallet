import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/errors/error_mapper.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/app_start_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_snapshot_cache.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_seed_service.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';

final onboardingWalletSeedServiceProvider = Provider<WalletSeedService>(
  (ref) => WalletSeedService(
    secureStorage: ref.watch(secureStorageProvider),
    walletStoragePathLoader: () => ref.read(walletStoragePathProvider.future),
  ),
);

class OnboardingState {
  const OnboardingState({
    required this.isBusy,
    required this.challengeIndices,
    this.errorMessage,
    this.recoveryPhrase,
  });

  factory OnboardingState.initial() {
    return const OnboardingState(isBusy: false, challengeIndices: []);
  }

  final bool isBusy;
  final List<int> challengeIndices;
  final String? errorMessage;
  final String? recoveryPhrase;

  OnboardingState copyWith({
    bool? isBusy,
    List<int>? challengeIndices,
    String? errorMessage,
    String? recoveryPhrase,
    bool clearError = false,
    bool clearRecoveryPhrase = false,
  }) {
    return OnboardingState(
      isBusy: isBusy ?? this.isBusy,
      challengeIndices: challengeIndices ?? this.challengeIndices,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      recoveryPhrase: clearRecoveryPhrase
          ? null
          : (recoveryPhrase ?? this.recoveryPhrase),
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController(this._ref) : super(OnboardingState.initial());

  final Ref _ref;
  final Random _random = Random.secure();

  Future<bool> createWallet({
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final identity = await _ref
          .read(onboardingWalletSeedServiceProvider)
          .createWallet(scriptType: scriptType);
      _resetLocalWalletSessionState();
      state = state.copyWith(
        isBusy: false,
        challengeIndices: const [],
        recoveryPhrase: identity.recoveryPhrase,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: mapErrorToMessage(
          error,
          context: ErrorContext.general,
          includeDebugDetails: !_ref.read(appEnvProvider).isProduction,
        ),
      );
      return false;
    }
  }

  Future<bool> restoreWallet(
    String mnemonic, {
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final identity = await _ref
          .read(onboardingWalletSeedServiceProvider)
          .restoreWallet(mnemonic: mnemonic, scriptType: scriptType);
      _resetLocalWalletSessionState();
      state = state.copyWith(
        isBusy: false,
        challengeIndices: const [],
        recoveryPhrase: identity.recoveryPhrase,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: mapErrorToMessage(
          error,
          context: ErrorContext.general,
          includeDebugDetails: !_ref.read(appEnvProvider).isProduction,
        ),
      );
      return false;
    }
  }

  Future<void> prepareSeedChallenge() async {
    if (state.challengeIndices.isNotEmpty) {
      return;
    }
    try {
      await _prepareChallenge();
    } catch (error) {
      state = state.copyWith(
        errorMessage: mapErrorToMessage(
          error,
          context: ErrorContext.general,
          includeDebugDetails: !_ref.read(appEnvProvider).isProduction,
        ),
      );
    }
  }

  Future<bool> confirmBackup(Map<int, String> answers) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final phrase =
          state.recoveryPhrase ??
          await _ref
              .read(secureStorageProvider)
              .read(key: WalletStorageKeys.mnemonic);
      if (phrase == null || phrase.trim().isEmpty) {
        throw StateError('Recovery phrase is not available.');
      }
      final words = _normalizeWords(phrase);
      final requiredIndices = state.challengeIndices.isEmpty
          ? _randomIndices(words.length)
          : state.challengeIndices;

      for (final index in requiredIndices) {
        final expected = words[index - 1].toLowerCase();
        final actual = answers[index]?.trim().toLowerCase();
        if (actual == null || actual.isEmpty || actual != expected) {
          state = state.copyWith(
            isBusy: false,
            errorMessage: 'Seed words do not match. Please try again.',
          );
          return false;
        }
      }

      await _ref.read(backupReminderProvider.notifier).confirmBackup();
      _ref.invalidate(appStartControllerProvider);
      state = state.copyWith(
        isBusy: false,
        clearRecoveryPhrase: true,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: mapErrorToMessage(
          error,
          context: ErrorContext.general,
          includeDebugDetails: !_ref.read(appEnvProvider).isProduction,
        ),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void _resetLocalWalletSessionState() {
    unawaited(_clearLocalWalletSessionState().catchError((Object _) {}));
    _ref.invalidate(appStartControllerProvider);
  }

  Future<void> _clearLocalWalletSessionState() async {
    await _ref.read(backupReminderProvider.notifier).clearBackupConfirmation();
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await WalletSnapshotCache(prefs).clear();
    await WalletLabelStore(prefs).clear();
  }

  Future<void> _prepareChallenge() async {
    final phrase =
        state.recoveryPhrase ??
        await _ref
            .read(secureStorageProvider)
            .read(key: WalletStorageKeys.mnemonic);
    if (phrase == null || phrase.trim().isEmpty) {
      throw StateError('Recovery phrase is not available.');
    }
    final words = _normalizeWords(phrase);
    state = state.copyWith(
      challengeIndices: _randomIndices(words.length),
      clearError: true,
    );
  }

  List<String> _normalizeWords(String phrase) {
    return phrase
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  List<int> _randomIndices(int wordCount) {
    final pool = List<int>.generate(wordCount, (index) => index + 1);
    pool.shuffle(_random);
    final picks = pool.take(min(3, wordCount)).toList()..sort();
    return picks;
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>(
      (ref) => OnboardingController(ref),
    );

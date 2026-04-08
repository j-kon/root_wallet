import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/errors/error_mapper.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/app_start_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

class OnboardingState {
  const OnboardingState({
    required this.isBusy,
    required this.challengeIndices,
    this.errorMessage,
  });

  factory OnboardingState.initial() {
    return const OnboardingState(isBusy: false, challengeIndices: []);
  }

  final bool isBusy;
  final List<int> challengeIndices;
  final String? errorMessage;

  OnboardingState copyWith({
    bool? isBusy,
    List<int>? challengeIndices,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OnboardingState(
      isBusy: isBusy ?? this.isBusy,
      challengeIndices: challengeIndices ?? this.challengeIndices,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController(this._ref) : super(OnboardingState.initial());

  final Ref _ref;
  final Random _random = Random.secure();

  Future<bool> createWallet() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _ref.read(createWalletUsecaseProvider).call();
      await _ref.read(backupReminderProvider.notifier).clearBackupConfirmation();
      _ref.invalidate(appStartControllerProvider);
      state = state.copyWith(
        isBusy: false,
        challengeIndices: const [],
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

  Future<bool> restoreWallet(String mnemonic) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _ref.read(restoreWalletUsecaseProvider).call(mnemonic);
      await _ref.read(backupReminderProvider.notifier).clearBackupConfirmation();
      _ref.invalidate(appStartControllerProvider);
      state = state.copyWith(
        isBusy: false,
        challengeIndices: const [],
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
      final phrase = await _ref.read(getRecoveryPhraseUsecaseProvider).call();
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
      state = state.copyWith(isBusy: false, clearError: true);
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

  Future<void> _prepareChallenge() async {
    final phrase = await _ref.read(getRecoveryPhraseUsecaseProvider).call();
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

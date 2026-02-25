import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/features/send/data/datasources/broadcast_datasource.dart';
import 'package:root_wallet/features/send/data/datasources/mempool_fee_datasource.dart';
import 'package:root_wallet/features/send/data/repositories/send_repository_impl.dart';
import 'package:root_wallet/features/send/domain/entities/fee_rate.dart';
import 'package:root_wallet/features/send/domain/entities/send_request.dart';
import 'package:root_wallet/features/send/domain/repositories/send_repository.dart';
import 'package:root_wallet/features/send/domain/usecases/broadcast_tx.dart';
import 'package:root_wallet/features/send/domain/usecases/build_tx.dart';
import 'package:root_wallet/features/send/domain/usecases/sign_tx.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

final mempoolFeeDatasourceProvider = Provider<MempoolFeeDatasource>(
  (ref) => MempoolFeeDatasource(),
);

final broadcastDatasourceProvider = Provider<BroadcastDatasource>(
  (ref) => BroadcastDatasource(),
);

final sendRepositoryProvider = Provider<SendRepository>((ref) {
  return SendRepositoryImpl(
    broadcastDatasource: ref.watch(broadcastDatasourceProvider),
  );
});

final buildTxUsecaseProvider = Provider<BuildTx>(
  (ref) => BuildTx(ref.watch(sendRepositoryProvider)),
);

final signTxUsecaseProvider = Provider<SignTx>(
  (ref) => SignTx(ref.watch(sendRepositoryProvider)),
);

final broadcastTxUsecaseProvider = Provider<BroadcastTx>(
  (ref) => BroadcastTx(ref.watch(sendRepositoryProvider)),
);

final suggestedFeeProvider = FutureProvider<FeeRate>((ref) {
  return ref.watch(mempoolFeeDatasourceProvider).recommendedFee();
});

enum FeePreset { slow, standard, fast }

extension FeePresetX on FeePreset {
  String get label {
    return switch (this) {
      FeePreset.slow => 'Slow',
      FeePreset.standard => 'Standard',
      FeePreset.fast => 'Fast',
    };
  }
}

class SendFormState {
  const SendFormState({
    required this.address,
    required this.amountBtcText,
    required this.feeRate,
    required this.feePreset,
    this.builtPsbt,
    this.errorMessage,
    this.isSubmitting = false,
  });

  factory SendFormState.initial() {
    return const SendFormState(
      address: '',
      amountBtcText: '',
      feeRate: FeeRate(satsPerVByte: 1),
      feePreset: FeePreset.standard,
    );
  }

  final String address;
  final String amountBtcText;
  final FeeRate feeRate;
  final FeePreset feePreset;
  final String? builtPsbt;
  final String? errorMessage;
  final bool isSubmitting;

  SendFormState copyWith({
    String? address,
    String? amountBtcText,
    FeeRate? feeRate,
    FeePreset? feePreset,
    String? builtPsbt,
    String? errorMessage,
    bool? isSubmitting,
    bool clearBuiltPsbt = false,
    bool clearError = false,
  }) {
    return SendFormState(
      address: address ?? this.address,
      amountBtcText: amountBtcText ?? this.amountBtcText,
      feeRate: feeRate ?? this.feeRate,
      feePreset: feePreset ?? this.feePreset,
      builtPsbt: clearBuiltPsbt ? null : (builtPsbt ?? this.builtPsbt),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  double? get amountBtc {
    return double.tryParse(amountBtcText.trim());
  }

  int? get amountSats {
    final btc = amountBtc;
    if (btc == null || btc <= 0) {
      return null;
    }

    return (btc * AppConstants.satoshisPerBitcoin).round();
  }

  int get estimatedFeeSats => feeRate.satsPerVByte * 140;

  int? get totalSats {
    final sats = amountSats;
    if (sats == null) {
      return null;
    }
    return sats + estimatedFeeSats;
  }

  bool get canSubmit => address.trim().isNotEmpty && amountSats != null;
}

class SendFormNotifier extends StateNotifier<SendFormState> {
  SendFormNotifier(this._ref) : super(SendFormState.initial()) {
    _primeFee();
  }

  final Ref _ref;

  void resetAfterSuccess() {
    state = SendFormState.initial().copyWith(
      feeRate: state.feeRate,
      feePreset: state.feePreset,
      clearError: true,
      clearBuiltPsbt: true,
    );
  }

  void setAddress(String value) {
    state = state.copyWith(address: value, clearError: true);
  }

  void setAmountBtc(String value) {
    state = state.copyWith(amountBtcText: value, clearError: true);
  }

  void setFeePreset(FeePreset preset, int suggestedRate) {
    final satsPerVByte = _rateForPreset(preset, suggestedRate);
    state = state.copyWith(
      feePreset: preset,
      feeRate: FeeRate(satsPerVByte: satsPerVByte),
      clearError: true,
    );
  }

  Future<bool> buildTransaction() async {
    final address = state.address.trim();
    if (!_isValidBitcoinAddress(address)) {
      state = state.copyWith(errorMessage: 'Invalid address');
      return false;
    }

    final amountSats = state.amountSats;
    if (amountSats == null || amountSats <= 0) {
      state = state.copyWith(errorMessage: 'Enter a valid amount');
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearBuiltPsbt: true,
    );

    try {
      final balance = await _ref.read(getBalanceUsecaseProvider).call();
      final totalToSpend = amountSats + state.estimatedFeeSats;
      if (totalToSpend > balance.totalSats) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Insufficient balance',
        );
        return false;
      }

      final psbt = await _ref
          .read(buildTxUsecaseProvider)
          .call(
            SendRequest(
              address: address,
              amountSats: amountSats,
              feeRate: state.feeRate,
            ),
          );
      state = state.copyWith(isSubmitting: false, builtPsbt: psbt);
      return true;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Network error. Try again.',
      );
      return false;
    }
  }

  Future<String?> signAndBroadcast() async {
    final psbt = state.builtPsbt;
    if (psbt == null) {
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final signed = await _ref.read(signTxUsecaseProvider).call(psbt);
      final txId = await _ref.read(broadcastTxUsecaseProvider).call(signed);
      state = state.copyWith(isSubmitting: false);
      return txId;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Network error. Try again.',
      );
      return null;
    }
  }

  Future<void> _primeFee() async {
    final fee = await _ref.read(suggestedFeeProvider.future);
    setFeePreset(FeePreset.standard, fee.satsPerVByte);
  }

  int _rateForPreset(FeePreset preset, int suggestedRate) {
    return switch (preset) {
      FeePreset.slow => max(1, suggestedRate - 2),
      FeePreset.standard => max(1, suggestedRate),
      FeePreset.fast => max(1, suggestedRate + 4),
    };
  }

  bool _isValidBitcoinAddress(String address) {
    if (address.isEmpty) {
      return false;
    }

    final normalized = address.toLowerCase();
    if (normalized.startsWith('bc1') ||
        normalized.startsWith('tb1') ||
        normalized.startsWith('bcrt1')) {
      return address.length >= 14;
    }

    final legacyPattern = RegExp(r'^[13mn2][a-km-zA-HJ-NP-Z1-9]{25,34}$');
    return legacyPattern.hasMatch(address);
  }
}

final sendFormProvider = StateNotifierProvider<SendFormNotifier, SendFormState>(
  (ref) => SendFormNotifier(ref),
);

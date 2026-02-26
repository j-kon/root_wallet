import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/core/errors/error_mapper.dart';
import 'package:root_wallet/features/send/data/datasources/broadcast_datasource.dart';
import 'package:root_wallet/features/send/data/datasources/mempool_fee_datasource.dart';
import 'package:root_wallet/features/send/data/repositories/send_repository_impl.dart';
import 'package:root_wallet/features/send/domain/entities/fee_rate.dart';
import 'package:root_wallet/features/send/domain/entities/send_request.dart';
import 'package:root_wallet/features/send/domain/repositories/send_repository.dart';
import 'package:root_wallet/features/send/domain/usecases/broadcast_tx.dart';
import 'package:root_wallet/features/send/domain/usecases/build_tx.dart';
import 'package:root_wallet/features/send/domain/usecases/sign_tx.dart';
import 'package:root_wallet/features/send/presentation/models/send_draft.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

final mempoolFeeDatasourceProvider = Provider<MempoolFeeDatasource>(
  (ref) => MempoolFeeDatasource(
    walletDatasource: ref.watch(bdkWalletDatasourceProvider),
  ),
);

final broadcastDatasourceProvider = Provider<BroadcastDatasource>(
  (ref) => BroadcastDatasource(
    walletDatasource: ref.watch(bdkWalletDatasourceProvider),
  ),
);

final sendRepositoryProvider = Provider<SendRepository>((ref) {
  return SendRepositoryImpl(
    broadcastDatasource: ref.watch(broadcastDatasourceProvider),
    walletDatasource: ref.watch(bdkWalletDatasourceProvider),
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

class SendState {
  const SendState({
    required this.draft,
    this.errorMessage,
    this.isSending = false,
    this.lastTxId,
  });

  factory SendState.initial() {
    return SendState(draft: SendDraft.initial());
  }

  final SendDraft draft;
  final String? errorMessage;
  final bool isSending;
  final String? lastTxId;

  SendState copyWith({
    SendDraft? draft,
    String? errorMessage,
    bool? isSending,
    String? lastTxId,
    bool clearError = false,
    bool clearTxId = false,
  }) {
    return SendState(
      draft: draft ?? this.draft,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSending: isSending ?? this.isSending,
      lastTxId: clearTxId ? null : (lastTxId ?? this.lastTxId),
    );
  }

  int? get amountSats => draft.amountSats;

  int get estimatedFeeSats => draft.feeRate.satsPerVByte * 140;

  int? get totalSats {
    final sats = amountSats;
    if (sats == null) {
      return null;
    }
    return sats + estimatedFeeSats;
  }

  bool get canReview => draft.canReview;
}

class SendController extends StateNotifier<SendState> {
  SendController(this._ref) : super(SendState.initial()) {
    _primeFee();
  }

  final Ref _ref;

  void setAddress(String value) {
    state = state.copyWith(
      draft: state.draft.copyWith(address: value),
      clearError: true,
      clearTxId: true,
    );
  }

  void setAmountBtc(String value) {
    state = state.copyWith(
      draft: state.draft.copyWith(amountBtcText: value),
      clearError: true,
      clearTxId: true,
    );
  }

  void setFeePreset(FeePreset preset, int suggestedRate) {
    final satsPerVByte = _rateForPreset(preset, suggestedRate);
    state = state.copyWith(
      draft: state.draft.copyWith(
        feePreset: preset,
        feeRate: FeeRate(satsPerVByte: satsPerVByte),
      ),
      clearError: true,
    );
  }

  bool validateForReview() {
    if (!state.draft.hasValidAddress) {
      state = state.copyWith(errorMessage: 'Invalid address');
      return false;
    }

    final amountSats = state.amountSats;
    if (amountSats == null || amountSats <= 0) {
      state = state.copyWith(errorMessage: 'Enter a valid amount');
      return false;
    }

    state = state.copyWith(clearError: true);
    return true;
  }

  Future<String?> send() async {
    if (!validateForReview()) {
      return null;
    }

    final amountSats = state.amountSats!;
    final address = state.draft.address.trim();

    state = state.copyWith(isSending: true, clearError: true, clearTxId: true);

    try {
      final balance = await _ref.read(getBalanceUsecaseProvider).call();
      final totalToSpend = amountSats + state.estimatedFeeSats;
      if (totalToSpend > balance.totalSats) {
        state = state.copyWith(
          isSending: false,
          errorMessage: 'Insufficient balance',
        );
        return null;
      }

      final psbt = await _ref
          .read(buildTxUsecaseProvider)
          .call(
            SendRequest(
              address: address,
              amountSats: amountSats,
              feeRate: state.draft.feeRate,
            ),
          );
      final signed = await _ref.read(signTxUsecaseProvider).call(psbt);
      final txId = await _ref.read(broadcastTxUsecaseProvider).call(signed);

      state = state.copyWith(isSending: false, lastTxId: txId);
      return txId;
    } catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: mapErrorToMessage(error, context: ErrorContext.broadcast),
      );
      return null;
    }
  }

  void resetAfterSuccess() {
    final feePreset = state.draft.feePreset;
    final feeRate = state.draft.feeRate;

    state = SendState.initial().copyWith(
      draft: SendDraft.initial().copyWith(
        feePreset: feePreset,
        feeRate: feeRate,
      ),
      clearError: true,
      clearTxId: true,
    );
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
}

final sendControllerProvider = StateNotifierProvider<SendController, SendState>(
  (ref) => SendController(ref),
);

final sendFormProvider = sendControllerProvider;

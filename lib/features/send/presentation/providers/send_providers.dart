import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/features/send/data/datasources/broadcast_datasource.dart';
import 'package:root_wallet/features/send/data/datasources/mempool_fee_datasource.dart';
import 'package:root_wallet/features/send/data/repositories/send_repository_impl.dart';
import 'package:root_wallet/features/send/domain/entities/fee_rate.dart';
import 'package:root_wallet/features/send/domain/entities/send_request.dart';
import 'package:root_wallet/features/send/domain/repositories/send_repository.dart';
import 'package:root_wallet/features/send/domain/usecases/broadcast_tx.dart';
import 'package:root_wallet/features/send/domain/usecases/build_tx.dart';
import 'package:root_wallet/features/send/domain/usecases/sign_tx.dart';

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

class SendFormState {
  const SendFormState({
    required this.address,
    required this.amountText,
    required this.feeRate,
    this.builtPsbt,
    this.errorMessage,
    this.isSubmitting = false,
  });

  factory SendFormState.initial() {
    return const SendFormState(
      address: '',
      amountText: '',
      feeRate: FeeRate(satsPerVByte: 1),
    );
  }

  final String address;
  final String amountText;
  final FeeRate feeRate;
  final String? builtPsbt;
  final String? errorMessage;
  final bool isSubmitting;

  SendFormState copyWith({
    String? address,
    String? amountText,
    FeeRate? feeRate,
    String? builtPsbt,
    String? errorMessage,
    bool? isSubmitting,
    bool clearBuiltPsbt = false,
    bool clearError = false,
  }) {
    return SendFormState(
      address: address ?? this.address,
      amountText: amountText ?? this.amountText,
      feeRate: feeRate ?? this.feeRate,
      builtPsbt: clearBuiltPsbt ? null : (builtPsbt ?? this.builtPsbt),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  bool get canSubmit => address.trim().isNotEmpty && _validSats > 0;

  int get _validSats => int.tryParse(amountText.trim()) ?? 0;
}

class SendFormNotifier extends StateNotifier<SendFormState> {
  SendFormNotifier(this._ref) : super(SendFormState.initial()) {
    _primeFee();
  }

  final Ref _ref;

  void setAddress(String value) {
    state = state.copyWith(address: value, clearError: true);
  }

  void setAmount(String value) {
    state = state.copyWith(amountText: value, clearError: true);
  }

  void setFeeRate(FeeRate feeRate) {
    state = state.copyWith(feeRate: feeRate, clearError: true);
  }

  Future<bool> buildTransaction() async {
    final amount = int.tryParse(state.amountText.trim());

    if (state.address.trim().isEmpty || amount == null || amount <= 0) {
      state = state.copyWith(errorMessage: 'Enter valid address and amount');
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearBuiltPsbt: true,
    );

    try {
      final psbt = await _ref
          .read(buildTxUsecaseProvider)
          .call(
            SendRequest(
              address: state.address.trim(),
              amountSats: amount,
              feeRate: state.feeRate,
            ),
          );
      state = state.copyWith(isSubmitting: false, builtPsbt: psbt);
      return true;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Could not build tx: $error',
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
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Broadcast failed: $error',
      );
      return null;
    }
  }

  Future<void> _primeFee() async {
    final fee = await _ref.read(suggestedFeeProvider.future);
    state = state.copyWith(feeRate: fee);
  }
}

final sendFormProvider = StateNotifierProvider<SendFormNotifier, SendFormState>(
  (ref) => SendFormNotifier(ref),
);

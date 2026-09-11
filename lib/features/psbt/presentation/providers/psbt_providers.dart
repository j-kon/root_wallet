import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/features/psbt/data/services/psbt_service.dart';
import 'package:root_wallet/features/psbt/domain/entities/psbt_details.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

final psbtServiceProvider = Provider<PsbtService>((ref) {
  return PsbtService(
    walletService: ref.watch(bdkWalletServiceProvider),
  );
});

final psbtInspectionProvider =
    FutureProvider.family<PsbtDetails, String>((ref, psbtBase64) async {
  final service = ref.watch(psbtServiceProvider);
  return service.inspectPsbt(psbtBase64);
});

class PsbtActionState {
  const PsbtActionState({
    this.isLoading = false,
    this.errorMessage,
    this.signingResult,
    this.broadcastTxid,
  });

  final bool isLoading;
  final String? errorMessage;
  final PsbtSigningResult? signingResult;
  final String? broadcastTxid;

  PsbtActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    PsbtSigningResult? signingResult,
    String? broadcastTxid,
  }) {
    return PsbtActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      signingResult: signingResult ?? this.signingResult,
      broadcastTxid: broadcastTxid ?? this.broadcastTxid,
    );
  }
}

class PsbtActionController extends StateNotifier<PsbtActionState> {
  PsbtActionController(this._psbtService) : super(const PsbtActionState());

  final PsbtService _psbtService;

  Future<PsbtSigningResult?> sign(String psbtBase64) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _psbtService.signPsbt(psbtBase64);
      state = state.copyWith(isLoading: false, signingResult: result);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<String?> broadcast(String psbtBase64) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final txid = await _psbtService.broadcastPsbt(psbtBase64);
      state = state.copyWith(isLoading: false, broadcastTxid: txid);
      return txid;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  void reset() {
    state = const PsbtActionState();
  }
}

final psbtActionControllerProvider =
    StateNotifierProvider<PsbtActionController, PsbtActionState>((ref) {
  return PsbtActionController(ref.watch(psbtServiceProvider));
});

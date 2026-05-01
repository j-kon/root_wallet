import 'package:root_wallet/features/send/domain/entities/fee_rate.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';

class MempoolFeeDatasource {
  MempoolFeeDatasource({required BdkWalletService walletService})
    : _walletService = walletService;

  final BdkWalletService _walletService;

  Future<FeeRate> recommendedFee() async {
    try {
      final sats = (await _walletService.estimateFeeSatPerVbyte(
        targetBlocks: 3,
      )).ceil();
      return FeeRate(satsPerVByte: sats < 1 ? 1 : sats);
    } catch (_) {
      return const FeeRate(satsPerVByte: 5);
    }
  }
}

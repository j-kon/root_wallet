import 'package:root_wallet/features/send/domain/entities/fee_rate.dart';

class MempoolFeeDatasource {
  Future<FeeRate> recommendedFee() async {
    return const FeeRate(satsPerVByte: 5);
  }
}

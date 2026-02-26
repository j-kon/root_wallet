import 'package:root_wallet/features/send/domain/entities/fee_rate.dart';
import 'package:root_wallet/features/wallet/data/datasources/bdk_wallet_datasource.dart';

class MempoolFeeDatasource {
  MempoolFeeDatasource({required BdkWalletDatasource walletDatasource})
    : _walletDatasource = walletDatasource;

  final BdkWalletDatasource _walletDatasource;

  Future<FeeRate> recommendedFee() async {
    try {
      final blockchain = await _walletDatasource.resolveBlockchain();
      final estimated = await blockchain.estimateFee(target: BigInt.from(3));
      final sats = estimated.satPerVb.ceil();
      return FeeRate(satsPerVByte: sats < 1 ? 1 : sats);
    } catch (_) {
      return const FeeRate(satsPerVByte: 5);
    }
  }
}

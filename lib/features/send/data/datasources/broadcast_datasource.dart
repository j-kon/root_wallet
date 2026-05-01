import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';

class BroadcastDatasource {
  BroadcastDatasource({required BdkWalletService walletService})
    : _walletService = walletService;

  final BdkWalletService _walletService;

  Future<String> broadcast(bdk.Transaction transaction) async {
    return _walletService.broadcastTransaction(transaction);
  }
}

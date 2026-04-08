import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:root_wallet/features/wallet/data/datasources/bdk_wallet_datasource.dart';

class BroadcastDatasource {
  BroadcastDatasource({required BdkWalletDatasource walletDatasource})
    : _walletDatasource = walletDatasource;

  final BdkWalletDatasource _walletDatasource;

  Future<String> broadcast(Transaction transaction) async {
    return _walletDatasource.broadcastTransaction(transaction);
  }
}

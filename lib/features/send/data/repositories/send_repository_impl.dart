import 'package:root_wallet/features/send/data/datasources/broadcast_datasource.dart';
import 'package:root_wallet/features/send/domain/entities/send_request.dart';
import 'package:root_wallet/features/send/domain/repositories/send_repository.dart';

class SendRepositoryImpl implements SendRepository {
  SendRepositoryImpl({required BroadcastDatasource broadcastDatasource})
    : _broadcastDatasource = broadcastDatasource;

  final BroadcastDatasource _broadcastDatasource;

  @override
  Future<String> broadcastTx(String signedTx) {
    return _broadcastDatasource.broadcast(signedTx);
  }

  @override
  Future<String> buildTx(SendRequest request) async {
    return 'psbt:${request.address}:${request.amountSats}:${request.feeRate.satsPerVByte}';
  }

  @override
  Future<String> signTx(String psbt) async {
    return 'signed:$psbt';
  }
}

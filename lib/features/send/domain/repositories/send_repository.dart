import 'package:root_wallet/features/send/domain/entities/send_request.dart';

abstract class SendRepository {
  Future<String> buildTx(SendRequest request);
  Future<String> signTx(String psbt);
  Future<String> broadcastTx(String signedTx);
}

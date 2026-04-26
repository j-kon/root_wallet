import 'package:root_wallet/features/send/domain/entities/send_request.dart';
import 'package:root_wallet/features/send/domain/entities/send_preview.dart';

abstract class SendRepository {
  Future<SendPreview> previewTx(SendRequest request);
  Future<String> buildTx(SendRequest request);
  Future<String> signTx(String psbt);
  Future<String> broadcastTx(String signedTx);
}

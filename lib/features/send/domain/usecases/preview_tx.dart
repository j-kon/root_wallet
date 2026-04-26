import 'package:root_wallet/features/send/domain/entities/send_preview.dart';
import 'package:root_wallet/features/send/domain/entities/send_request.dart';
import 'package:root_wallet/features/send/domain/repositories/send_repository.dart';

class PreviewTx {
  const PreviewTx(this._repository);

  final SendRepository _repository;

  Future<SendPreview> call(SendRequest request) {
    return _repository.previewTx(request);
  }
}

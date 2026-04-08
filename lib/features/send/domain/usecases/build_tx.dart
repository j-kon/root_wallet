import 'package:root_wallet/features/send/domain/entities/send_request.dart';
import 'package:root_wallet/features/send/domain/repositories/send_repository.dart';

class BuildTx {
  const BuildTx(this._repository);

  final SendRepository _repository;

  Future<String> call(SendRequest request) {
    return _repository.buildTx(request);
  }
}

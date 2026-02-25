import 'package:root_wallet/features/send/domain/repositories/send_repository.dart';

class BroadcastTx {
  const BroadcastTx(this._repository);

  final SendRepository _repository;

  Future<String> call(String signedTx) {
    return _repository.broadcastTx(signedTx);
  }
}

import 'package:root_wallet/features/send/domain/repositories/send_repository.dart';

class SignTx {
  const SignTx(this._repository);

  final SendRepository _repository;

  Future<String> call(String psbt) {
    return _repository.signTx(psbt);
  }
}

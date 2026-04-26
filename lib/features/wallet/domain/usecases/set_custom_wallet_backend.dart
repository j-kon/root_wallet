import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class SetCustomWalletBackend {
  SetCustomWalletBackend(this._repository);

  final WalletRepository _repository;

  Future<void> call(String? endpoint) {
    return _repository.setCustomBackend(endpoint);
  }
}

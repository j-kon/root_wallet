import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class ResetWallet {
  const ResetWallet(this._repository);

  final WalletRepository _repository;

  Future<void> call() {
    return _repository.resetWallet();
  }
}

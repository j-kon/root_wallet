import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class HasWallet {
  const HasWallet(this._repository);

  final WalletRepository _repository;

  Future<bool> call() {
    return _repository.hasWallet();
  }
}

import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class CreateWallet {
  const CreateWallet(this._repository);

  final WalletRepository _repository;

  Future<WalletIdentity> call() {
    return _repository.createWallet();
  }
}

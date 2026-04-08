import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class GetBalance {
  const GetBalance(this._repository);

  final WalletRepository _repository;

  Future<Balance> call() {
    return _repository.getBalance();
  }
}

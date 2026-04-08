import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class GetAddress {
  const GetAddress(this._repository);

  final WalletRepository _repository;

  Future<String> call() {
    return _repository.getAddress();
  }
}

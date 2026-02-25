import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class GetTransactions {
  const GetTransactions(this._repository);

  final WalletRepository _repository;

  Future<List<TxItem>> call() {
    return _repository.getTransactions();
  }
}

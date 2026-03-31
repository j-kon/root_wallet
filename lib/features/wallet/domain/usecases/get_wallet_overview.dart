import 'package:root_wallet/features/wallet/domain/entities/wallet_overview.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class GetWalletOverview {
  const GetWalletOverview(this._repository);

  final WalletRepository _repository;

  Future<WalletOverview> call() {
    return _repository.getOverview();
  }
}

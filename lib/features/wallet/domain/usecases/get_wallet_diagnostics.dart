import 'package:root_wallet/features/wallet/domain/entities/wallet_diagnostics.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class GetWalletDiagnostics {
  const GetWalletDiagnostics(this._repository);

  final WalletRepository _repository;

  Future<WalletDiagnostics> call() {
    return _repository.getDiagnostics();
  }
}

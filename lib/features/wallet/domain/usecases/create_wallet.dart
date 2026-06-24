import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class CreateWallet {
  const CreateWallet(this._repository);

  final WalletRepository _repository;

  Future<WalletIdentity> call({
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
  }) {
    return _repository.createWallet(scriptType: scriptType);
  }
}

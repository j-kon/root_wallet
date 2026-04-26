import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class RestoreWallet {
  const RestoreWallet(this._repository);

  final WalletRepository _repository;

  Future<WalletIdentity> call(
    String mnemonic, {
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
  }) {
    return _repository.restoreWallet(
      mnemonic: mnemonic,
      scriptType: scriptType,
    );
  }
}

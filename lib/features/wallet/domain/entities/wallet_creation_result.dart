import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';

/// Ephemeral result returned exclusively during wallet creation.
///
/// Contains the newly initialized public [walletIdentity] alongside the raw
/// [recoveryPhrase], intended only for immediate user review and backup verification.
class WalletCreationResult {
  const WalletCreationResult({
    required this.walletIdentity,
    required this.recoveryPhrase,
  });

  final WalletIdentity walletIdentity;
  final String recoveryPhrase;
}

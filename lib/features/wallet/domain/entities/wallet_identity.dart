import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';

/// Public, non-secret identity metadata for an active wallet.
///
/// Contains only non-sensitive identifiers:
/// - [id]: internal wallet storage identifier.
/// - [fingerprint]: master key fingerprint (truncated hash).
/// - [network]: Bitcoin network name.
/// - [capability]: operational capabilities (signing vs. watch-only).
///
/// Private keys and mnemonic recovery words are strictly excluded from this model.
class WalletIdentity {
  const WalletIdentity({
    required this.id,
    required this.fingerprint,
    required this.network,
    this.capability = WalletCapability.signing,
  });

  factory WalletIdentity.fromRecord(dynamic record) {
    return WalletIdentity(
      id: record.id as String,
      fingerprint: record.fingerprint as String,
      network: record.network as String,
      capability: (record.type.name == 'watchOnly')
          ? WalletCapability.watchOnly
          : WalletCapability.signing,
    );
  }

  final String id;
  final String fingerprint;
  final String network;
  final WalletCapability capability;
}


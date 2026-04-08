class WalletIdentity {
  const WalletIdentity({
    required this.id,
    required this.fingerprint,
    required this.network,
  });

  final String id;
  final String fingerprint;
  final String network;
}

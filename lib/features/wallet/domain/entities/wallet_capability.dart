/// Represents the operational capabilities of an active wallet.
///
/// Distinguishes between signing wallets (which possess private seed/key material)
/// and watch-only wallets (which possess only public descriptors/keys).
enum WalletCapability {
  /// Full self-custody signing wallet capable of constructing and signing transactions.
  signing,

  /// Watch-only wallet capable of address derivation, monitoring, and constructing
  /// unsigned PSBTs, but unable to sign on this device.
  watchOnly;

  /// Whether the wallet can derive receive addresses.
  bool get canDeriveAddresses => true;

  /// Whether the wallet can sync with the Bitcoin blockchain network.
  bool get canSync => true;

  /// Whether the wallet can view historical transactions.
  bool get canViewTransactions => true;

  /// Whether the wallet can view unspent transaction outputs (UTXOs).
  bool get canViewUtxos => true;

  /// Whether the wallet can construct unsigned spending proposals (PSBTs).
  bool get canConstructUnsignedTransactions => true;

  /// Whether the wallet can sign transactions on this device.
  bool get canSignTransactions => this == WalletCapability.signing;

  /// Whether this is a watch-only wallet.
  bool get isWatchOnly => this == WalletCapability.watchOnly;

  /// Storage string representation.
  String get storageValue => name;

  /// Parse from storage string with safe fallback.
  static WalletCapability fromStorageValue(String? value) {
    if (value == WalletCapability.watchOnly.name) {
      return WalletCapability.watchOnly;
    }
    return WalletCapability.signing;
  }
}

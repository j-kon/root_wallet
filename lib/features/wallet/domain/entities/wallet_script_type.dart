enum WalletScriptType {
  nativeSegwit,
  taproot,
  nestedSegwit,
  legacy;

  String get storageValue {
    return switch (this) {
      WalletScriptType.nativeSegwit => 'native_segwit',
      WalletScriptType.taproot => 'taproot',
      WalletScriptType.nestedSegwit => 'nested_segwit',
      WalletScriptType.legacy => 'legacy',
    };
  }

  String get displayName {
    return switch (this) {
      WalletScriptType.nativeSegwit => 'Native SegWit',
      WalletScriptType.taproot => 'Taproot',
      WalletScriptType.nestedSegwit => 'Nested SegWit',
      WalletScriptType.legacy => 'Legacy',
    };
  }

  String get shortLabel {
    return switch (this) {
      WalletScriptType.nativeSegwit => 'tb1q',
      WalletScriptType.taproot => 'tb1p',
      WalletScriptType.nestedSegwit => '2...',
      WalletScriptType.legacy => 'm/n',
    };
  }

  String get description {
    return switch (this) {
      WalletScriptType.nativeSegwit =>
        'Most modern wallets. Addresses usually start with tb1q.',
      WalletScriptType.taproot =>
        'Newer Taproot wallets. Addresses usually start with tb1p.',
      WalletScriptType.nestedSegwit =>
        'Older compatibility wallets. Testnet addresses usually start with 2.',
      WalletScriptType.legacy =>
        'Old wallets. Testnet addresses usually start with m or n.',
    };
  }

  static WalletScriptType fromStorageValue(String? value) {
    for (final type in WalletScriptType.values) {
      if (type.storageValue == value) {
        return type;
      }
    }
    return WalletScriptType.nativeSegwit;
  }
}

import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';

abstract final class WalletStorageKeys {
  // Legacy single-wallet keys (preserved for migration & compatibility)
  static const mnemonic = 'wallet.mnemonic';
  static const scriptType = 'wallet.script_type';
  static const decoyMnemonic = 'wallet.decoy_mnemonic';
  static const walletCapability = 'wallet.capability';
  static const externalDescriptor = 'wallet.external_descriptor';
  static const internalDescriptor = 'wallet.internal_descriptor';

  // Explicit legacy constants
  static const legacyMnemonic = 'wallet.mnemonic';
  static const legacyScriptType = 'wallet.script_type';
  static const legacyCapability = 'wallet.capability';
  static const legacyExternalDescriptor = 'wallet.external_descriptor';
  static const legacyInternalDescriptor = 'wallet.internal_descriptor';
  static const legacyMigrationCompleted = 'wallet.migration.completed.v1';

  // Wallet-scoped key helpers
  static String mnemonicFor(String walletId) => 'wallet.$walletId.mnemonic';
  static String scriptTypeFor(String walletId) => 'wallet.$walletId.script_type';
  static String capabilityFor(String walletId) => 'wallet.$walletId.capability';
  static String externalDescriptorFor(String walletId) =>
      'wallet.$walletId.external_descriptor';
  static String internalDescriptorFor(String walletId) =>
      'wallet.$walletId.internal_descriptor';
  static String metadataFor(String walletId) => 'wallet.$walletId.metadata';

  /// Wallet-scoped backup confirmation key in [SharedPreferences].
  static String backupConfirmedFor(String walletId) {
    WalletRecord.validateWalletId(walletId);
    return 'wallet.$walletId.backup_confirmed';
  }

  static List<String> allKeysFor(String walletId) => [
        mnemonicFor(walletId),
        scriptTypeFor(walletId),
        capabilityFor(walletId),
        externalDescriptorFor(walletId),
        internalDescriptorFor(walletId),
        metadataFor(walletId),
      ];
}

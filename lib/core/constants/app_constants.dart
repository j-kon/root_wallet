abstract final class AppConstants {
  static const appName = 'Root Wallet';
  static const appTagline = 'Secure self-custody, without the noise.';
  static const appVersionName = '1.0.0';
  static const appBuildNumber = '1';
  static const networkDisplayName = 'Testnet';
  static const bitcoinNetworkDisplayName = 'Bitcoin testnet';
  static const defaultCurrency = 'BTC';
  static const satoshisPerBitcoin = 100000000;
  static const minPinLength = 6;
  static const minSendAmountSats = 546;
  static const splashMinimumDuration = Duration(milliseconds: 1800);
  static const supportUrl = 'https://support.rootwallet.app';
  static const walletDatabaseSchemaVersion = 1;
  static const walletSnapshotSchemaVersion = 1;
  static const walletAddressDiscoveryStopGap = 100;
  static const esploraRequestConcurrency = 2;
  static const esploraRequestTimeoutSeconds = 60;
  static const mainnetEsploraUrl = 'https://blockstream.info/api';
  static const testnetEsploraUrl = 'https://mempool.space/testnet/api';
  static const blockstreamTestnetEsploraUrl =
      'https://blockstream.info/testnet/api';
  static const testnetExplorerBaseUrl = 'https://mempool.space/testnet';
  static const testnetEsploraFallbackUrls = <String>[
    testnetEsploraUrl,
    blockstreamTestnetEsploraUrl,
  ];

  static String testnetExplorerTxUrl(String txId) {
    return '$testnetExplorerBaseUrl/tx/$txId';
  }
}
